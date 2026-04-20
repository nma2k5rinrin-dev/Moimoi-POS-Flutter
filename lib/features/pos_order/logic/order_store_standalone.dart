import 'dart:convert' show jsonEncode;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:moimoi_pos/features/pos_order/models/order_model.dart';
import 'package:moimoi_pos/features/auth/models/user_model.dart';
import 'package:moimoi_pos/core/state/base_mixin.dart';

import 'package:moimoi_pos/core/database/app_database.dart';
import 'package:moimoi_pos/core/utils/notification_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:async';

import 'package:moimoi_pos/core/utils/quota_helper.dart';
import 'package:moimoi_pos/features/premium/presentation/widgets/upgrade_dialog.dart';

import 'package:moimoi_pos/features/pos_order/logic/cart_store_standalone.dart';

/// Manages Orders CRUD, and order-related Drift helpers.
class OrderStore extends ChangeNotifier with BaseMixin {
  final QuotaDataProvider quotaProvider;
  final CartStore cartStore;
  final UserModel? Function() getCurrentUser;
  final VoidCallback onPlayNewOrderSound;
  final void Function(OrderModel order)? onNewOrderAlert;

  OrderStore({
    required this.quotaProvider,
    required this.cartStore,
    required this.getCurrentUser,
    required this.onPlayNewOrderSound,
    this.onNewOrderAlert,
  });

  @override
  String getStoreId() => quotaProvider.getStoreId();

  // ── State ─────────────────────────────────────────────────
  List<OrderModel> orders = [];

  /// Track order IDs that already got merge notifications to prevent duplicates
  /// (INSERT and UPDATE events can both fire for the same merge)
  final Set<String> _mergeNotifiedOrderIds = {};

  UserModel? get currentUser => getCurrentUser();

  void clearOrderState() {
    orders = [];
    _mergeNotifiedOrderIds.clear();
  }

  // ── Drift Helpers ─────────────────────────────────────────

  Future<void> initOrderStore(String storeId, DateTime todayStart) async {
    try {
      final rows = await supabaseClient
          .from('orders')
          .select('id, store_id, table_name, items, status, payment_status, total_amount, time, created_by, payment_method, deleted_at')
          .eq('store_id', storeId)
          .isFilter('deleted_at', null)
          .order('time', ascending: false)
          .limit(100);

      final fetchedOrders = rows.map((e) => OrderModel.fromMap(e)).toList();

      if (db != null) {
        final List<OrderModel> resolvedOrders = [];
        final localData = await db!.getOrdersByStore(storeId);
        
        for (final fetched in fetchedOrders) {
          final hasPending = await db!.hasPendingSync(fetched.id);
          
          if (hasPending) {
            // Local wins: preserve the current drift state which has the unsynced changes
            final localRow = localData.firstWhere((o) => o.id == fetched.id, 
                orElse: () => throw Exception('Missing local data for pending sync'));
            final localModelData = jsonDecode(localRow.itemsJson);
            // Reconstruct full item from local row
            resolvedOrders.add(OrderModel(
              id: localRow.id,
              storeId: localRow.storeId,
              table: localRow.orderTable,
              items: (localModelData as List).map((i) => OrderItemModel.fromMap(i)).toList(),
              status: localRow.status,
              paymentStatus: localRow.paymentStatus,
              totalAmount: localRow.totalAmount,
              createdBy: localRow.createdBy,
              time: localRow.time,
              paymentMethod: localRow.paymentMethod,
            ));
          } else {
            // No pending changes -> safe to overwrite with server state
            resolvedOrders.add(fetched);
            await db!.upsertOrder(
              LocalOrdersCompanion(
                id: Value(fetched.id),
                storeId: Value(fetched.storeId),
                orderTable: Value(fetched.table),
                itemsJson: Value(
                  jsonEncode(fetched.items.map((i) => i.toMap()).toList()),
                ),
                status: Value(fetched.status),
                paymentStatus: Value(fetched.paymentStatus),
                totalAmount: Value(fetched.totalAmount),
                createdBy: Value(fetched.createdBy),
                time: Value(fetched.time),
                paymentMethod: Value(fetched.paymentMethod),
                isSynced: const Value(true),
              ),
            );
          }
        }
        
        // ADD LOCAL PENDING ORDERS THAT WERE NOT FETCHED FROM SERVER
        for (final local in localData) {
          if (!resolvedOrders.any((o) => o.id == local.id)) {
            final hasPending = await db!.hasPendingSync(local.id);
            if (hasPending) {
              final localModelData = jsonDecode(local.itemsJson);
              resolvedOrders.add(OrderModel(
                id: local.id,
                storeId: local.storeId,
                table: local.orderTable,
                items: (localModelData as List).map((i) => OrderItemModel.fromMap(i)).toList(),
                status: local.status,
                paymentStatus: local.paymentStatus,
                totalAmount: local.totalAmount,
                createdBy: local.createdBy,
                time: local.time,
                paymentMethod: local.paymentMethod,
              ));
            }
          }
        }
        
        resolvedOrders.sort((a, b) => b.time.compareTo(a.time));
        orders = resolvedOrders;
      } else {
        orders = fetchedOrders;
      }
    } catch (e) {
      debugPrint('[initOrderStore] Error: $e');
    }
    notifyListeners();

    // Dọn dẹp đơn "ma" (xóa mềm nhưng chưa hủy) — chạy ngầm, không chặn UI
    _cleanupGhostOrders(storeId);
  }

