import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
// ignore_for_file: avoid_print
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/store_info_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/notification_model.dart';
import '../models/upgrade_request_model.dart';
import '../models/thu_chi_transaction_model.dart';
import '../utils/quota_helper.dart';
import '../widgets/upgrade_dialog.dart';
import '../db/app_database.dart';
import '../sync/sync_engine.dart';
import 'dart:convert' show jsonEncode, jsonDecode;
import 'package:drift/drift.dart' show Value;

class AppStore extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Offline-first (Drift + SyncEngine) ──────────────────
  AppDatabase? _db;
  SyncEngine? _syncEngine;

  /// Inject Drift DB and SyncEngine (called from main.dart)
  void initOfflineFirst(AppDatabase? db, SyncEngine? engine) {
    _db = db;
    _syncEngine = engine;
    engine?.onNewServerOrders = (count) {
      debugPrint('[AppStore] $count new orders pulled from server');
      // Trigger reload from Drift
      _reloadOrdersFromDrift();
    };
  }

  /// Reload orders from Drift into in-memory list
  Future<void> _reloadOrdersFromDrift() async {
    if (_db == null) return;
    final storeId = getStoreId();
    final localOrders = await _db!.getOrdersByStore(storeId);
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
    notifyListeners();
  }

  /// Build a Drift update for an existing in-memory order
  Future<void> _updateOrderInDrift(String orderId) async {
    if (_db == null) return;
    final order = orders.firstWhere((o) => o.id == orderId,
        orElse: () => const OrderModel(id: ''));
    if (order.id.isEmpty) return;
    await _db!.upsertOrder(LocalOrdersCompanion(
      id: Value(orderId),
      storeId: Value(order.storeId),
      orderTable: Value(order.table),
      itemsJson: Value(jsonEncode(order.items.map((i) => i.toMap()).toList())),
      status: Value(order.status),
      paymentStatus: Value(order.paymentStatus),
      totalAmount: Value(order.totalAmount),
      createdBy: Value(order.createdBy),
      time: Value(order.time),
      paymentMethod: Value(order.paymentMethod),
      isSynced: const Value(false),
    ));
  }

  /// Global context set by MaterialApp builder for showing dialogs.
  BuildContext? rootContext;

  /// Lightweight notifier that ONLY fires when auth state changes (login/logout).
  /// Used by GoRouter.refreshListenable so router doesn't re-evaluate on every
  /// cart/toast/search change.
  final AuthNotifier authNotifier = AuthNotifier();

  // ── Auth & Users ─────────────────────────────────────────
  UserModel? currentUser;
  List<UserModel> users = [];

  /// Users visible to admin/staff — never includes sadmin accounts.
  List<UserModel> get visibleUsers =>
      users.where((u) => u.role != 'sadmin').toList();
  bool isLoading = false;

  // Store data keyed by storeId
  Map<String, StoreInfoModel> storeInfos = {
    'sadmin': const StoreInfoModel(name: 'Nhà Hàng Của Tôi', isPremium: true),
  };
  Map<String, List<String>> storeTables = {'sadmin': []};
  Map<String, List<CategoryModel>> categories = {'sadmin': []};
  Map<String, List<ProductModel>> products = {'sadmin': []};

  // Orders
  List<OrderModel> orders = [];

  // Notifications
  List<NotificationModel> notifications = [];

  // Upgrade Requests
  List<UpgradeRequestModel> upgradeRequests = [];

  // Thu Chi Transactions (manual income/expense)
  List<ThuChiTransaction> thuChiTransactions = [];

  // Cart (local only)
  List<OrderItemModel> cart = [];
  String selectedCategory = 'all';
  String searchQuery = '';
  String selectedTable = '';
  String sadminViewStoreId = 'all';

  // UI State
  String? toastMessage;
  String toastType = 'success';
  bool isUpgradeModalOpen = false;
  ConfirmDialogData? confirmDialog;

  // ── Realtime channels ───────────────────────────────────
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _productsChannel;
  RealtimeChannel? _notiChannel;
  RealtimeChannel? _upgradeChannel;

  // ── Audio notification ──────────────────────────────────
  final AudioPlayer _orderSoundPlayer = AudioPlayer();
  RealtimeChannel? _thuChiChannel;
  RealtimeChannel? _categoriesChannel;
  RealtimeChannel? _usersChannel;
  RealtimeChannel? _storeInfoChannel;

  // ── Cache invalidation ──────────────────────────────────
  bool _cachesDirty = true;
  List<OrderModel>? _cachedVisibleOrders;
  List<OrderModel>? _cachedStoreOrders;
  List<String>? _cachedStoreUsernames;
  Timer? _searchDebounce;

  void _invalidateCaches() {
    _cachesDirty = true;
    _cachedVisibleOrders = null;
    _cachedStoreOrders = null;
    _cachedStoreUsernames = null;
  }

  @override
  void notifyListeners() {
    _invalidateCaches();
    super.notifyListeners();
  }

  // ── Optimistic UI Helper ──────────────────────────────
  /// Updates state immediately, syncs to Supabase in background.
  /// On failure: rolls back state and shows error toast.
  void _optimistic({
    required VoidCallback apply,
    required Future<void> Function() remote,
    required VoidCallback rollback,
    String errorMsg = 'Có lỗi xảy ra, đã hoàn tác',
  }) {
    apply();
    notifyListeners();
    remote().catchError((e) {
      debugPrint('[Optimistic rollback] $e');
      rollback();
      notifyListeners();
      showToast(errorMsg, 'error');
    });
  }

  // ── Offline-First Helper ──────────────────────────────
  /// Ghi vào Drift trước, enqueue sync_queue, UI cập nhật ngay.
  /// Nếu không có Drift DB (web/test) → fallback về _optimistic.
  Future<void> _offlineFirst({
    required String table,
    required String operation,
    required String recordId,
    required Map<String, dynamic> payload,
    required VoidCallback applyInMemory,
    required Future<void> Function() applyDrift,
    VoidCallback? rollback,
    String errorMsg = 'Có lỗi xảy ra',
  }) async {
    if (_db == null) {
      // Fallback: no local DB → direct to Supabase
      _optimistic(
        apply: applyInMemory,
        remote: () async {
          if (operation == 'INSERT') {
            await _supabase.from(table).upsert(payload);
          } else if (operation == 'UPDATE') {
            await _supabase.from(table).update(payload).eq('id', recordId);
          } else if (operation == 'DELETE') {
            await _supabase.from(table).delete().eq('id', recordId);
          }
        },
        rollback: rollback ?? () {},
        errorMsg: errorMsg,
      );
      return;
    }

    try {
      // 1. Apply to in-memory state
      applyInMemory();

      // 2. Apply to Drift
      await applyDrift();

      // 3. Enqueue sync operation
      final txId = 'tx_${DateTime.now().millisecondsSinceEpoch}_${recordId.hashCode}';
      await _db!.enqueueSyncOp(
        txId: txId,
        tableName: table,
        operation: operation,
        recordId: recordId,
        payload: jsonEncode(payload),
      );

      notifyListeners();

      // 4. Try sync immediately (fire-and-forget)
      _syncEngine?.tryImmediateSync();
    } catch (e) {
      debugPrint('[_offlineFirst] Error: $e');
      rollback?.call();
      notifyListeners();
      showToast(errorMsg, 'error');
    }
  }

  // ── Derived: getStoreId ─────────────────────────────────
  String getStoreId() {
    if (currentUser == null) return 'sadmin';
    if (currentUser!.role == 'sadmin') {
      return sadminViewStoreId == 'all' ? 'sadmin' : sadminViewStoreId;
    }
    return currentUser!.role == 'staff'
        ? (currentUser!.createdBy ?? 'sadmin')
        : currentUser!.username;
  }

  StoreInfoModel get currentStoreInfo {
    final sid = getStoreId();
    return storeInfos[sid] ?? storeInfos['sadmin'] ?? const StoreInfoModel();
  }

  List<String> get currentTables => storeTables[getStoreId()] ?? [];
  List<CategoryModel> get currentCategories =>
      categories[getStoreId()] ?? [];
  List<ProductModel> get currentProducts => products[getStoreId()] ?? [];

  // ── Load Initial Data ───────────────────────────────────
  Future<void> loadInitialData(UserModel user) async {
    isLoading = true;
    notifyListeners();
    try {
      final storeId = user.role == 'sadmin'
          ? null
          : user.role == 'staff'
              ? user.createdBy
              : user.username;

      final isPremium = user.isPremium || user.role == 'sadmin';
      final daysToKeep = isPremium ? 365 : 3;
      final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));

      // Build orders query
      PostgrestFilterBuilder ordersQuery = _supabase
          .from('orders')
          .select()
          .gte('time', cutoff.toIso8601String());
      if (storeId != null) {
        ordersQuery = ordersQuery.eq('store_id', storeId);
      }

      // Build thu_chi query
      PostgrestFilterBuilder thuChiQuery = _supabase
          .from('thu_chi_transactions')
          .select();
      if (storeId != null) {
        thuChiQuery = thuChiQuery.eq('store_id', storeId);
      }

      // Run ALL queries in parallel instead of sequentially
      final results = await Future.wait([
        _supabase.from('users').select(),                         // 0
        _supabase.from('store_infos').select(),                   // 1
        _supabase.from('store_tables').select().order('sort_order'), // 2
        _supabase.from('categories').select(),                    // 3
        _supabase.from('products').select(),                      // 4
        ordersQuery.order('time', ascending: false),              // 5
        _supabase.from('notifications').select()
            .eq('user_id', user.username)
            .order('time', ascending: false),                     // 6
        _supabase.from('upgrade_requests').select()
            .order('time', ascending: false),                     // 7
        thuChiQuery.order('time', ascending: false),              // 8
      ]);

      // Process results
      users = (results[0] as List).map((u) => UserModel.fromMap(u)).toList();

      storeInfos = {'sadmin': const StoreInfoModel(name: 'Nhà Hàng Của Tôi', isPremium: true)};
      for (final s in results[1]) {
        storeInfos[s['store_id']] = StoreInfoModel.fromMap(s);
      }

      // ── Auto-downgrade expired premium stores to basic ──
      for (final entry in storeInfos.entries.toList()) {
        if (entry.key == 'sadmin') continue;
        final info = entry.value;
        if (info.isPremium && info.isExpired) {
          // Update local state immediately
          storeInfos[entry.key] = info.copyWith(isPremium: false);
          // Fire-and-forget: update Supabase in the background
          _supabase
              .from('store_infos')
              .update({'is_premium': false})
              .eq('store_id', entry.key)
              .then((_) => debugPrint('⚠️ Auto-downgraded expired store: ${entry.key}'))
              .catchError((e) => debugPrint('❌ Failed to downgrade store ${entry.key}: $e'));
        }
      }

      storeTables = {};
      for (final t in results[2]) {
        final sid = t['store_id'] as String;
        storeTables.putIfAbsent(sid, () => []);
        storeTables[sid]!.add(t['table_name'] as String);
      }

      categories = {};
      for (final c in results[3]) {
        final sid = c['store_id'] as String;
        categories.putIfAbsent(sid, () => []);
        categories[sid]!.add(CategoryModel.fromMap(c));
      }

      products = {};
      for (final p in results[4]) {
        final sid = p['store_id'] as String;
        products.putIfAbsent(sid, () => []);
        products[sid]!.add(ProductModel.fromMap(p));
      }

      orders = (results[5] as List).map((o) => OrderModel.fromMap(o)).toList();

      notifications =
          (results[6] as List).map((n) => NotificationModel.fromMap(n)).toList();

      upgradeRequests = (results[7] as List)
          .map((r) => UpgradeRequestModel.fromMap(r))
          .toList();

      thuChiTransactions = (results[8] as List)
          .map((r) => ThuChiTransaction.fromMap(r))
          .toList();

      // ── Cache into Drift for offline use ──
      if (_db != null) {
        final sid = storeId ?? 'sadmin';
        // Cache orders
        for (final o in orders) {
          await _db!.upsertOrder(LocalOrdersCompanion(
            id: Value(o.id),
            storeId: Value(o.storeId),
            orderTable: Value(o.table),
            itemsJson: Value(jsonEncode(o.items.map((i) => i.toMap()).toList())),
            status: Value(o.status),
            paymentStatus: Value(o.paymentStatus),
            totalAmount: Value(o.totalAmount),
            createdBy: Value(o.createdBy),
            time: Value(o.time),
            paymentMethod: Value(o.paymentMethod),
            isSynced: const Value(true),
          ));
        }
        // Cache products
        final prodCompanions = <LocalProductsCompanion>[];
        for (final entry in products.entries) {
          for (final p in entry.value) {
            prodCompanions.add(LocalProductsCompanion(
              id: Value(p.id),
              storeId: Value(p.storeId),
              name: Value(p.name),
              price: Value(p.price),
              image: Value(p.image),
              category: Value(p.category),
              description: Value(p.description),
              isOutOfStock: Value(p.isOutOfStock),
              isHot: Value(p.isHot),
              quantity: Value(p.quantity),
              costPrice: Value(p.costPrice),
            ));
          }
        }
        if (prodCompanions.isNotEmpty) {
          await _db!.replaceAllProducts(sid, prodCompanions);
        }
        // Cache categories
        final catCompanions = <LocalCategoriesCompanion>[];
        for (final entry in categories.entries) {
          for (final c in entry.value) {
            catCompanions.add(LocalCategoriesCompanion(
              id: Value(c.id),
              name: Value(c.name),
              storeId: Value(c.storeId),
              emoji: Value(c.emoji),
              color: Value(c.color),
            ));
          }
        }
        if (catCompanions.isNotEmpty) {
          await _db!.replaceAllCategories(sid, catCompanions);
        }
        // Cache thu chi
        for (final t in thuChiTransactions) {
          await _db!.upsertThuChi(LocalThuChiCompanion(
            id: Value(t.id),
            storeId: Value(t.storeId),
            type: Value(t.type),
            amount: Value(t.amount),
            category: Value(t.category),
            note: Value(t.note),
            time: Value(t.time),
            createdBy: Value(t.createdBy),
            isSynced: const Value(true),
          ));
        }
        // Set pull timestamps
        final now = DateTime.now().toIso8601String();
        await _db!.setKv('last_pull_orders_at', now);
        await _db!.setKv('last_pull_thuchi_at', now);
        debugPrint('[Drift] Cached ${orders.length} orders, ${prodCompanions.length} products, ${catCompanions.length} categories, ${thuChiTransactions.length} thu/chi');
      }

      isLoading = false;
      notifyListeners();

      // Setup realtime after data loaded
      _setupRealtime(user, storeId);
    } catch (e) {
      debugPrint('[loadInitialData] $e');
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Login ───────────────────────────────────────────────
  Future<String> login(String username, String password) async {
    final cleanUsername = username.toLowerCase().replaceAll(RegExp(r'\s'), '');
    try {
      final response = await _supabase
          .from('users')
          .select()
          .ilike('username', cleanUsername);

      if (response.isEmpty) return 'invalid';

      final rawUser = (response as List).cast<Map<String, dynamic>>().firstWhere(
        (u) => u['pass'] == password,
        orElse: () => {},
      );
      if (rawUser.isEmpty) return 'invalid';

      var user = UserModel.fromMap(rawUser);

      // Check VIP expiration
      if (user.role == 'admin' && user.expiresAt != null) {
        final isExpired =
            DateTime.now().isAfter(DateTime.parse(user.expiresAt!));
        if (isExpired && user.isPremium) {
          user = user.copyWith(isPremium: false, showVipExpired: true);
          await _supabase
              .from('users')
              .update({'is_premium': false, 'show_vip_expired': true})
              .eq('username', user.username);
        }
      }

      currentUser = user;
      authNotifier.notify();
      notifyListeners();
      await loadInitialData(user);

      // Cache credentials for biometric login
      await saveLoginCredentials(cleanUsername, password);

      return 'success';
    } catch (e) {
      debugPrint('[login] $e');
      return 'invalid';
    }
  }

  // ── Biometric Credential Caching ────────────────────────────
  static const _kBioUser = 'bio_username';
  static const _kBioPass = 'bio_password';

  /// Save login credentials for biometric re-authentication.
  Future<void> saveLoginCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBioUser, username);
    await prefs.setString(_kBioPass, password);
  }

  /// Check if saved credentials exist.
  Future<bool> hasSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kBioUser) && prefs.containsKey(_kBioPass);
  }

  /// Get saved credentials (returns null if none).
  Future<Map<String, String>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_kBioUser);
    final password = prefs.getString(_kBioPass);
    if (username == null || password == null) return null;
    return {'username': username, 'password': password};
  }

  /// Clear saved credentials (call on logout).
  Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBioUser);
    await prefs.remove(_kBioPass);
  }

  /// Login using saved credentials after biometric verification.
  Future<String> loginWithBiometric() async {
    final creds = await getSavedCredentials();
    if (creds == null) return 'no_credentials';
    return login(creds['username']!, creds['password']!);
  }


  // ── Register ────────────────────────────────────────────
  Future<String> register({
    required String fullname,
    required String phone,
    required String storeName,
    required String username,
    required String password,
    String address = '',
  }) async {
    try {
      final existing = await _supabase
          .from('users')
          .select('username')
          .eq('username', username);
      if ((existing as List).isNotEmpty) {
        showToast('Tên đăng nhập đã tồn tại', 'error');
        return 'exists';
      }

      final newUser = {
        'username': username,
        'pass': password,
        'role': 'admin',
        'fullname': fullname,
        'phone': phone,
        'is_premium': false,
      };

      await _supabase.from('users').insert(newUser);
      final storeData = <String, dynamic>{
        'store_id': username,
        'name': storeName.isNotEmpty ? storeName : fullname,
        'phone': phone,
        'is_premium': false,
      };
      if (address.isNotEmpty) storeData['address'] = address;
      await _supabase.from('store_infos').insert(storeData);

      final mappedUser = UserModel.fromMap(newUser);
      currentUser = mappedUser;
      users.add(mappedUser);
      authNotifier.notify();
      notifyListeners();
      await loadInitialData(mappedUser);
      return 'success';
    } catch (e) {
      debugPrint('[register] $e');
      showToast('Đăng ký thất bại', 'error');
      return 'error';
    }
  }

  // ── Logout ──────────────────────────────────────────────
  void logout() {
    _removeRealtimeChannels();
    currentUser = null;
    users = [];
    storeInfos = {};
    storeTables = {};
    categories = {};
    products = {};
    orders = [];
    notifications = [];
    upgradeRequests = [];
    thuChiTransactions = [];
    cart = [];
    selectedTable = '';
    authNotifier.notify();
    notifyListeners();
  }

  // ── Update User ─────────────────────────────────────────
  void updateUser(String username, Map<String, dynamic> updatedData) {
    final dbData = <String, dynamic>{};
    if (updatedData.containsKey('fullname')) dbData['fullname'] = updatedData['fullname'];
    if (updatedData.containsKey('phone')) dbData['phone'] = updatedData['phone'];
    if (updatedData.containsKey('pass')) dbData['pass'] = updatedData['pass'];
    if (updatedData.containsKey('isPremium')) dbData['is_premium'] = updatedData['isPremium'];
    if (updatedData.containsKey('expiresAt')) dbData['expires_at'] = updatedData['expiresAt'];
    if (updatedData.containsKey('showVipExpired')) dbData['show_vip_expired'] = updatedData['showVipExpired'];
    if (updatedData.containsKey('showVipCongrat')) dbData['show_vip_congrat'] = updatedData['showVipCongrat'];
    if (updatedData.containsKey('avatar')) dbData['avatar'] = updatedData['avatar'];
    if (updatedData.containsKey('role')) dbData['role'] = updatedData['role'];
    if (updatedData.containsKey('createdBy') && updatedData['createdBy'] != null && (updatedData['createdBy'] as String).isNotEmpty) {
      dbData['created_by'] = updatedData['createdBy'];
    }

    // Snapshot for rollback
    final oldUsers = List<UserModel>.from(users);
    final oldCurrentUser = currentUser;

    _optimistic(
      apply: () {
        users = users.map((u) {
          if (u.username == username) {
            return UserModel(
              username: u.username,
              pass: updatedData['pass'] ?? u.pass,
              role: updatedData['role'] ?? u.role,
              fullname: updatedData['fullname'] ?? u.fullname,
              phone: updatedData['phone'] ?? u.phone,
              avatar: updatedData['avatar'] ?? u.avatar,
              isPremium: updatedData['isPremium'] ?? u.isPremium,
              expiresAt: updatedData['expiresAt'] ?? u.expiresAt,
              createdBy: updatedData['createdBy'] ?? u.createdBy,
              showVipExpired: updatedData['showVipExpired'] ?? u.showVipExpired,
              showVipCongrat: updatedData['showVipCongrat'] ?? u.showVipCongrat,
            );
          }
          return u;
        }).toList();
        if (currentUser?.username == username) {
          currentUser = users.firstWhere((u) => u.username == username);
        }
      },
      remote: () => _supabase.from('users').update(dbData).eq('username', username),
      rollback: () {
        users = oldUsers;
        currentUser = oldCurrentUser;
      },
      errorMsg: 'Cập nhật thất bại, đã hoàn tác',
    );
  }

  // ── Delete User ─────────────────────────────────────────
  void deleteUser(String username) {
    final oldUsers = List<UserModel>.from(users);
    _optimistic(
      apply: () {
        users.removeWhere((u) => u.username == username);
      },
      remote: () => _supabase.from('users').delete().eq('username', username),
      rollback: () { users = oldUsers; },
      errorMsg: 'Xoá người dùng thất bại, đã hoàn tác',
    );
  }

  // ── Add Staff ───────────────────────────────────────────
  Future<void> addStaff({
    required String fullname,
    required String phone,
    required String username,
    required String password,
    String role = 'staff',
    String? createdBy,
  }) async {
    if (users.any((u) => u.username == username)) {
      showToast('Tên đăng nhập đã tồn tại', 'error');
      return;
    }

    // Quota check for Basic tier
    final quota = QuotaHelper(this);
    if (!quota.canAddStaff) {
      final ctx = rootContext;
      if (ctx != null) await showUpgradePrompt(ctx, quota.staffLimitMsg);
      return;
    }

    final newStaffRow = {
      'username': username,
      'pass': password,
      'role': role,
      'fullname': fullname,
      'phone': phone,
      'avatar': '',
      'is_premium': false,
      'created_by': createdBy ?? currentUser?.username,
    };

    try {
      await _supabase.from('users').insert(newStaffRow);
      if (role == 'admin') {
        await _supabase.from('store_infos').insert({
          'store_id': username,
          'name': fullname.isNotEmpty ? fullname : username,
          'phone': phone,
          'is_premium': false,
        });
      }
      showToast('Thêm tài khoản thành công!');
      users.add(UserModel.fromMap(newStaffRow));
      notifyListeners();
    } catch (e) {
      debugPrint('[addStaff] $e');
      showToast('Thêm tài khoản thất bại', 'error');
    }
  }

  // ── Store Info ──────────────────────────────────────────
  void updateStoreInfo(StoreInfoModel info) {
    final storeId = getStoreId();
    final oldInfo = storeInfos[storeId];
    final dbData = {
      'name': info.name,
      'phone': info.phone,
      'address': info.address,
      'logo_url': info.logoUrl,
      'tax_id': info.taxId,
      'open_hours': info.openHours,
      'bank_id': info.bankId,
      'bank_account': info.bankAccount,
      'bank_owner': info.bankOwner,
      'qr_image_url': info.qrImageUrl,
    };
    dbData.removeWhere((k, v) => v.toString().isEmpty);
    _optimistic(
      apply: () { storeInfos[storeId] = info; },
      remote: () => _supabase.from('store_infos').upsert({'store_id': storeId, ...dbData}),
      rollback: () {
        if (oldInfo != null) {
          storeInfos[storeId] = oldInfo;
        } else {
          storeInfos.remove(storeId);
        }
      },
      errorMsg: 'Cập nhật thông tin cửa hàng thất bại, đã hoàn tác',
    );
  }

  /// Update store info for a specific store by ID (used by sadmin).
  void updateStoreInfoById(String storeId, StoreInfoModel info) {
    final oldInfo = storeInfos[storeId];
    final dbData = {
      'name': info.name,
      'phone': info.phone,
      'address': info.address,
      'logo_url': info.logoUrl,
      'tax_id': info.taxId,
      'open_hours': info.openHours,
      'bank_id': info.bankId,
      'bank_account': info.bankAccount,
      'bank_owner': info.bankOwner,
      'qr_image_url': info.qrImageUrl,
    };
    dbData.removeWhere((k, v) => v.toString().isEmpty);
    _optimistic(
      apply: () { storeInfos[storeId] = info; },
      remote: () => _supabase.from('store_infos').upsert({'store_id': storeId, ...dbData}),
      rollback: () {
        if (oldInfo != null) {
          storeInfos[storeId] = oldInfo;
        } else {
          storeInfos.remove(storeId);
        }
      },
      errorMsg: 'Cập nhật thông tin cửa hàng thất bại, đã hoàn tác',
    );
  }

  /// Delete a store and its admin user + all staff users created by that admin.
  void deleteStore(String storeId) {
    final oldStoreInfos = Map<String, StoreInfoModel>.from(storeInfos);
    final oldUsers = List<UserModel>.from(users);
    final staffToDelete = users.where((u) => u.createdBy == storeId).map((u) => u.username).toList();

    _optimistic(
      apply: () {
        storeInfos.remove(storeId);
        users.removeWhere((u) => u.username == storeId || u.createdBy == storeId);
      },
      remote: () async {
        // Delete staff users first
        for (final staffUsername in staffToDelete) {
          await _supabase.from('users').delete().eq('username', staffUsername);
        }
        // Delete admin user
        await _supabase.from('users').delete().eq('username', storeId);
        // Delete store info
        await _supabase.from('store_infos').delete().eq('store_id', storeId);
      },
      rollback: () {
        storeInfos = oldStoreInfos;
        users = oldUsers;
      },
      errorMsg: 'Xoá cửa hàng thất bại, đã hoàn tác',
    );
  }

  // ── Tables ──────────────────────────────────────────────
  Future<void> addTable(String tableName) async {
    // Quota check for Basic tier
    final quota = QuotaHelper(this);
    if (!quota.canAddTable) {
      final ctx = rootContext;
      if (ctx != null) await showUpgradePrompt(ctx, quota.tableLimitMsg);
      return;
    }
    final storeId = getStoreId();
    final currentTablesList = storeTables[storeId] ?? [];
    if (currentTablesList.contains(tableName)) return;
    _optimistic(
      apply: () {
        storeTables.putIfAbsent(storeId, () => []);
        storeTables[storeId]!.add(tableName);
      },
      remote: () => _supabase.from('store_tables').insert({
        'store_id': storeId,
        'table_name': tableName,
        'sort_order': currentTablesList.length,
      }),
      rollback: () { storeTables[storeId]?.remove(tableName); },
      errorMsg: 'Thêm bàn thất bại, đã hoàn tác',
    );
  }

  void removeTable(String tableName) {
    final storeId = getStoreId();
    final oldTables = List<String>.from(storeTables[storeId] ?? []);
    final oldSelectedTable = selectedTable;
    _optimistic(
      apply: () {
        storeTables[storeId]?.remove(tableName);
        if (selectedTable == tableName) {
          selectedTable = storeTables[storeId]?.isNotEmpty == true
              ? storeTables[storeId]!.first
              : '';
        }
      },
      remote: () => _supabase.from('store_tables').delete().eq('store_id', storeId).eq('table_name', tableName),
      rollback: () {
        storeTables[storeId] = oldTables;
        selectedTable = oldSelectedTable;
      },
      errorMsg: 'Xoá bàn thất bại, đã hoàn tác',
    );
  }

  void updateTable(String oldName, String newName) {
    if (oldName.isEmpty || newName.isEmpty || oldName == newName) return;
    final storeId = getStoreId();
    final oldTables = List<String>.from(storeTables[storeId] ?? []);
    final oldSelectedTable = selectedTable;
    _optimistic(
      apply: () {
        final tablesList = storeTables[storeId] ?? [];
        final idx = tablesList.indexOf(oldName);
        if (idx >= 0) tablesList[idx] = newName;
        if (selectedTable == oldName) selectedTable = newName;
      },
      remote: () => _supabase.from('store_tables').update({'table_name': newName}).eq('store_id', storeId).eq('table_name', oldName),
      rollback: () {
        storeTables[storeId] = oldTables;
        selectedTable = oldSelectedTable;
      },
      errorMsg: 'Cập nhật bàn thất bại, đã hoàn tác',
    );
  }

  void renameArea(String oldArea, String newArea) {
    if (oldArea.isEmpty || newArea.isEmpty || oldArea == newArea) return;
    final storeId = getStoreId();
    final oldTables = List<String>.from(storeTables[storeId] ?? []);
    final oldSelectedTable = selectedTable;
    final tablesList = storeTables[storeId] ?? [];
    final prefix = '$oldArea::';
    // Collect rename pairs for batch Supabase calls
    final renamePairs = <MapEntry<String, String>>[];
    for (int i = 0; i < tablesList.length; i++) {
      if (tablesList[i].startsWith(prefix)) {
        final tablePart = tablesList[i].substring(prefix.length);
        final oldFullName = tablesList[i];
        final newFullName = '$newArea::$tablePart';
        renamePairs.add(MapEntry(oldFullName, newFullName));
      }
    }
    _optimistic(
      apply: () {
        for (final pair in renamePairs) {
          final idx = tablesList.indexOf(pair.key);
          if (idx >= 0) tablesList[idx] = pair.value;
          if (selectedTable == pair.key) selectedTable = pair.value;
        }
      },
      remote: () async {
        for (final pair in renamePairs) {
          await _supabase.from('store_tables').update({'table_name': pair.value}).eq('store_id', storeId).eq('table_name', pair.key);
        }
      },
      rollback: () {
        storeTables[storeId] = oldTables;
        selectedTable = oldSelectedTable;
      },
      errorMsg: 'Đổi tên khu vực thất bại, đã hoàn tác',
    );
  }

  // ── Categories ──────────────────────────────────────────
  Future<void> addCategory(String categoryName, {String emoji = '', String color = ''}) async {
    // Quota check for Basic tier
    final quota = QuotaHelper(this);
    if (!quota.canAddCategory) {
      final ctx = rootContext;
      if (ctx != null) await showUpgradePrompt(ctx, quota.categoryLimitMsg);
      return;
    }
    final storeId = getStoreId();
    final newCat = {
      'id': 'cat_${DateTime.now().millisecondsSinceEpoch}',
      'store_id': storeId,
      'name': categoryName,
      'emoji': emoji,
      'color': color,
    };
    final catModel = CategoryModel.fromMap(newCat);
    _optimistic(
      apply: () {
        categories.putIfAbsent(storeId, () => []);
        categories[storeId]!.add(catModel);
      },
      remote: () => _supabase.from('categories').insert(newCat),
      rollback: () { categories[storeId]?.removeWhere((c) => c.id == catModel.id); },
      errorMsg: 'Thêm danh mục thất bại, đã hoàn tác',
    );
  }

  void updateCategory(CategoryModel updatedCategory) {
    final storeId = getStoreId();
    final oldCategories = List<CategoryModel>.from(categories[storeId] ?? []);
    _optimistic(
      apply: () {
        categories[storeId] = (categories[storeId] ?? [])
            .map((c) => c.id == updatedCategory.id ? updatedCategory : c)
            .toList();
      },
      remote: () => _supabase.from('categories').update({
        'name': updatedCategory.name,
        'emoji': updatedCategory.emoji,
        'color': updatedCategory.color,
      }).eq('id', updatedCategory.id),
      rollback: () { categories[storeId] = oldCategories; },
      errorMsg: 'Cập nhật danh mục thất bại, đã hoàn tác',
    );
  }

  void deleteCategory(String categoryId) {
    final storeId = getStoreId();
    final oldCategories = List<CategoryModel>.from(categories[storeId] ?? []);
    final oldProducts = List<ProductModel>.from(products[storeId] ?? []);
    _optimistic(
      apply: () {
        categories[storeId]?.removeWhere((c) => c.id == categoryId);
        products[storeId] = (products[storeId] ?? []).map((p) {
          return p.category == categoryId ? p.copyWith(category: '') : p;
        }).toList();
      },
      remote: () async {
        await _supabase.from('categories').delete().eq('id', categoryId);
        await _supabase.from('products').update({'category': ''}).eq('store_id', storeId).eq('category', categoryId);
      },
      rollback: () {
        categories[storeId] = oldCategories;
        products[storeId] = oldProducts;
      },
      errorMsg: 'Xoá danh mục thất bại, đã hoàn tác',
    );
  }

  // ── Products ────────────────────────────────────────────
  Future<void> addProduct(ProductModel product) async {
    // Quota check for Basic tier
    final quota = QuotaHelper(this);
    if (!quota.canAddProduct) {
      final ctx = rootContext;
      if (ctx != null) await showUpgradePrompt(ctx, quota.productLimitMsg);
      return;
    }
    final storeId = getStoreId();
    final newProd = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'store_id': storeId,
      'name': product.name,
      'price': product.price,
      'image': product.image,
      'category': product.category,
      'description': product.description,
      'is_out_of_stock': product.isOutOfStock,
      'is_hot': product.isHot,
      'quantity': product.quantity,
      'cost_price': product.costPrice,
    };
    final newProduct = product.copyWith(id: newProd['id'] as String, storeId: storeId);
    _optimistic(
      apply: () {
        products.putIfAbsent(storeId, () => []);
        products[storeId]!.insert(0, newProduct);
      },
      remote: () => _supabase.from('products').insert(newProd),
      rollback: () { products[storeId]?.removeWhere((p) => p.id == newProduct.id); },
      errorMsg: 'Thêm sản phẩm thất bại, đã hoàn tác',
    );
  }

  void updateProduct(ProductModel updatedProduct) {
    final storeId = getStoreId();
    final oldProducts = List<ProductModel>.from(products[storeId] ?? []);
    _optimistic(
      apply: () {
        products[storeId] = (products[storeId] ?? [])
            .map((p) => p.id == updatedProduct.id ? updatedProduct : p)
            .toList();
      },
      remote: () => _supabase.from('products').update({
        'name': updatedProduct.name,
        'price': updatedProduct.price,
        'image': updatedProduct.image,
        'category': updatedProduct.category,
        'description': updatedProduct.description,
        'is_out_of_stock': updatedProduct.isOutOfStock,
        'is_hot': updatedProduct.isHot,
        'quantity': updatedProduct.quantity,
        'cost_price': updatedProduct.costPrice,
      }).eq('id', updatedProduct.id),
      rollback: () { products[storeId] = oldProducts; },
      errorMsg: 'Cập nhật sản phẩm thất bại, đã hoàn tác',
    );
  }

  void deleteProduct(String productId) {
    final storeId = getStoreId();
    final oldProducts = List<ProductModel>.from(products[storeId] ?? []);
    _optimistic(
      apply: () { products[storeId]?.removeWhere((p) => p.id == productId); },
      remote: () => _supabase.from('products').delete().eq('id', productId),
      rollback: () { products[storeId] = oldProducts; },
      errorMsg: 'Xoá sản phẩm thất bại, đã hoàn tác',
    );
  }

  // ── Orders ──────────────────────────────────────────────
  void updateOrderStatus(String orderId, String status) {
    final oldOrders = List<OrderModel>.from(orders);
    _offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: orderId,
      payload: {'status': status},
      applyInMemory: () {
        orders = orders.map((o) => o.id == orderId ? o.copyWith(status: status) : o).toList();
      },
      applyDrift: () => _updateOrderInDrift(orderId),
      rollback: () { orders = oldOrders; },
      errorMsg: 'Cập nhật trạng thái đơn thất bại, đã hoàn tác',
    );
  }

  /// Atomically mark an order as completed + paid in one call.
  void completeOrderWithPayment(String orderId, String paymentMethod) {
    final oldOrders = List<OrderModel>.from(orders);
    _offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: orderId,
      payload: {
        'status': 'completed',
        'payment_status': 'paid',
        'payment_method': paymentMethod,
      },
      applyInMemory: () {
        orders = orders.map((o) => o.id == orderId
            ? o.copyWith(status: 'completed', paymentStatus: 'paid', paymentMethod: paymentMethod)
            : o).toList();
      },
      applyDrift: () => _updateOrderInDrift(orderId),
      rollback: () { orders = oldOrders; },
      errorMsg: 'Thanh toán thất bại, đã hoàn tác',
    );
  }

  /// Change the table of an existing order.
  void updateOrderTable(String orderId, String newTable) {
    final oldOrders = List<OrderModel>.from(orders);
    _offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: orderId,
      payload: {'table_name': newTable},
      applyInMemory: () {
        orders = orders.map((o) => o.id == orderId ? o.copyWith(table: newTable) : o).toList();
      },
      applyDrift: () => _updateOrderInDrift(orderId),
      rollback: () { orders = oldOrders; },
      errorMsg: 'Đổi bàn thất bại, đã hoàn tác',
    );
  }

  void updateOrderPaymentStatus(
      String orderId, String paymentStatus, {String paymentMethod = ''}) {
    final oldOrders = List<OrderModel>.from(orders);
    final updateData = <String, dynamic>{'payment_status': paymentStatus};
    if (paymentMethod.isNotEmpty) updateData['payment_method'] = paymentMethod;
    _offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: orderId,
      payload: updateData,
      applyInMemory: () {
        orders = orders.map((o) => o.id == orderId
            ? o.copyWith(paymentStatus: paymentStatus, paymentMethod: paymentMethod.isNotEmpty ? paymentMethod : null)
            : o).toList();
      },
      applyDrift: () => _updateOrderInDrift(orderId),
      rollback: () { orders = oldOrders; },
      errorMsg: 'Cập nhật thanh toán thất bại, đã hoàn tác',
    );
  }

  void updateOrderItemStatus(
      String orderId, String itemId, bool isDone) {
    final order = orders.firstWhere((o) => o.id == orderId,
        orElse: () => const OrderModel(id: ''));
    if (order.id.isEmpty) return;
    final newItems =
        order.items.map((i) => i.id == itemId ? i.copyWith(isDone: isDone) : i).toList();
    _offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: orderId,
      payload: {'items': newItems.map((i) => i.toMap()).toList()},
      applyInMemory: () {
        orders = orders.map((o) => o.id == orderId ? o.copyWith(items: newItems) : o).toList();
      },
      applyDrift: () => _updateOrderInDrift(orderId),
      rollback: () {
        orders = orders.map((o) => o.id == orderId ? o.copyWith(items: order.items) : o).toList();
      },
    );
  }

  /// Mark ONE item matching [productName] as done (or undone) across cooking orders.
  /// Each call increments/decrements by one: 0/5 → 1/5 → 2/5 ... → 5/5
  void markProductDoneAcrossOrders(String productName, bool isDone) {
    final cookingOrders = orders.where((o) => o.status == 'cooking').toList();
    final oldOrders = List<OrderModel>.from(orders);

    // Find the first matching item that needs to change
    String? targetOrderId;
    String? targetItemId;

    for (final order in cookingOrders) {
      for (final item in order.items) {
        if (item.name == productName && item.isDone != isDone) {
          targetOrderId = order.id;
          targetItemId = item.id;
          break;
        }
      }
      if (targetOrderId != null) break;
    }
    if (targetOrderId == null || targetItemId == null) return;

    // Build updated items for the target order only
    final targetOrder = cookingOrders.firstWhere((o) => o.id == targetOrderId);
    final updatedItems = targetOrder.items
        .map((i) => i.id == targetItemId ? i.copyWith(isDone: isDone) : i)
        .toList();

    final capturedTargetOrderId = targetOrderId;
    _offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: capturedTargetOrderId,
      payload: {'items': updatedItems.map((i) => i.toMap()).toList()},
      applyInMemory: () {
        orders = orders.map((o) =>
            o.id == capturedTargetOrderId ? o.copyWith(items: updatedItems) : o).toList();
      },
      applyDrift: () => _updateOrderInDrift(capturedTargetOrderId),
      rollback: () { orders = oldOrders; },
      errorMsg: 'Cập nhật trạng thái sản phẩm thất bại, đã hoàn tác',
    );
  }

  /// Reset ALL items matching [productName] to undone across cooking orders.
  /// Used when a fully-completed product is tapped again.
  void resetAllProductDoneAcrossOrders(String productName) {
    final cookingOrders = orders.where((o) => o.status == 'cooking').toList();
    final oldOrders = List<OrderModel>.from(orders);

    final updatedOrderMap = <String, List<OrderItemModel>>{};
    for (final order in cookingOrders) {
      final hasMatch = order.items.any((i) => i.name == productName && i.isDone);
      if (hasMatch) {
        updatedOrderMap[order.id] = order.items
            .map((i) => i.name == productName ? i.copyWith(isDone: false) : i)
            .toList();
      }
    }
    if (updatedOrderMap.isEmpty) return;

    // Apply in-memory
    orders = orders.map((o) {
      final updated = updatedOrderMap[o.id];
      return updated != null ? o.copyWith(items: updated) : o;
    }).toList();

    // Enqueue each updated order separately
    for (final entry in updatedOrderMap.entries) {
      _offlineFirst(
        table: 'orders',
        operation: 'UPDATE',
        recordId: entry.key,
        payload: {'items': entry.value.map((i) => i.toMap()).toList()},
        applyInMemory: () {}, // Already applied above
        applyDrift: () => _updateOrderInDrift(entry.key),
        rollback: () { orders = oldOrders; },
        errorMsg: 'Cập nhật trạng thái sản phẩm thất bại, đã hoàn tác',
      );
    }
    notifyListeners();
  }

  void updateOrderItemNote(
      String orderId, String itemId, String note) {
    final order = orders.firstWhere((o) => o.id == orderId,
        orElse: () => const OrderModel(id: ''));
    if (order.id.isEmpty) return;
    final newItems =
        order.items.map((i) => i.id == itemId ? i.copyWith(note: note) : i).toList();
    _offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: orderId,
      payload: {'items': newItems.map((i) => i.toMap()).toList()},
      applyInMemory: () {
        orders = orders.map((o) => o.id == orderId ? o.copyWith(items: newItems) : o).toList();
      },
      applyDrift: () => _updateOrderInDrift(orderId),
      rollback: () {
        orders = orders.map((o) => o.id == orderId ? o.copyWith(items: order.items) : o).toList();
      },
    );
  }


  void updateOrderItems(
      String orderId, List<OrderItemModel> newItems, double newTotal) {
    final oldOrders = List<OrderModel>.from(orders);
    _offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: orderId,
      payload: {
        'items': newItems.map((i) => i.toMap()).toList(),
        'total_amount': newTotal,
      },
      applyInMemory: () {
        orders = orders.map((o) => o.id == orderId
            ? o.copyWith(items: newItems, totalAmount: newTotal)
            : o).toList();
      },
      applyDrift: () => _updateOrderInDrift(orderId),
      rollback: () { orders = oldOrders; },
      errorMsg: 'Cập nhật đơn hàng thất bại, đã hoàn tác',
    );
  }

  void removeOrderItem(String orderId, String itemId) {
    final order = orders.firstWhere((o) => o.id == orderId, orElse: () => orders.first);
    if (order.items.length <= 1) return; // Don't remove last item
    final newItems = order.items.where((i) => i.id != itemId).toList();
    final newTotal = newItems.fold(0.0, (acc, i) => acc + i.price * i.quantity);
    updateOrderItems(orderId, newItems, newTotal);
  }

  void cancelOrder(String orderId) {
    final oldOrders = List<OrderModel>.from(orders);
    _offlineFirst(
      table: 'orders',
      operation: 'UPDATE',
      recordId: orderId,
      payload: {'status': 'cancelled'},
      applyInMemory: () {
        final idx = orders.indexWhere((o) => o.id == orderId);
        if (idx != -1) orders[idx] = orders[idx].copyWith(status: 'cancelled');
      },
      applyDrift: () => _updateOrderInDrift(orderId),
      rollback: () { orders = oldOrders; },
      errorMsg: 'Huỷ đơn thất bại, đã hoàn tác',
    );
  }

  Future<void> checkoutOrder({String paymentStatus = 'unpaid', String paymentMethod = ''}) async {
    if (cart.isEmpty) return;

    // Quota check for Basic tier
    final quota = QuotaHelper(this);
    if (!quota.canPlaceOrder) {
      final ctx = rootContext;
      if (ctx != null) await showUpgradePrompt(ctx, quota.orderLimitMsg);
      return;
    }

    final totalAmount = getCartTotal();
    final storeId = getStoreId();
    final orderId =
        'ORD-${Random().nextInt(10000).toString().padLeft(4, '0')}';
    final itemsList = cart.map((item) => item.copyWith(isDone: false).toMap()).toList();
    final timeStr = DateTime.now().toIso8601String();
    final createdByStr = (currentUser?.fullname.isNotEmpty == true ? currentUser!.fullname : currentUser?.username) ?? 'unknown';

    final newOrder = {
      'id': orderId,
      'store_id': storeId,
      'table_name': selectedTable,
      'items': itemsList,
      'status': 'pending',
      'payment_status': paymentStatus,
      'time': timeStr,
      'total_amount': totalAmount,
      'created_by': createdByStr,
      'payment_method': paymentMethod,
    };

    final orderModel = OrderModel.fromMap(newOrder);
    final savedCart = List<OrderItemModel>.from(cart);
    final savedTable = selectedTable;

    await _offlineFirst(
      table: 'orders',
      operation: 'INSERT',
      recordId: orderId,
      payload: newOrder,
      applyInMemory: () {
        orders.insert(0, orderModel);
        cart = [];
        selectedTable = '';
      },
      applyDrift: () => _db!.upsertOrder(LocalOrdersCompanion(
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
      )),
      rollback: () {
        orders.removeWhere((o) => o.id == orderId);
        cart = savedCart;
        selectedTable = savedTable;
      },
      errorMsg: 'Tạo đơn thất bại',
    );
  }

  // ── Thu Chi Transactions ────────────────────────────────
  Future<void> loadThuChiTransactions(String? storeId) async {
    try {
      PostgrestFilterBuilder query = _supabase
          .from('thu_chi_transactions')
          .select();
      if (storeId != null) {
        query = query.eq('store_id', storeId);
      }
      final data = await query.order('time', ascending: false);
      thuChiTransactions = (data as List)
          .map((r) => ThuChiTransaction.fromMap(r))
          .toList();
    } catch (e) {
      debugPrint('[loadThuChiTransactions] $e');
      // Table may not exist yet — silently ignore
      thuChiTransactions = [];
    }
  }

  Future<void> addThuChiTransaction({
    required String type,
    required double amount,
    required String category,
    String note = '',
    DateTime? date,
  }) async {
    // Quota check for Basic tier
    final quota = QuotaHelper(this);
    if (!quota.canUseThuChi) {
      final ctx = rootContext;
      if (ctx != null) await showUpgradePrompt(ctx, quota.thuChiLimitMsg);
      return;
    }
    final storeId = getStoreId();
    final txnId = 'tc_${DateTime.now().millisecondsSinceEpoch}';
    final txnTime = (date ?? DateTime.now()).toIso8601String();
    final createdBy = currentUser?.fullname.isNotEmpty == true
        ? currentUser!.fullname
        : (currentUser?.username ?? 'unknown');

    final newTxn = {
      'id': txnId,
      'store_id': storeId,
      'type': type,
      'amount': amount,
      'category': category,
      'note': note,
      'time': txnTime,
      'created_by': createdBy,
    };
    final txnModel = ThuChiTransaction.fromMap(newTxn);
    await _offlineFirst(
      table: 'thu_chi_transactions',
      operation: 'INSERT',
      recordId: txnId,
      payload: newTxn,
      applyInMemory: () { thuChiTransactions.insert(0, txnModel); },
      applyDrift: () => _db!.upsertThuChi(LocalThuChiCompanion(
        id: Value(txnId),
        storeId: Value(storeId),
        type: Value(type),
        amount: Value(amount),
        category: Value(category),
        note: Value(note),
        time: Value(txnTime),
        createdBy: Value(createdBy),
        isSynced: const Value(false),
      )),
      rollback: () { thuChiTransactions.removeWhere((t) => t.id == txnId); },
      errorMsg: 'Lưu giao dịch thất bại, đã hoàn tác',
    );
  }

  // ── Cart ────────────────────────────────────────────────
  void addToCart(ProductModel product) {
    final existingIdx = cart.indexWhere((item) => item.id == product.id);
    if (existingIdx >= 0) {
      cart = [
        for (int i = 0; i < cart.length; i++)
          if (i == existingIdx)
            cart[i].copyWith(quantity: cart[i].quantity + 1)
          else
            cart[i],
      ];
    } else {
      cart = [
        ...cart,
        OrderItemModel(
          id: product.id,
          name: product.name,
          price: product.price,
          quantity: 1,
          note: '',
          image: product.image,
        ),
      ];
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    cart = cart.where((item) => item.id != productId).toList();
    notifyListeners();
  }

  void updateQuantity(String productId, int amount) {
    final idx = cart.indexWhere((item) => item.id == productId);
    if (idx >= 0) {
      final newQty = cart[idx].quantity + amount;
      if (newQty <= 0) {
        cart = [...cart.sublist(0, idx), ...cart.sublist(idx + 1)];
      } else {
        cart = [
          for (int i = 0; i < cart.length; i++)
            if (i == idx) cart[i].copyWith(quantity: newQty) else cart[i],
        ];
      }
      notifyListeners();
    }
  }

  void addNote(String productId, String note) {
    cart = cart
        .map((item) => item.id == productId ? item.copyWith(note: note) : item)
        .toList();
    notifyListeners();
  }

  void clearCart() {
    cart = [];
    notifyListeners();
  }

  double getCartTotal() {
    return cart.fold(0.0, (total, item) => total + (item.price * item.quantity));
  }

  int get cartItemCount =>
      cart.fold(0, (total, item) => total + item.quantity);

  // ── Selections ──────────────────────────────────────────
  void setSelectedTable(String table) {
    selectedTable = table;
    notifyListeners();
  }

  void setCategory(String category) {
    selectedCategory = category;
    searchQuery = '';
    _searchDebounce?.cancel();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    if (query.isNotEmpty && selectedCategory != 'all') {
      selectedCategory = 'all';
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      notifyListeners();
    });
  }

  void setSadminViewStoreId(String storeId) {
    sadminViewStoreId = storeId;
    notifyListeners();
  }

  // ── Toast ───────────────────────────────────────────────
  void showToast(String message, [String type = 'success']) {
    toastMessage = message;
    toastType = type;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (toastMessage == message) {
        toastMessage = null;
        // Avoid broad rebuild for toast clear — only update if visible
        super.notifyListeners();
      }
    });
  }

  // ── Confirm Dialog ──────────────────────────────────────
  void showConfirm(
    String message,
    VoidCallback onConfirm, {
    String? title,
    String? description,
    String? itemName,
    String? itemSubtitle,
    IconData? icon,
    String? avatarInitials,
    Color? avatarColor,
    String? confirmLabel,
  }) {
    confirmDialog = ConfirmDialogData(
      message: message,
      onConfirm: onConfirm,
      title: title,
      description: description,
      itemName: itemName,
      itemSubtitle: itemSubtitle,
      icon: icon,
      avatarInitials: avatarInitials,
      avatarColor: avatarColor,
      confirmLabel: confirmLabel,
    );
    notifyListeners();
  }

  void closeConfirm() {
    confirmDialog = null;
    notifyListeners();
  }

  // ── Upgrade Modal ───────────────────────────────────────
  void setUpgradeModalOpen(bool isOpen) {
    isUpgradeModalOpen = isOpen;
    notifyListeners();
  }

  // ── Notifications ───────────────────────────────────────
  void markNotificationAsRead(String id) {
    final oldNotifications = List<NotificationModel>.from(notifications);
    _optimistic(
      apply: () {
        notifications = notifications.map((n) => n.id == id ? n.copyWith(read: true) : n).toList();
      },
      remote: () => _supabase.from('notifications').update({'read': true}).eq('id', id),
      rollback: () { notifications = oldNotifications; },
    );
  }

  void clearNotifications(String userId) {
    final oldNotifications = List<NotificationModel>.from(notifications);
    _optimistic(
      apply: () { notifications.removeWhere((n) => n.userId == userId); },
      remote: () => _supabase.from('notifications').delete().eq('user_id', userId),
      rollback: () { notifications = oldNotifications; },
    );
  }

  // ── VIP ─────────────────────────────────────────────────
  void clearVipCongrat(String username) {
    final oldUsers = List<UserModel>.from(users);
    final oldCurrentUser = currentUser;
    _optimistic(
      apply: () {
        users = users.map((u) => u.username == username ? u.copyWith(showVipCongrat: false) : u).toList();
        if (currentUser?.username == username) {
          currentUser = currentUser!.copyWith(showVipCongrat: false);
        }
      },
      remote: () => _supabase.from('users').update({'show_vip_congrat': false}).eq('username', username),
      rollback: () {
        users = oldUsers;
        currentUser = oldCurrentUser;
      },
    );
  }

  void closeVipExpiredModal(String username) {
    final oldUsers = List<UserModel>.from(users);
    final oldCurrentUser = currentUser;
    _optimistic(
      apply: () {
        users = users.map((u) => u.username == username ? u.copyWith(showVipExpired: false) : u).toList();
        if (currentUser?.username == username) {
          currentUser = currentUser!.copyWith(showVipExpired: false);
        }
      },
      remote: () => _supabase.from('users').update({'show_vip_expired': false}).eq('username', username),
      rollback: () {
        users = oldUsers;
        currentUser = oldCurrentUser;
      },
    );
  }

  // ── Upgrade Requests ────────────────────────────────────
  static const List<int> planPrices = [250000, 600000, 900000, 1500000];

  void requestUpgrade(
      String username, int planIndex, String planName, int months) {
    if (upgradeRequests.any((r) => r.username == username && r.status == 'pending')) {
      showToast('Bạn đã có yêu cầu đang chờ thanh toán!', 'error');
      return;
    }
    final reqId = DateTime.now().millisecondsSinceEpoch.toString();
    final storeName = currentStoreInfo.name.isNotEmpty
        ? currentStoreInfo.name
        : username;
    // Remove spaces and special chars for bank transfer content
    final cleanStoreName = storeName.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final cleanPlanName = planName.toUpperCase().replaceAll(' ', '');
    final transferContent = '$cleanStoreName $cleanPlanName';
    final amount = planIndex < planPrices.length ? planPrices[planIndex] : 250000;

    final newReq = {
      'id': reqId,
      'username': username,
      'plan_index': planIndex,
      'plan_name': planName,
      'months': months,
      'time': DateTime.now().toIso8601String(),
      'status': 'pending',
      'transfer_content': transferContent,
      'amount': amount,
    };
    final reqModel = UpgradeRequestModel.fromMap(newReq);
    _optimistic(
      apply: () {
        upgradeRequests.add(reqModel);
        isUpgradeModalOpen = false;
      },
      remote: () async {
        await _supabase.from('upgrade_requests').insert(newReq);
        // Send notification to all sadmin users
        final sadmins = users.where((u) => u.role == 'sadmin').toList();
        for (final sa in sadmins) {
          await _supabase.from('notifications').insert({
            'id': 'noti_upgrade_$reqId',
            'user_id': sa.username,
            'title': 'Yêu cầu nâng cấp Premium',
            'message': '$username đã đăng ký gói $planName. Chờ thanh toán.',
            'type': 'upgrade',
            'time': DateTime.now().toIso8601String(),
            'read': false,
          });
        }
      },
      rollback: () {
        upgradeRequests.removeWhere((r) => r.id == reqModel.id);
      },
      errorMsg: 'Gửi yêu cầu nâng cấp thất bại, đã hoàn tác',
    );
  }

  Future<void> approveUpgrade(String requestId) async {
    final req = upgradeRequests.firstWhere((r) => r.id == requestId,
        orElse: () => const UpgradeRequestModel(
            id: '', username: '', planIndex: 0, planName: '', months: 0, time: ''));
    if (req.id.isEmpty) return;

    final targetUser =
        users.firstWhere((u) => u.username == req.username,
            orElse: () => const UserModel(username: '', pass: '', role: ''));
    if (targetUser.username.isEmpty) {
      showToast('Không tìm thấy tài khoản', 'error');
      return;
    }

    var baseDate = (targetUser.expiresAt != null &&
            DateTime.parse(targetUser.expiresAt!).isAfter(DateTime.now()))
        ? DateTime.parse(targetUser.expiresAt!)
        : DateTime.now();
    baseDate = baseDate.add(Duration(days: req.months * 30));

    await _supabase.from('users').update({
      'is_premium': true,
      'expires_at': baseDate.toIso8601String(),
      'show_vip_congrat': true,
    }).eq('username', req.username);
    await _supabase
        .from('store_infos')
        .update({'is_premium': true})
        .eq('store_id', req.username);
    await _supabase.from('upgrade_requests').delete().eq('id', requestId);

    showToast('Đã duyệt gói ${req.planName} cho ${req.username}');
    upgradeRequests.removeWhere((r) => r.id == requestId);
    users = users.map((u) {
      if (u.username == req.username) {
        return u.copyWith(
          isPremium: true,
          expiresAt: baseDate.toIso8601String(),
          showVipCongrat: true,
        );
      }
      return u;
    }).toList();
    notifyListeners();
  }

  void rejectUpgrade(String requestId) {
    final oldRequests = List<UpgradeRequestModel>.from(upgradeRequests);
    _optimistic(
      apply: () { upgradeRequests.removeWhere((r) => r.id == requestId); },
      remote: () => _supabase.from('upgrade_requests').delete().eq('id', requestId),
      rollback: () { upgradeRequests = oldRequests; },
      errorMsg: 'Từ chối yêu cầu thất bại, đã hoàn tác',
    );
  }

  // ── Notification Sound ─────────────────────────────────
  void _playNewOrderSound() async {
    try {
      await _orderSoundPlayer.stop();
      await _orderSoundPlayer.setSource(AssetSource('sounds/new_order.wav'));
      await _orderSoundPlayer.resume();
      debugPrint('[Sound] ✅ Played new order notification sound');
    } catch (e) {
      debugPrint('[Sound] ❌ Error playing notification: $e');
    }
  }

  // ── Realtime ────────────────────────────────────────────
  void _setupRealtime(UserModel user, String? storeId) {
    _removeRealtimeChannels();

    // Orders realtime
    _ordersChannel = _supabase.channel('orders-changes').onPostgresChanges(
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
        debugPrint('[Realtime] Orders event: ${payload.eventType} | id=${payload.newRecord['id']}');
        if (payload.eventType == PostgresChangeEvent.insert) {
          final newOrder = OrderModel.fromMap(payload.newRecord);
          debugPrint('[Realtime] ✅ New order received: ${newOrder.id} | table=${newOrder.table} | store=${newOrder.storeId}');
          if (!orders.any((o) => o.id == newOrder.id)) {
            orders.insert(0, newOrder);
            _playNewOrderSound();
            // Also write to Drift (marking as synced since it came from server)
            if (_db != null) {
              await _db!.upsertOrder(LocalOrdersCompanion(
                id: Value(newOrder.id),
                storeId: Value(newOrder.storeId),
                orderTable: Value(newOrder.table),
                itemsJson: Value(jsonEncode(newOrder.items.map((i) => i.toMap()).toList())),
                status: Value(newOrder.status),
                paymentStatus: Value(newOrder.paymentStatus),
                totalAmount: Value(newOrder.totalAmount),
                createdBy: Value(newOrder.createdBy),
                time: Value(newOrder.time),
                paymentMethod: Value(newOrder.paymentMethod),
                isSynced: const Value(true),
              ));
            }
            notifyListeners();
            debugPrint('[Realtime] ✅ Order added to list + Drift, sound triggered');
          } else {
            debugPrint('[Realtime] ⚠️ Order ${newOrder.id} already exists, skipped');
          }
        } else if (payload.eventType == PostgresChangeEvent.update) {
          final rec = payload.newRecord;
          final id = rec['id']?.toString() ?? '';
          final idx = orders.indexWhere((o) => o.id == id);
          // Skip if there's a pending local sync for this order (local wins)
          final hasPending = _db != null ? await _db!.hasPendingSync(id) : false;
          if (hasPending) {
            debugPrint('[Realtime] ⚠️ Order $id has pending sync, skipping server update');
            return;
          }
          if (idx != -1) {
            final existing = orders[idx];
            // Merge: use new values if present, keep existing otherwise
            // Supabase Realtime may not include JSONB columns like 'items'
            final updatedItems = rec['items'] != null
                ? (rec['items'] as List<dynamic>)
                    .map((e) => OrderItemModel.fromMap(e as Map<String, dynamic>))
                    .toList()
                : existing.items;
            orders[idx] = existing.copyWith(
              status: rec['status'] ?? existing.status,
              paymentStatus: rec['payment_status'] ?? existing.paymentStatus,
              paymentMethod: (rec['payment_method'] != null && (rec['payment_method'] as String).isNotEmpty)
                  ? rec['payment_method'] as String
                  : existing.paymentMethod,
              totalAmount: rec['total_amount'] != null
                  ? (rec['total_amount'] as num).toDouble()
                  : null,
              items: updatedItems,
            );
            // Update Drift too
            if (_db != null) await _updateOrderInDrift(id);
            notifyListeners();
          }
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final deletedId = payload.oldRecord['id']?.toString() ?? '';
          orders.removeWhere((o) => o.id == deletedId);
          if (_db != null) {
            await (_db!.delete(_db!.localOrders)..where((t) => t.id.equals(deletedId))).go();
          }
          notifyListeners();
        }
      },
    ).subscribe();

    // Products realtime
    _productsChannel = _supabase.channel('products-changes').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'products',
      filter: storeId != null
          ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'store_id',
              value: storeId,
            )
          : null,
      callback: (payload) {
        if (payload.eventType == PostgresChangeEvent.insert) {
          final p = ProductModel.fromMap(payload.newRecord);
          final existing = products[p.storeId] ?? [];
          if (!existing.any((x) => x.id == p.id)) {
            products[p.storeId] = [p, ...existing];
            notifyListeners();
          }
        } else if (payload.eventType == PostgresChangeEvent.update) {
          final p = ProductModel.fromMap(payload.newRecord);
          products[p.storeId] = (products[p.storeId] ?? [])
              .map((x) => x.id == p.id ? p : x)
              .toList();
          notifyListeners();
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final sid = payload.oldRecord['store_id'] as String?;
          final pid = payload.oldRecord['id'];
          if (sid != null) {
            products[sid] = (products[sid] ?? [])
                .where((x) => x.id != pid)
                .toList();
            notifyListeners();
          }
        }
      },
    ).subscribe();

    // Notifications realtime
    _notiChannel = _supabase
        .channel('notifications-${user.username}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.username,
          ),
          callback: (payload) {
            final n = NotificationModel.fromMap(payload.newRecord);
            notifications.insert(0, n);
            notifyListeners();
          },
        )
        .subscribe();

    // Upgrade requests realtime (all users — for payment status updates)
    _upgradeChannel = _supabase.channel('upgrade-requests').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'upgrade_requests',
      callback: (payload) {
        if (payload.eventType == PostgresChangeEvent.insert) {
          final r = UpgradeRequestModel.fromMap(payload.newRecord);
          if (!upgradeRequests.any((x) => x.id == r.id)) {
            upgradeRequests.insert(0, r);
            notifyListeners();
          }
        } else if (payload.eventType == PostgresChangeEvent.update) {
          final r = UpgradeRequestModel.fromMap(payload.newRecord);
          upgradeRequests = upgradeRequests
              .map((x) => x.id == r.id ? r : x)
              .toList();
          notifyListeners();
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          upgradeRequests.removeWhere(
              (x) => x.id == payload.oldRecord['id']?.toString());
          notifyListeners();
        }
      },
    ).subscribe();

    // Thu Chi Transactions realtime
    _thuChiChannel = _supabase.channel('thu-chi-changes').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'thu_chi_transactions',
      filter: storeId != null
          ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'store_id',
              value: storeId,
            )
          : null,
      callback: (payload) {
        if (payload.eventType == PostgresChangeEvent.insert) {
          final t = ThuChiTransaction.fromMap(payload.newRecord);
          if (!thuChiTransactions.any((x) => x.id == t.id)) {
            thuChiTransactions = [t, ...thuChiTransactions];
            notifyListeners();
          }
        } else if (payload.eventType == PostgresChangeEvent.update) {
          final t = ThuChiTransaction.fromMap(payload.newRecord);
          thuChiTransactions = thuChiTransactions
              .map((x) => x.id == t.id ? t : x)
              .toList();
          notifyListeners();
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          thuChiTransactions = thuChiTransactions
              .where((x) => x.id != payload.oldRecord['id'])
              .toList();
          notifyListeners();
        }
      },
    ).subscribe();

    // Categories realtime
    _categoriesChannel = _supabase.channel('categories-changes').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'categories',
      filter: storeId != null
          ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'store_id',
              value: storeId,
            )
          : null,
      callback: (payload) {
        if (payload.eventType == PostgresChangeEvent.insert) {
          final c = CategoryModel.fromMap(payload.newRecord);
          final existing = categories[c.storeId] ?? [];
          if (!existing.any((x) => x.id == c.id)) {
            categories[c.storeId] = [...existing, c];
            notifyListeners();
          }
        } else if (payload.eventType == PostgresChangeEvent.update) {
          final c = CategoryModel.fromMap(payload.newRecord);
          categories[c.storeId] = (categories[c.storeId] ?? [])
              .map((x) => x.id == c.id ? c : x)
              .toList();
          notifyListeners();
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final sid = payload.oldRecord['store_id'] as String?;
          final cid = payload.oldRecord['id'];
          if (sid != null) {
            categories[sid] = (categories[sid] ?? [])
                .where((x) => x.id != cid)
                .toList();
            notifyListeners();
          }
        }
      },
    ).subscribe();

    // Users realtime (admin sees staff changes)
    _usersChannel = _supabase.channel('users-changes').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'users',
      callback: (payload) {
        if (payload.eventType == PostgresChangeEvent.insert) {
          final u = UserModel.fromMap(payload.newRecord);
          if (!users.any((x) => x.username == u.username)) {
            users.add(u);
            notifyListeners();
          }
        } else if (payload.eventType == PostgresChangeEvent.update) {
          final u = UserModel.fromMap(payload.newRecord);
          users = users
              .map((x) => x.username == u.username ? u : x)
              .toList();
          // Also update currentUser if it's the same user
          if (currentUser?.username == u.username) {
            currentUser = u;
          }
          notifyListeners();
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          users.removeWhere(
              (x) => x.username == payload.oldRecord['username']);
          notifyListeners();
        }
      },
    ).subscribe();

    // Store info realtime
    _storeInfoChannel = _supabase.channel('store-info-changes').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'store_infos',
      callback: (payload) {
        if (payload.eventType == PostgresChangeEvent.insert ||
            payload.eventType == PostgresChangeEvent.update) {
          final sid = payload.newRecord['store_id'] as String?;
          if (sid != null) {
            storeInfos[sid] = StoreInfoModel.fromMap(payload.newRecord);
            notifyListeners();
          }
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final sid = payload.oldRecord['store_id'] as String?;
          if (sid != null) {
            storeInfos.remove(sid);
            notifyListeners();
          }
        }
      },
    ).subscribe();
  }

  void _removeRealtimeChannels() {
    if (_ordersChannel != null) _supabase.removeChannel(_ordersChannel!);
    if (_productsChannel != null) _supabase.removeChannel(_productsChannel!);
    if (_notiChannel != null) _supabase.removeChannel(_notiChannel!);
    if (_upgradeChannel != null) _supabase.removeChannel(_upgradeChannel!);
    if (_thuChiChannel != null) _supabase.removeChannel(_thuChiChannel!);
    if (_categoriesChannel != null) _supabase.removeChannel(_categoriesChannel!);
    if (_usersChannel != null) _supabase.removeChannel(_usersChannel!);
    if (_storeInfoChannel != null) _supabase.removeChannel(_storeInfoChannel!);
    _ordersChannel = null;
    _productsChannel = null;
    _notiChannel = null;
    _upgradeChannel = null;
    _thuChiChannel = null;
    _categoriesChannel = null;
    _usersChannel = null;
    _storeInfoChannel = null;
  }

  // ── Processing Badges (cached) ─────────────────────────────
  List<String> get storeUsernames {
    if (_cachedStoreUsernames != null) return _cachedStoreUsernames!;
    if (currentUser == null) return const [];
    final sid = getStoreId();
    List<String> result;
    if (currentUser!.role == 'sadmin') {
      if (sid == 'sadmin') {
        result = users.map((u) => u.username).toList();
      } else {
        result = users
            .where((u) => u.username == sid || u.createdBy == sid)
            .map((u) => u.username)
            .toList();
      }
    } else {
      final owner = currentUser!.role == 'staff'
          ? (currentUser!.createdBy ?? currentUser!.username)
          : currentUser!.username;
      result = users
          .where((u) => u.username == owner || u.createdBy == owner)
          .map((u) => u.username)
          .toList();
    }
    _cachedStoreUsernames = result;
    return result;
  }

  List<OrderModel> get storeOrders {
    if (_cachedStoreOrders != null) return _cachedStoreOrders!;
    final usernames = storeUsernames;
    final usernameSet = usernames.toSet();
    _cachedStoreOrders = orders.where((o) => usernameSet.contains(o.createdBy)).toList();
    return _cachedStoreOrders!;
  }

  int get pendingProcessing =>
      visibleOrders.where((o) => o.status == 'pending').length;

  int get cookingProcessing =>
      visibleOrders.where((o) => o.status == 'cooking').length;

  int get unpaidTables =>
      storeOrders.where((o) => o.status == 'cooking').length;

  // ── Visible Orders (cached) ─────────────────────────────
  List<OrderModel> get visibleOrders {
    if (_cachedVisibleOrders != null) return _cachedVisibleOrders!;
    final sid = getStoreId();
    var list = orders.toList();
    if (currentUser?.role != 'sadmin') {
      list = list.where((o) =>
          o.storeId == sid || (o.storeId.isEmpty && sid == 'sadmin')).toList();
    } else if (sadminViewStoreId != 'all') {
      list = list.where((o) =>
          o.storeId == sadminViewStoreId ||
          (o.storeId.isEmpty && sadminViewStoreId == 'sadmin')).toList();
    }
    if (currentUser?.role == 'staff') {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      list = list.where((o) => o.time.startsWith(todayStr)).toList();
    }
    _cachedVisibleOrders = list;
    return list;
  }
}

class ConfirmDialogData {
  final String message;
  final VoidCallback onConfirm;
  final String? title;
  final String? description;
  final String? itemName;
  final String? itemSubtitle;
  final IconData? icon;
  final String? avatarInitials;
  final Color? avatarColor;
  final String? confirmLabel;
  const ConfirmDialogData({
    required this.message,
    required this.onConfirm,
    this.title,
    this.description,
    this.itemName,
    this.itemSubtitle,
    this.icon,
    this.avatarInitials,
    this.avatarColor,
    this.confirmLabel,
  });
}

/// Lightweight [ChangeNotifier] that fires ONLY on auth state changes.
/// Used by GoRouter.refreshListenable so the router doesn't
/// re-evaluate redirects on every cart/toast/search update.
class AuthNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
