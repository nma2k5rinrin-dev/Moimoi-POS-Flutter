import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;
import 'package:moimoi_pos/core/database/app_database.dart';
import 'package:moimoi_pos/services/connectivity/connectivity_service.dart';

/// SyncEngine chịu trách nhiệm:
/// 1. PUSH: dequeue sync_queue → gọi Supabase API
/// 2. PULL: query Supabase orders mới → merge vào Drift
/// 3. Immediate sync khi connectivity thay đổi
class SyncEngine extends ChangeNotifier {
  final AppDatabase db;
  final ConnectivityService connectivity;
  final SupabaseClient _supabase;

  Timer? _periodicTimer;
  StreamSubscription<bool>? _connectivitySub;
  bool _isSyncing = false;

  /// Callback khi có đơn mới từ server (QR orders)
  void Function(int newOrderCount)? onNewServerOrders;

  SyncEngine({
    required this.db,
    required this.connectivity,
    SupabaseClient? supabaseClient,
  }) : _supabase = supabaseClient ?? Supabase.instance.client;

  /// Khởi tạo: lắng nghe connectivity + chạy periodic sync
  void init() {
    // Trigger sync ngay khi reconnect
    _connectivitySub = connectivity.onConnectivityChanged.listen((online) {
      if (online) {
        debugPrint('[SyncEngine] Network restored → triggering sync');
        syncAll();
      }
    });

    // Periodic sync mỗi 2 giờ (Realtime lo realtime, đây chỉ là backup catch-up)
    _periodicTimer = Timer.periodic(const Duration(hours: 2), (_) {
      syncAll();
    });
  }

  /// Thử sync ngay lập tức (fire-and-forget)
  void tryImmediateSync() {
    if (connectivity.isOnline) {
      syncAll();
    }
  }

