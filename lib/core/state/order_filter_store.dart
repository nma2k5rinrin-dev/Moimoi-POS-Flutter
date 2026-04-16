import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';
import 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';
import 'package:moimoi_pos/features/pos_order/models/order_model.dart';
import 'package:moimoi_pos/features/auth/models/user_model.dart';
import 'dart:convert';
import 'package:drift/drift.dart' show OrderingTerm, OrderingMode, CustomExpression, Value;
import 'package:moimoi_pos/core/database/app_database.dart';
/// Provides filtered/computed order views that depend on both
/// OrderStore (orders data) and AuthStore (user/role info).
///
/// Replaces the visibleOrders / storeOrders / badge logic
/// that was previously baked into AppStore.
class OrderFilterStore extends ChangeNotifier {
  final AuthStore _auth;
  final OrderStore _order;

  OrderFilterStore({
    required AuthStore auth,
    required OrderStore order,
  })  : _auth = auth,
        _order = order {
    _auth.addListener(_invalidateCache);
    _order.addListener(_invalidateCache);
  }

  // ── Cache ──────────────────────────────────────────────────
  List<String>? _cachedStoreUsernames;
  List<OrderModel>? _cachedStoreOrders;
  List<OrderModel>? _cachedVisibleOrders;

  void _invalidateCache() {
    _cachedStoreUsernames = null;
    _cachedStoreOrders = null;
    _cachedVisibleOrders = null;
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────
  UserModel? get _currentUser => _auth.currentUser;
  List<UserModel> get _users => _auth.users;
  String get _sadminViewStoreId => _auth.sadminViewStoreId;

  String getStoreId() {
    final u = _currentUser;
    if (u == null) return '';
    if (u.role == 'sadmin') return 'sadmin';
    if (u.role == 'admin') return u.username;
    final owner = u.createdBy ?? '';
    return owner.isNotEmpty ? owner : u.username;
  }

  // ── Store Usernames (cached) ───────────────────────────────
  List<String> get storeUsernames {
    if (_cachedStoreUsernames != null) return _cachedStoreUsernames!;
    final user = _currentUser;
    if (user == null) return const [];
    final sid = getStoreId();
    List<String> result;
    if (user.role == 'sadmin') {
      if (sid == 'sadmin') {
        result = _users.map((u) => u.username).toList();
      } else {
        result = _users
            .where((u) => u.username == sid || u.createdBy == sid)
            .map((u) => u.username)
            .toList();
      }
    } else {
      final owner = user.role != 'admin'
          ? (user.createdBy ?? user.username)
          : user.username;
      result = _users
          .where((u) => u.username == owner || u.createdBy == owner)
          .map((u) => u.username)
          .toList();
    }
    _cachedStoreUsernames = result;
    return result;
  }

  // ── Store Orders (cached) ──────────────────────────────────
  List<OrderModel> get storeOrders {
    if (_cachedStoreOrders != null) return _cachedStoreOrders!;
    final usernames = storeUsernames;
    final usernameSet = usernames.toSet();
    _cachedStoreOrders = _order.orders
        .where((o) => usernameSet.contains(o.createdBy))
        .toList();
    return _cachedStoreOrders!;
  }

  // ── Visible Orders (cached) ────────────────────────────────
  List<OrderModel> get visibleOrders {
    if (_cachedVisibleOrders != null) return _cachedVisibleOrders!;
    final sid = getStoreId();
    var list = _order.orders.toList();
    if (_currentUser?.role != 'sadmin') {
      list = list
          .where(
            (o) => o.storeId == sid || (o.storeId.isEmpty && sid == 'sadmin'),
          )
          .toList();
    } else if (_sadminViewStoreId != 'all') {
      list = list
          .where(
            (o) =>
                o.storeId == _sadminViewStoreId ||
                (o.storeId.isEmpty && _sadminViewStoreId == 'sadmin'),
          )
          .toList();
    }
    if (_currentUser?.role != 'admin' && _currentUser?.role != 'sadmin') {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      list = list.where((o) => o.time.startsWith(todayStr)).toList();
    }
    _cachedVisibleOrders = list;
    return list;
  }

  // ── Badges ─────────────────────────────────────────────────
  int get pendingProcessing =>
      visibleOrders.where((o) => o.status == 'pending').length;

  int get processingProcessing =>
      visibleOrders.where((o) => o.status == 'processing').length;

  int get unpaidTables =>
      storeOrders.where((o) => o.status == 'processing').length;

  // ── Date Range Fetch ──────────────────────────────────────
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<OrderModel>> fetchOrdersByDateRange(
    DateTime start,
    DateTime end, {
    int offset = 0,
    int limit = 10,
  }) async {
    final storeId = getStoreId();
    var query = _supabase.from('orders').select(
        'id, table_name, items, status, payment_status, total_amount, time, created_by, store_id, payment_method');
    if (storeId != 'sadmin') {
      query = query.eq('store_id', storeId).isFilter('deleted_at', null);
    }
    final response = await query
        .gte('time', start.toIso8601String())
        .lte('time', end.toIso8601String())
        .order('time', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((o) => OrderModel.fromMap(o)).toList();
  }

  Future<List<OrderModel>> fetchCashflowOrdersByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final storeId = getStoreId();
    final db = _order.db;
    if (db == null) return [];

    final fromStr = start.toIso8601String();
    final toStr = end.toIso8601String();

    try {
      // 1) PULL từ Supabase ngầm (Stale-While-Revalidate)
      Future(() async {
        try {
          final sClient = Supabase.instance.client;
          final serverData = await sClient
              .from('orders')
              .select()
              .eq('store_id', storeId)
              .gte('time', fromStr)
              .lte('time', toStr)
              .isFilter('deleted_at', null);

          if (serverData.isNotEmpty) {
            for (final row in serverData) {
               await db.upsertOrder(
                LocalOrdersCompanion(
                  id: Value(row['id']?.toString() ?? ''),
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
            }
            // Gọi notifyListeners của SyncEngine để UI lẳng lặng tự refresh lại
            _order.syncEngine?.notifyListeners();
          }
        } catch (e) {
          // Bỏ qua lỗi ngầm nếu offline
        }
      });

      // 2) RETURN nhanh dữ liệu đang có trong Drift ngay lập tức 
      final query = db.select(db.localOrders)
        ..where((o) => CustomExpression<bool>("time >= '$fromStr' AND time <= '$toStr'"))
        ..where((o) => o.deletedAt.isNull())
        ..orderBy([(o) => OrderingTerm(expression: o.time, mode: OrderingMode.desc)]);
      
      if (storeId != 'sadmin') {
        query.where((o) => o.storeId.equals(storeId));
      }

      final records = await query.get();
      return records.map((r) => OrderModel(
        id: r.id,
        storeId: r.storeId,
        table: r.orderTable, // String getter, not nullable
        items: [], // Chi tiết items không quan trọng cho Cashflow
        status: r.status,
        paymentStatus: r.paymentStatus,
        totalAmount: r.totalAmount,
        time: r.time,
        createdBy: r.createdBy,
        paymentMethod: r.paymentMethod,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_invalidateCache);
    _order.removeListener(_invalidateCache);
    super.dispose();
  }
}