  Future<void> reloadOrdersFromDrift() async {
    if (db == null) return;
    final storeId = quotaProvider.getStoreId();
    final localOrders = await db!.getOrdersByStore(storeId);
    orders = localOrders.map((lo) => OrderModel.fromMap({
      'id': lo.id,
      'store_id': lo.storeId,
      'table_name': lo.orderTable,
      'items': jsonDecode(lo.itemsJson),
      'status': lo.status,
      'payment_status': lo.paymentStatus,
      'total_amount': lo.totalAmount,
      'created_by': lo.createdBy,
      'time': lo.time,
      'payment_method': lo.paymentMethod,
    })).toList();
    orders.sort((a, b) => b.time.compareTo(a.time));
    notifyListeners();
  }

  /// Tự động dọn dẹp đơn bị xóa mềm nhưng status vẫn là pending/processing.
  /// Đổi chúng thành cancelled để không bao giờ chặn đơn QR mới.
  Future<void> _cleanupGhostOrders(String storeId) async {
    try {
      // 1. Tìm tất cả đơn "ma": đã xóa mềm nhưng status chưa cancel/complete
      final ghostOrders = await supabaseClient
          .from('orders')
          .select('id')
          .eq('store_id', storeId)
          .not('deleted_at', 'is', null)
          .inFilter('status', ['pending', 'processing']);

      if (ghostOrders.isNotEmpty) {
        final ghostIds = ghostOrders.map((e) => e['id'].toString()).toList();
        debugPrint('[Cleanup] Tìm thấy ${ghostIds.length} đơn ma, đang xử lý...');

        // 2. Chuyển tất cả sang cancelled
        await supabaseClient
            .from('orders')
            .update({'status': 'cancelled'})
            .inFilter('id', ghostIds);

        debugPrint('[Cleanup] Đã hủy ${ghostIds.length} đơn ma thành công!');
      }

      // 3. Xóa cứng các đơn đã xóa mềm quá 7 ngày (giữ DB sạch)
      final cutoff = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();
      await supabaseClient
          .from('orders')
          .delete()
          .eq('store_id', storeId)
          .not('deleted_at', 'is', null)
          .lt('deleted_at', cutoff);
    } catch (e) {
      debugPrint('[Cleanup] Ghost order cleanup error: $e');
    }
  }

  void playNewOrderSound() => onPlayNewOrderSound();

  RealtimeChannel? _ordersChannel;