  /// Chạy toàn bộ flow sync: PUSH rồi PULL
  Future<void> syncAll() async {
    if (_isSyncing) return; // Tránh chạy song song
    _isSyncing = true;
    try {
      final online = await connectivity.checkNow();
      if (!online) return;

      await _pushLocalChanges();
      await _pullServerChanges();
      
      notifyListeners();
    } catch (e) {
      debugPrint('[SyncEngine] syncAll error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PHASE 1: PUSH — sync_queue → Supabase
  // ═══════════════════════════════════════════════════════════
  Future<void> _pushLocalChanges() async {
    final pendingOps = await db.getPendingSyncOps();
    if (pendingOps.isEmpty) return;

    debugPrint('[SyncEngine] Pushing ${pendingOps.length} pending ops...');

    for (final op in pendingOps) {
      try {
        await db.markSyncProcessing(op.id);

        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
        final table = op.targetTable;

        switch (op.operation) {
          case 'INSERT':
            await _supabase.from(table).upsert(payload);
            break;
          case 'UPDATE':
            await _supabase.from(table).update(payload).eq('id', op.recordId);
            break;
          case 'DELETE':
            await _supabase.from(table).delete().eq('id', op.recordId);
            break;
        }

        // Success → remove from queue + mark local record as synced
        await db.markSyncDone(op.id);
        if (op.operation != 'DELETE') {
          if (table == 'orders') {
            await db.markOrderSynced(op.recordId);
          } else if (table == 'transactions') {
            await db.markTransactionSynced(op.recordId);
          } else if (table == 'products') {
            await db.markProductSynced(op.recordId);
          } else if (table == 'categories') {
            await db.markCategorySynced(op.recordId);
          }
        }

        debugPrint('[SyncEngine] ✅ Pushed ${op.operation} ${op.recordId}');
      } catch (e) {
        debugPrint('[SyncEngine] ❌ Push failed for ${op.recordId}: $e');
        await db.markSyncFailed(op.id, op.retryCount, op.maxRetries);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PHASE 2: PULL — Supabase → Drift (catch-up missed orders)
  // ═══════════════════════════════════════════════════════════
  Future<void> _pullServerChanges() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    String? storeId;
    try {
      final userData = await _supabase
          .from('users')
          .select('username, role, created_by')
          .eq('id', user.id)
          .single();

      final role = userData['role'] as String?;
      if (role == 'sadmin') return; // Sadmin does not need offline order sync

      if (role == 'admin') {
        storeId = userData['username'] as String?;
      } else if (role != null) {
        storeId = userData['created_by'] as String?;
      }

      if (storeId == null || storeId.isEmpty) return;
    } catch (e) {
      debugPrint('[SyncEngine] Failed to resolve storeId: $e');
      return;
    }

    await _pullOrders(storeId);
    await _pullTransactions(storeId);
  }

  Future<void> _pullOrders(String storeId) async {
    try {
      final lastPull = await db.getKv('last_pull_orders_at');
      final since = lastPull ?? DateTime.now().subtract(const Duration(days: 3)).toIso8601String();

      // Chỉ pull full pending/processing khi KHÔNG có Realtime (app vừa resume từ background)
      // Tối ưu: nếu đang foreground (Realtime active), chỉ pull delta thay vì toàn bộ
      List<dynamic> pendingProcessingData = [];
      final isFirstPull = lastPull == null;
      if (isFirstPull) {
        // Lần đầu: cần lấy toàn bộ pending/processing
        pendingProcessingData = await _supabase
            .from('orders')
            .select()
            .eq('store_id', storeId)
            .inFilter('status', ['pending', 'processing'])
            .isFilter('deleted_at', null)
            .order('time', ascending: true);
      }

      // Lấy các đơn mới (hoặc hoàn thành) từ lần pull trước
      final data = await _supabase
          .from('orders')
          .select()
          .eq('store_id', storeId)
          .gt('time', since)
          .order('time', ascending: true);
          
      // Trộn hai list lại, ưu tiên các order trong `pendingProcessingData` vì đó là thông tin mới nhất
      final Set<String> processedOrderIds = {};
      final combinedData = <dynamic>[...pendingProcessingData];
      for (var row in data) {
         if (!combinedData.any((r) => r['id'] == row['id'])) {
             combinedData.add(row);
         }
      }

      if (combinedData.isEmpty) return;

      int newCount = 0;
      for (final row in combinedData) {
        final orderId = row['id']?.toString() ?? '';
        if (orderId.isEmpty) continue;

        // Kiểm tra có pending sync cho order này không
        final hasPending = await db.hasPendingSync(orderId);

        // Nếu có pending sync → skip (local wins)
        if (hasPending) continue;

        // Upsert vào Drift
        await db.upsertOrder(
          LocalOrdersCompanion(
            id: Value(orderId),
            storeId: Value(row['store_id'] ?? ''),
            orderTable: Value(row['table_name'] ?? ''),
            itemsJson: Value(jsonEncode(row['items'] ?? [])),
            status: Value(row['status'] ?? 'pending'),
            paymentStatus: Value(row['payment_status'] ?? 'unpaid'),
            totalAmount: Value((row['total_amount'] ?? 0).toDouble()),
            createdBy: Value(row['created_by'] ?? ''),
            time: Value(row['time'] ?? ''),
            paymentMethod: Value(row['payment_method'] ?? ''),
            isSynced: const Value(true),
          ),
        );

        newCount++;
      }

      // Cập nhật last_pull timestamp
      await db.setKv('last_pull_orders_at', DateTime.now().toIso8601String());

      if (newCount > 0) {
        debugPrint('[SyncEngine] 📥 Pulled $newCount orders from server');
        onNewServerOrders?.call(newCount);
      }
    } catch (e) {
      debugPrint('[SyncEngine] Pull orders error: $e');
    }
  }

  Future<void> _pullTransactions(String storeId) async {
    try {
      final lastPull = await db.getKv('last_pull_transactions_at');
      final since = lastPull ?? DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

      final data = await _supabase
          .from('transactions')
          .select()
          .eq('store_id', storeId)
          .gt('time', since)
          .order('time', ascending: true);

      if (data.isEmpty) return;

      for (final row in data) {
        final txnId = row['id']?.toString() ?? '';
        if (txnId.isEmpty) continue;

        final hasPending = await db.hasPendingSync(txnId);
        if (hasPending) continue;

        await db.upsertTransaction(
          LocalTransactionsCompanion(
            id: Value(txnId),
            storeId: Value(row['store_id'] ?? ''),
            type: Value(row['type'] ?? 'thu'),
            amount: Value((row['amount'] ?? 0).toDouble()),
            category: Value(row['category'] ?? ''),
            note: Value(row['note'] ?? ''),
            time: Value(row['time'] ?? ''),
            createdBy: Value(row['created_by'] ?? ''),
            isSynced: const Value(true),
          ),
        );
      }

      await db.setKv(
        'last_pull_transactions_at',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('[SyncEngine] Pull transactions error: $e');
    }
  }

  void dispose() {
    _periodicTimer?.cancel();
    _connectivitySub?.cancel();
  }
}
