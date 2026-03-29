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
class SyncEngine {
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

    // Periodic sync mỗi 15 phút (dùng cho foreground, Workmanager lo background)
    _periodicTimer = Timer.periodic(const Duration(minutes: 15), (_) {
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
            await _supabase
                .from(table)
                .update(payload)
                .eq('id', op.recordId);
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
            await db.markThuChiSynced(op.recordId);
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
    await _pullOrders();
    await _pullTransactions();
  }

  Future<void> _pullOrders() async {
    try {
      final lastPull = await db.getKv('last_pull_orders_at');
      final since = lastPull ?? '2000-01-01T00:00:00Z';

      // Lấy tất cả orders mới hơn last_pull
      final data = await _supabase
          .from('orders')
          .select()
          .gt('time', since)
          .order('time', ascending: true);

      if (data.isEmpty) return;

      int newCount = 0;
      for (final row in data) {
        final orderId = row['id']?.toString() ?? '';
        if (orderId.isEmpty) continue;

        // Kiểm tra có pending sync cho order này không
        final hasPending = await db.hasPendingSync(orderId);

        // Nếu có pending sync → skip (local wins)
        if (hasPending) continue;

        // Upsert vào Drift
        await db.upsertOrder(LocalOrdersCompanion(
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
        ));

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

  Future<void> _pullTransactions() async {
    try {
      final lastPull = await db.getKv('last_pull_thuchi_at');
      final since = lastPull ?? '2000-01-01T00:00:00Z';

      final data = await _supabase
          .from('transactions')
          .select()
          .gt('time', since)
          .order('time', ascending: true);

      if (data.isEmpty) return;

      for (final row in data) {
        final txnId = row['id']?.toString() ?? '';
        if (txnId.isEmpty) continue;

        final hasPending = await db.hasPendingSync(txnId);
        if (hasPending) continue;

        await db.upsertThuChi(LocalThuChiCompanion(
          id: Value(txnId),
          storeId: Value(row['store_id'] ?? ''),
          type: Value(row['type'] ?? 'thu'),
          amount: Value((row['amount'] ?? 0).toDouble()),
          category: Value(row['category'] ?? ''),
          note: Value(row['note'] ?? ''),
          time: Value(row['time'] ?? ''),
          createdBy: Value(row['created_by'] ?? ''),
          isSynced: const Value(true),
        ));
      }

      await db.setKv('last_pull_thuchi_at', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[SyncEngine] Pull transactions error: $e');
    }
  }

  void dispose() {
    _periodicTimer?.cancel();
    _connectivitySub?.cancel();
  }
}