  void setupOrdersRealtime(String? storeId, String userRole) {
    removeOrdersRealtime(); // Prevent duplicate listeners
    if (storeId == null && userRole == 'sadmin') return;
    _ordersChannel = supabaseClient
        .channel('orders-changes-$storeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: storeId != null
              ? PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'store_id',
                  value: storeId,
                )
              : null,
          callback: (payload) async {
            debugPrint('[Realtime] ══════ EVENT: ${payload.eventType} ══════');
            debugPrint('[Realtime] Record: id=${payload.newRecord['id']}, status=${payload.newRecord['status']}, table=${payload.newRecord['table_name']}, deleted_at=${payload.newRecord['deleted_at']}');
            
            if (payload.eventType == PostgresChangeEvent.insert) {
              final newOrder = OrderModel.fromMap(payload.newRecord);
              debugPrint('[Realtime] INSERT: id=${newOrder.id}, status=${newOrder.status}, table=${newOrder.table}, deletedAt=${newOrder.deletedAt}, items=${newOrder.items.length}');
              
              // Nếu INSERT event đến với deleted_at đã set (Realtime gửi trạng thái cuối)
              // hoặc status đã bị cancelled -> đây là tín hiệu merge từ DB trigger!
              // Phải query lại đơn cũ ngay lập tức để cập nhật UI.
              if (newOrder.deletedAt != null || newOrder.status == 'cancelled') {
                debugPrint('[Realtime] INSERT -> Merge detected (deleted/cancelled). Querying existing order...');
                try {
                  final existingData = await supabaseClient
                      .from('orders')
                      .select('id, store_id, table_name, items, status, payment_status, total_amount, time, created_by, payment_method, deleted_at')
                      .eq('store_id', newOrder.storeId)
                      .eq('table_name', newOrder.table)
                      .isFilter('deleted_at', null)
                      .inFilter('status', ['pending', 'processing'])
                      .eq('payment_status', 'unpaid')
                      .order('time', ascending: false)
                      .limit(1)
                      .maybeSingle();

                  if (existingData != null) {
                    final mergedOrder = OrderModel.fromMap(existingData);
                    debugPrint('[Realtime] INSERT->Merge: Found existing order id=${mergedOrder.id}, status=${mergedOrder.status}, items=${mergedOrder.items.length}');
                    final mergeIdx = orders.indexWhere((o) => o.id == mergedOrder.id);
                    if (mergeIdx != -1) {
                      debugPrint('[Realtime] INSERT->Merge: Updating existing order at idx=$mergeIdx');
                      orders[mergeIdx] = mergedOrder;
                    } else {
                      debugPrint('[Realtime] INSERT->Merge: Order not in list, inserting at top');
                      orders.insert(0, mergedOrder);
                    }
                    
                    if (!_mergeNotifiedOrderIds.contains(mergedOrder.id)) {
                      _mergeNotifiedOrderIds.add(mergedOrder.id);
                      Future.delayed(const Duration(seconds: 10), () => _mergeNotifiedOrderIds.remove(mergedOrder.id));
                      showToast('${mergedOrder.table} vừa thêm sản phẩm vào đơn', 'warning');
                      playNewOrderSound();
                      NotificationHelper.showNewOrderNotification(mergedOrder, isUpdate: true);
                    }
                    
                    if (db != null) await updateOrderInDrift(mergedOrder.id);
                    notifyListeners();
                  } else {
                    debugPrint('[Realtime] INSERT->Merge: No existing order found for table=${newOrder.table}');
                  }
                } catch (e) {
                  debugPrint('[Realtime] Lỗi query đơn gộp từ INSERT: $e');
                }
                return;
              }
              
              if (orders.any((o) => o.id == newOrder.id)) {
                debugPrint('[Realtime] INSERT: Order ${newOrder.id} already in list, skipping.');
                return;
              }

              // Đợi để DB trigger kịp xử lý merge (nếu có)
              // rồi kiểm tra lại xem đơn có bị cancelled chưa
              debugPrint('[Realtime] INSERT: Waiting 800ms for trigger to merge...');
              await Future.delayed(const Duration(milliseconds: 800));
              debugPrint('[Realtime] INSERT: 800ms elapsed. Querying fresh state of ${newOrder.id}...');

              try {
                final freshData = await supabaseClient
                    .from('orders')
                    .select('id, store_id, table_name, items, status, payment_status, total_amount, time, created_by, payment_method, deleted_at')
                    .eq('id', newOrder.id)
                    .maybeSingle();
                
                debugPrint('[Realtime] INSERT: freshData null=${freshData == null}, deleted_at=${freshData?['deleted_at']}, status=${freshData?['status']}');
                
                // Nếu đơn đã bị trigger cancelled/xóa -> đây là merge!
                // Query lại đơn cũ đã được gộp để cập nhật UI
                if (freshData == null || 
                    freshData['deleted_at'] != null || 
                    freshData['status'] == 'cancelled') {
                  
                  debugPrint('[Realtime] INSERT: Merge detected! Searching for existing order on table=${newOrder.table}...');
                  // Tìm đơn cũ đang active của cùng bàn đó
                  final existingData = await supabaseClient
                      .from('orders')
                      .select('id, store_id, table_name, items, status, payment_status, total_amount, time, created_by, payment_method, deleted_at')
                      .eq('store_id', newOrder.storeId)
                      .eq('table_name', newOrder.table)
                      .isFilter('deleted_at', null)
                      .inFilter('status', ['pending', 'processing'])
                      .eq('payment_status', 'unpaid')
                      .order('time', ascending: false)
                      .limit(1)
                      .maybeSingle();

                  debugPrint('[Realtime] INSERT: Existing order found=${existingData != null}, id=${existingData?['id']}, items=${existingData != null ? (existingData['items'] as List?)?.length : 'N/A'}');

                  if (existingData != null) {
                    final mergedOrder = OrderModel.fromMap(existingData);
                    final mergeIdx = orders.indexWhere((o) => o.id == mergedOrder.id);
                    debugPrint('[Realtime] INSERT->Merge: mergeIdx=$mergeIdx, mergedOrder.items=${mergedOrder.items.length}');
                    if (mergeIdx != -1) {
                      orders[mergeIdx] = mergedOrder;
                    } else {
                      orders.insert(0, mergedOrder);
                    }
                    
                    if (!_mergeNotifiedOrderIds.contains(mergedOrder.id)) {
                      _mergeNotifiedOrderIds.add(mergedOrder.id);
                      Future.delayed(const Duration(seconds: 10), () => _mergeNotifiedOrderIds.remove(mergedOrder.id));
                      showToast('${mergedOrder.table} vừa thêm sản phẩm vào đơn', 'warning');
                      playNewOrderSound();
                      NotificationHelper.showNewOrderNotification(mergedOrder, isUpdate: true);
                    }
                    
                    if (db != null) await updateOrderInDrift(mergedOrder.id);
                    notifyListeners();
                  } else {
                    debugPrint('[Realtime] INSERT->Merge: No existing order found for table=${newOrder.table}');
                  }
                  return;
                }
                
                // Đơn không bị cancelled -> kiểm tra xem có đơn cũ cùng bàn không
                // Nếu có → trigger không gộp được, app tự gộp!
                debugPrint('[Realtime] INSERT: Order still active. Checking if existing order on same table...');
                Map<String, dynamic>? matchingExisting;
                
                // --- Pinned tables bypass ---
                // "Bàn ghim" bắt đầu bằng \u2605 (★). Không được gộp đơn cho bàn ghim!
                if (!newOrder.table.startsWith('\u2605')) {
                  final existingForTable = await supabaseClient
                      .from('orders')
                      .select('id, store_id, table_name, items, status, payment_status, total_amount, time, created_by, payment_method, deleted_at')
                      .eq('store_id', newOrder.storeId)
                      .isFilter('deleted_at', null)
                      .inFilter('status', ['pending', 'processing'])
                      .eq('payment_status', 'unpaid')
                      .neq('id', newOrder.id)
                      .order('time', ascending: false);

                  // Tìm đơn cùng bàn bằng cách so sánh tên bàn đã normalize
                  final normalizedNewTable = newOrder.table.toLowerCase().replaceAll('bàn', '').replaceAll('bán', '').trim();
                  for (final row in existingForTable) {
                    final existingTable = (row['table_name'] ?? '').toString().toLowerCase().replaceAll('bàn', '').replaceAll('bán', '').trim();
                    if (existingTable == normalizedNewTable) {
                      matchingExisting = row;
                      break;
                    }
                  }
                }

                if (matchingExisting != null) {
                  debugPrint('[Realtime] INSERT: Found existing order ${matchingExisting['id']} on same table! Trigger did NOT merge. App will merge manually.');
                  
                  // App-level merge: gộp items từ đơn mới vào đơn cũ
                  final existingOrder = OrderModel.fromMap(matchingExisting);
                  final newItems = OrderModel.fromMap(freshData).items;
                  
                  // Merge items: thêm items mới vào cuối, không gộp số lượng
                  // Mỗi món thêm mới tách riêng 1 dòng để dễ phân biệt
                  final mergedItems = [...existingOrder.items];
                  for (final newItem in newItems) {
                    mergedItems.add(newItem.copyWith(isNewlyAdded: true));
                  }
                  
                  final newTotal = existingOrder.totalAmount + OrderModel.fromMap(freshData).totalAmount;
                  
                  // Update đơn cũ trên Supabase
                  await supabaseClient.from('orders').update({
                    'items': mergedItems.map((i) => i.toMap()).toList(),
                    'total_amount': newTotal,
                  }).eq('id', existingOrder.id);
                  
                  // Soft-delete đơn mới
                  await supabaseClient.from('orders').update({
                    'deleted_at': DateTime.now().toUtc().toIso8601String(),
                    'status': 'cancelled',
                  }).eq('id', newOrder.id);
                  
                  // Update UI
                  final mergedOrderModel = existingOrder.copyWith(
                    items: mergedItems,
                    totalAmount: newTotal,
                  );
                  final mergeIdx = orders.indexWhere((o) => o.id == existingOrder.id);
                  if (mergeIdx != -1) {
                    orders[mergeIdx] = mergedOrderModel;
                  } else {
                    orders.insert(0, mergedOrderModel);
                  }
                  
                  if (!_mergeNotifiedOrderIds.contains(existingOrder.id)) {
                    _mergeNotifiedOrderIds.add(existingOrder.id);
                    Future.delayed(const Duration(seconds: 10), () => _mergeNotifiedOrderIds.remove(existingOrder.id));
                    showToast('${existingOrder.table} vừa thêm sản phẩm vào đơn', 'warning');
                    playNewOrderSound();
                    NotificationHelper.showNewOrderNotification(mergedOrderModel, isUpdate: true);
                  }
                  
                  if (db != null) await updateOrderInDrift(existingOrder.id);
                  notifyListeners();
                  debugPrint('[Realtime] INSERT: App-level merge completed! ${mergedItems.length} items total.');
                  return;
                }
                
                debugPrint('[Realtime] INSERT: No existing order on same table. Treating as genuine new order.');
                // Đơn không bị cancelled -> đây là đơn mới thật sự
                if (orders.any((o) => o.id == newOrder.id)) return;
                
                final confirmedOrder = OrderModel.fromMap(freshData);
                orders.insert(0, confirmedOrder);
                showToast('${confirmedOrder.table} có đơn hàng mới');
                playNewOrderSound();
                NotificationHelper.showNewOrderNotification(confirmedOrder);

                if (db != null) {
                  await db!.upsertOrder(
                    LocalOrdersCompanion(
                      id: Value(confirmedOrder.id),
                      storeId: Value(confirmedOrder.storeId),
                      orderTable: Value(confirmedOrder.table),
                      itemsJson: Value(
                        jsonEncode(
                          confirmedOrder.items.map((i) => i.toMap()).toList(),
                        ),
                      ),
                      status: Value(confirmedOrder.status),
                      paymentStatus: Value(confirmedOrder.paymentStatus),
                      totalAmount: Value(confirmedOrder.totalAmount),
                      createdBy: Value(confirmedOrder.createdBy),
                      time: Value(confirmedOrder.time),
                      paymentMethod: Value(confirmedOrder.paymentMethod),
                      isSynced: const Value(true),
                    ),
                  );
                }
                notifyListeners();
              } catch (e) {
                debugPrint('[Realtime] Lỗi xác nhận đơn mới: $e');
              }
            } else if (payload.eventType == PostgresChangeEvent.update) {
              final rec = payload.newRecord;
              debugPrint('[Realtime] UPDATE: id=${rec['id']}, status=${rec['status']}, items_null=${rec['items'] == null}, deleted_at=${rec['deleted_at']}');
              if (rec['deleted_at'] != null) {
                debugPrint('[Realtime] UPDATE: Order ${rec['id']} soft-deleted, removing from list');
                orders.removeWhere((o) => o.id == rec['id']?.toString());
                if (db != null)
                  db!.deleteOrderLocally(rec['id']?.toString() ?? '');
                notifyListeners();
                return;
              }
              final id = rec['id']?.toString() ?? '';
              
              if (db != null) {
                final hasPending = await db!.hasPendingSync(id);
                if (hasPending) {
                  // Ignore Realtime UPDATE if local app is currently trying to push its own changes
                  // Local wins. When SyncEngine succeeds, it will broadcast a fresh update.
                  debugPrint('[Realtime] Đã bỏ qua UPDATE cho $id vì đang có pending sync.');
                  return;
                }
              }

              final idx = orders.indexWhere((o) => o.id == id);

              debugPrint('[Realtime] UPDATE: Order idx in local list = $idx (total orders: ${orders.length})');
              if (idx != -1) {
                final existing = orders[idx];
                debugPrint('[Realtime] UPDATE: Found existing order status=${existing.status}, items=${existing.items.length}');
                List<OrderItemModel> updatedItems = existing.items;

                if (rec['items'] != null) {
                  debugPrint('[Realtime] UPDATE: Incoming items count=${(rec['items'] as List).length}');
                  final incomingItems = (rec['items'] as List<dynamic>)
                      .map((e) => OrderItemModel.fromMap(e as Map<String, dynamic>))
                      .toList();
                  
                  // Lấy list items y nguyên từ server đẩy về (DB trigger đã nối mảng jsonb, ko gộp)
                  updatedItems = incomingItems.map((item) {
                    // Cờ isNewlyAdded đã được set trong INSERT, DB không lưu cờ này
                    // Vì jsonb DB chỉ lưu state thô, nếu cần đánh dấu ta có thể dò lại...
                    // Tuy nhiên việc này đã được cover lúc INSERT nếu đó là merge App-level.
                    return item;
                  }).toList();
                }

                // Chống rollback trạng thái hoàn thành từ server dội lại
                String safeStatus = rec['status'] ?? existing.status;
                if (existing.status == 'completed' && safeStatus != 'completed') {
                  safeStatus = 'completed'; // Local is already completed, keep it
                }

                orders[idx] = existing.copyWith(
                  status: safeStatus,
                  paymentStatus: rec['payment_status'] ?? existing.paymentStatus,
                  paymentMethod:
                      (rec['payment_method'] != null &&
                          (rec['payment_method'] as String).isNotEmpty)
                      ? rec['payment_method'] as String
                      : existing.paymentMethod,
                  totalAmount: rec['total_amount'] != null
                      ? (rec['total_amount'] as num).toDouble()
                      : null,
                  items: updatedItems,
                );
                if (db != null) await updateOrderInDrift(id);

                // ── Thông báo khi phát hiện item mới được thêm (QR merge hay thiết bị khác) ──
                final oldTotalQty = existing.items.fold<int>(0, (s, i) => s + i.quantity);
                final newTotalQty = updatedItems.fold<int>(0, (s, i) => s + i.quantity);
                
                if (newTotalQty > oldTotalQty && !_mergeNotifiedOrderIds.contains(id)) {
                  _mergeNotifiedOrderIds.add(id);
                  Future.delayed(const Duration(seconds: 10), () => _mergeNotifiedOrderIds.remove(id));
                  final updatedOrder = orders[idx];
                  final tableName = updatedOrder.table.isNotEmpty ? updatedOrder.table : 'Mang về';
                  showToast('$tableName vừa thêm sản phẩm vào đơn', 'warning');
                  playNewOrderSound();
                  NotificationHelper.showNewOrderNotification(updatedOrder, isUpdate: true);
                }

                notifyListeners();
              } else {
                try {
                  final data = await supabaseClient
                      .from('orders')
                      .select('id, store_id, table_name, items, status, payment_status, total_amount, time, created_by, payment_method, deleted_at')
                      .eq('id', id)
                      .maybeSingle();
                  if (data != null) {
                    final newOrder = OrderModel.fromMap(data);
                    if (newOrder.deletedAt == null && !orders.any((o) => o.id == newOrder.id)) {
                      orders.insert(0, newOrder);
                      notifyListeners();
                    }
                  }
                } catch (e) {
                  debugPrint('[Realtime] Failed to fetch order $id: $e');
                }
              }
            } else if (payload.eventType == PostgresChangeEvent.delete) {
              final deletedId = payload.oldRecord['id']?.toString() ?? '';
              orders.removeWhere((o) => o.id == deletedId);
              if (db != null) {
                await (db!.delete(
                  db!.localOrders,
                )..where((t) => t.id.equals(deletedId))).go();
              }
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  void removeOrdersRealtime() {
    if (_ordersChannel != null) supabaseClient.removeChannel(_ordersChannel!);
    _ordersChannel = null;
  }

  Future<List<OrderModel>> fetchReportOrders(
    DateTime from,
    DateTime to, [
    String? storeIdFilter,
  ]) async {
    final sid = storeIdFilter ?? getStoreId();
    if (sid.isEmpty || sid == 'sadmin') return [];
    final fromStr = DateTime(from.year, from.month, from.day).toIso8601String();
    final toStr = DateTime(
      to.year,
      to.month,
      to.day,
      23,
      59,
      59,
    ).toIso8601String();

    try {
      final response = await supabaseClient
          .from('orders')
          .select('id, table_name, status, payment_status, total_amount, time, created_by, store_id, payment_method')
          .eq('store_id', sid)
          .isFilter('deleted_at', null)
          .gte('time', fromStr)
          .lte('time', toStr)
          .order('time', ascending: false);
      return (response as List).map((o) => OrderModel.fromMap(o)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Build a Drift update for an existing in-memory order
  Future<void> updateOrderInDrift(String orderId) async {
    if (db == null) return;
    final order = orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => const OrderModel(id: ''),
    );
    if (order.id.isEmpty) return;
    await db!.upsertOrder(
      LocalOrdersCompanion(
        id: Value(orderId),
        storeId: Value(order.storeId),
        orderTable: Value(order.table),
        itemsJson: Value(
          jsonEncode(order.items.map((i) => i.toMap()).toList()),
        ),
        status: Value(order.status),
        paymentStatus: Value(order.paymentStatus),
        totalAmount: Value(order.totalAmount),
        createdBy: Value(order.createdBy),
        time: Value(order.time),
        paymentMethod: Value(order.paymentMethod),
        isSynced: const Value(false),
      ),
    );
  }

  // ── Orders CRUD ───────────────────────────────────────────
  void updateOrderStatus(String orderId, String status) {
    final oldOrders = List<OrderModel>.from(orders);
    offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: orderId,
      payload: {'status': status},
      applyInMemory: () {
        orders = orders
            .map((o) => o.id == orderId ? o.copyWith(status: status) : o)
            .toList();
      },
      applyDrift: () => updateOrderInDrift(orderId),
      rollback: () {
        orders = oldOrders;
      },
      errorMsg: 'Cập nhật trạng thái đơn thất bại, đã hoàn tác',
    );
  }

  void completeOrderWithPayment(String orderId, String paymentMethod) {
    final oldOrders = List<OrderModel>.from(orders);
    offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: orderId,
      payload: {
        'status': 'completed',
        'payment_status': 'paid',
        'payment_method': paymentMethod,
      },
      applyInMemory: () {
        orders = orders
            .map(
              (o) => o.id == orderId
                  ? o.copyWith(
                      status: 'completed',
                      paymentStatus: 'paid',
                      paymentMethod: paymentMethod,
                    )
                  : o,
            )
            .toList();
      },
      applyDrift: () => updateOrderInDrift(orderId),
      rollback: () {
        orders = oldOrders;
      },
      errorMsg: 'Thanh toán thất bại, đã hoàn tác',
    );
  }

  void updateOrderTable(String orderId, String newTable) {
    final oldOrders = List<OrderModel>.from(orders);
    offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: orderId,
      payload: {'table_name': newTable},
      applyInMemory: () {
        orders = orders
            .map((o) => o.id == orderId ? o.copyWith(table: newTable) : o)
            .toList();
      },
      applyDrift: () => updateOrderInDrift(orderId),
      rollback: () {
        orders = oldOrders;
      },
      errorMsg: 'Đổi bàn thất bại, đã hoàn tác',
    );
  }

  void updateOrderPaymentStatus(
    String orderId,
    String paymentStatus, {
    String paymentMethod = '',
  }) {
    final oldOrders = List<OrderModel>.from(orders);
    final updateData = <String, dynamic>{'payment_status': paymentStatus};
    if (paymentMethod.isNotEmpty) updateData['payment_method'] = paymentMethod;
    offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: orderId,
      payload: updateData,
      applyInMemory: () {
        orders = orders
            .map(
              (o) => o.id == orderId
                  ? o.copyWith(
                      paymentStatus: paymentStatus,
                      paymentMethod: paymentMethod.isNotEmpty
                          ? paymentMethod
                          : null,
                    )
                  : o,
            )
            .toList();
      },
      applyDrift: () => updateOrderInDrift(orderId),
      rollback: () {
        orders = oldOrders;
      },
      errorMsg: 'Cập nhật thanh toán thất bại, đã hoàn tác',
    );
  }

  void updateOrderItemStatus(OrderModel order, int itemIndex, bool isDone) {
    if (order.id.isEmpty) return;

    final newItems = List<OrderItemModel>.from(order.items);
    if (itemIndex >= 0 && itemIndex < newItems.length) {
      newItems[itemIndex] = newItems[itemIndex].copyWith(
        isDone: isDone,
        isNewlyAdded: isDone ? false : newItems[itemIndex].isNewlyAdded,
      );
    }
    offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: order.id,
      payload: {'items': newItems.map((i) => i.toMap()).toList()},
      applyInMemory: () {
        final orderExists = orders.any((o) => o.id == order.id);
        if (orderExists) {
          orders = orders
              .map((o) => o.id == order.id ? o.copyWith(items: newItems) : o)
              .toList();
        } else {
          orders = [...orders, order.copyWith(items: newItems)];
        }
      },
      applyDrift: () => updateOrderInDrift(order.id),
      rollback: () {
        orders = orders
            .map((o) => o.id == order.id ? o.copyWith(items: order.items) : o)
            .toList();
      },
    );
  }

  void markProductDoneAcrossOrders(
    String productName,
    bool isDone, {
    List<OrderModel>? targetOrders,
  }) {
    final processingOrders = targetOrders != null
        ? List<OrderModel>.from(targetOrders)
        : orders.where((o) => o.status == 'processing').toList();

    processingOrders.sort((a, b) {
      final tA = DateTime.tryParse(a.time) ?? DateTime(0);
      final tB = DateTime.tryParse(b.time) ?? DateTime(0);
      if (isDone) {
        return tA.compareTo(tB);
      } else {
        return tB.compareTo(tA);
      }
    });

    final oldOrders = List<OrderModel>.from(orders);

    String? targetOrderId;
    int? targetItemIndex;

    for (final order in processingOrders) {
      for (int i = 0; i < order.items.length; i++) {
        final item = order.items[i];
        if (item.name == productName) {
          if (isDone && item.doneQuantity < item.quantity) {
            targetOrderId = order.id;
            targetItemIndex = i;
            break;
          } else if (!isDone && item.doneQuantity > 0) {
            targetOrderId = order.id;
            targetItemIndex = i;
            break;
          }
        }
      }
      if (targetOrderId != null) break;
    }
    if (targetOrderId == null || targetItemIndex == null) return;

    final targetOrder = processingOrders.firstWhere((o) => o.id == targetOrderId);
    final targetItem = targetOrder.items[targetItemIndex];
    final newDoneQty = isDone
        ? targetItem.doneQuantity + 1
        : targetItem.doneQuantity - 1;

    final updatedItems = List<OrderItemModel>.from(targetOrder.items);
    updatedItems[targetItemIndex] = targetItem.copyWith(doneQuantity: newDoneQty);

    final capturedTargetOrderId = targetOrderId;
    offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: capturedTargetOrderId,
      payload: {'items': updatedItems.map((i) => i.toMap()).toList()},
      applyInMemory: () {
        orders = orders
            .map(
              (o) => o.id == capturedTargetOrderId
                  ? o.copyWith(items: updatedItems)
                  : o,
            )
            .toList();
      },
      applyDrift: () => updateOrderInDrift(capturedTargetOrderId),
      rollback: () {
        orders = oldOrders;
      },
      errorMsg: 'Cập nhật trạng thái sản phẩm thất bại, đã hoàn tác',
    );
  }

  void setAllProductDoneAcrossOrders(
    String productName,
    bool isDone, {
    List<OrderModel>? targetOrders,
  }) {
    final processingOrders = targetOrders != null
        ? List<OrderModel>.from(targetOrders)
        : orders.where((o) => o.status == 'processing').toList();
    final oldOrders = List<OrderModel>.from(orders);

    final updatedOrderMap = <String, List<OrderItemModel>>{};
    for (final order in processingOrders) {
      bool changed = false;
      final newItems = order.items.map((i) {
        if (i.name == productName) {
          final targetQty = isDone ? i.quantity : 0;
          if (i.doneQuantity != targetQty) {
            changed = true;
            return i.copyWith(doneQuantity: targetQty);
          }
        }
        return i;
      }).toList();
      if (changed) {
        updatedOrderMap[order.id] = newItems;
      }
    }
    if (updatedOrderMap.isEmpty) return;

    orders = orders.map((o) {
      final updated = updatedOrderMap[o.id];
      return updated != null ? o.copyWith(items: updated) : o;
    }).toList();

    for (final entry in updatedOrderMap.entries) {
      offlineFirst(
        table: 'orders',
        operation: 'UPDATE',
        recordId: entry.key,
        payload: {'items': entry.value.map((i) => i.toMap()).toList()},
        applyInMemory: () {},
        applyDrift: () => updateOrderInDrift(entry.key),
        rollback: () {
          orders = oldOrders;
        },
        errorMsg: 'Cập nhật trạng thái sản phẩm thất bại, đã hoàn tác',
      );
    }
    notifyListeners();
  }

  void updateOrderItemNote(String orderId, int itemIndex, String note) {
    final order = orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => const OrderModel(id: ''),
    );
    if (order.id.isEmpty) return;
    
    final newItems = List<OrderItemModel>.from(order.items);
    if (itemIndex >= 0 && itemIndex < newItems.length) {
      newItems[itemIndex] = newItems[itemIndex].copyWith(note: note);
    }
    offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: orderId,
      payload: {'items': newItems.map((i) => i.toMap()).toList()},
      applyInMemory: () {
        orders = orders
            .map((o) => o.id == orderId ? o.copyWith(items: newItems) : o)
            .toList();
      },
      applyDrift: () => updateOrderInDrift(orderId),
      rollback: () {
        orders = orders
            .map((o) => o.id == orderId ? o.copyWith(items: order.items) : o)
            .toList();
      },
    );
  }

  void updateOrderItems(
    String orderId,
    List<OrderItemModel> newItems,
    double newTotal,
  ) {
    final oldOrders = List<OrderModel>.from(orders);
    offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: orderId,
      payload: {
        'items': newItems.map((i) => i.toMap()).toList(),
        'total_amount': newTotal,
      },
      applyInMemory: () {
        orders = orders
            .map(
              (o) => o.id == orderId
                  ? o.copyWith(items: newItems, totalAmount: newTotal)
                  : o,
            )
            .toList();
      },
      applyDrift: () => updateOrderInDrift(orderId),
      rollback: () {
        orders = oldOrders;
      },
      errorMsg: 'Cập nhật đơn hàng thất bại, đã hoàn tác',
    );
  }

  void removeOrderItem(String orderId, int itemIndex) {
    final order = orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => orders.first,
    );
    final newItems = List<OrderItemModel>.from(order.items);
    if (itemIndex >= 0 && itemIndex < newItems.length) {
      newItems.removeAt(itemIndex);
    }

    if (newItems.isEmpty) {
      deleteOrder(orderId);
      return;
    }

    final newTotal = newItems.fold(0.0, (acc, i) => acc + i.price * i.quantity);
    updateOrderItems(orderId, newItems, newTotal);
  }

  void cancelOrder(String orderId) {
    final oldOrders = List<OrderModel>.from(orders);
    offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: orderId,
      payload: {'status': 'cancelled'},
      applyInMemory: () {
        final idx = orders.indexWhere((o) => o.id == orderId);
        if (idx != -1) orders[idx] = orders[idx].copyWith(status: 'cancelled');
      },
      applyDrift: () => updateOrderInDrift(orderId),
      rollback: () {
        orders = oldOrders;
      },
      errorMsg: 'Huỷ đơn thất bại, đã hoàn tác',
    );
  }

  void deleteOrder(String orderId) {
    final oldOrders = List<OrderModel>.from(orders);
    offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: orderId,
      payload: {
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'cancelled',
      },
      applyInMemory: () {
        orders.removeWhere((o) => o.id == orderId);
      },
      applyDrift: () async {
        if (db != null) await db!.deleteOrderLocally(orderId);
      },
      rollback: () {
        orders = oldOrders;
      },
      errorMsg: 'Xóa đơn hàng thất bại, đã hoàn tác',
    );
  }

  Future<void> checkoutOrder({
    String paymentStatus = 'unpaid',
    String paymentMethod = '',
  }) async {
    if (cartStore.cart.isEmpty) return;

    final quota = QuotaHelper(quotaProvider);
    if (!quota.canPlaceOrder) {
      final ctx = rootContext;
      if (ctx != null) await showUpgradePrompt(ctx, quota.orderLimitMsg);
      return;
    }

    final totalAmount = cartStore.getCartTotal();
    final storeId = getStoreId();

    if (cartStore.selectedTable.isNotEmpty &&
        paymentStatus == 'unpaid' &&
        !cartStore.selectedTable.trimLeft().startsWith('★')) {
      final existingOrderIdx = orders.indexWhere(
        (o) =>
            o.storeId == storeId &&
            o.table == cartStore.selectedTable &&
            o.paymentStatus == 'unpaid' &&
            (o.status == 'pending' || o.status == 'processing') &&
            o.deletedAt == null,
      );

      if (existingOrderIdx != -1) {
        final existingOrder = orders[existingOrderIdx];
        final newItems = cartStore.cart
            .map((item) => item.copyWith(isDone: false))
            .toList();

        final combinedItems = List<OrderItemModel>.from(existingOrder.items);
        for (final newItem in newItems) {
          combinedItems.add(newItem.copyWith(isNewlyAdded: true));
        }

        final newTotal = existingOrder.totalAmount + totalAmount;

        updateOrderItems(existingOrder.id, combinedItems, newTotal);

        cartStore.clearCart();
        return;
      }
    }

    final now = DateTime.now();
    final orderId =
        'ORD-${now.millisecondsSinceEpoch}-${Random().nextInt(1000).toString().padLeft(3, '0')}';
    final itemsList = cartStore.cart
        .map((item) => item.copyWith(isDone: false).toMap())
        .toList();
    final timeStr = DateTime.now().toIso8601String();
    final createdByStr =
        (currentUser?.fullname.isNotEmpty == true
            ? currentUser?.fullname
            : currentUser?.username) ??
        'unknown';

    final newOrder = {
      'id': orderId,
      'store_id': storeId,
      'table_name': cartStore.selectedTable,
      'items': itemsList,
      'status': 'pending',
      'payment_status': paymentStatus,
      'time': timeStr,
      'total_amount': totalAmount,
      'created_by': createdByStr,
      'payment_method': paymentMethod,
    };

    final orderModel = OrderModel.fromMap(newOrder);
    final savedCart = List<OrderItemModel>.from(cartStore.cart);
    final savedTable = cartStore.selectedTable;

    await offlineFirst(
      table: 'orders',
      operation: 'INSERT',
      recordId: orderId,
      payload: newOrder,
      applyInMemory: () {
        orders.insert(0, orderModel);
        cartStore.clearCart();
      },
      applyDrift: () => db!.upsertOrder(
        LocalOrdersCompanion(
          id: Value(orderId),
          storeId: Value(storeId),
          orderTable: Value(newOrder['table_name'] as String),
          itemsJson: Value(jsonEncode(itemsList)),
          status: const Value('pending'),
          paymentStatus: Value(paymentStatus),
          totalAmount: Value(totalAmount),
          createdBy: Value(createdByStr),
          time: Value(timeStr),
          paymentMethod: Value(paymentMethod),
          isSynced: const Value(false),
        ),
      ),
      rollback: () {
        orders.removeWhere((o) => o.id == orderId);
        cartStore.cart = savedCart;
        cartStore.selectedTable = savedTable;
        cartStore.notifyListeners();
      },
      errorMsg: 'Tạo đơn thất bại',
    );
  }

  // ── Selection ───────────────────────────────────────────
}
