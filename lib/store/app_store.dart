import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/store_info_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/notification_model.dart';
import '../models/upgrade_request_model.dart';

class AppStore extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Lightweight notifier that ONLY fires when auth state changes (login/logout).
  /// Used by GoRouter.refreshListenable so router doesn't re-evaluate on every
  /// cart/toast/search change.
  final AuthNotifier authNotifier = AuthNotifier();

  // ── Auth & Users ─────────────────────────────────────────
  UserModel? currentUser;
  List<UserModel> users = [];
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

      // Load users
      final usersData = await _supabase.from('users').select();
      users = (usersData as List).map((u) => UserModel.fromMap(u)).toList();

      // Load storeInfos
      final storeInfosData = await _supabase.from('store_infos').select();
      storeInfos = {'sadmin': const StoreInfoModel(name: 'Nhà Hàng Của Tôi', isPremium: true)};
      for (final s in storeInfosData) {
        storeInfos[s['store_id']] = StoreInfoModel.fromMap(s);
      }

      // Load storeTables
      final tablesData = await _supabase
          .from('store_tables')
          .select()
          .order('sort_order');
      storeTables = {};
      for (final t in tablesData) {
        final sid = t['store_id'] as String;
        storeTables.putIfAbsent(sid, () => []);
        storeTables[sid]!.add(t['name'] as String);
      }

      // Load categories
      final catsData = await _supabase.from('categories').select();
      categories = {};
      for (final c in catsData) {
        final sid = c['store_id'] as String;
        categories.putIfAbsent(sid, () => []);
        categories[sid]!.add(CategoryModel.fromMap(c));
      }

      // Load products
      final prodsData = await _supabase.from('products').select();
      products = {};
      for (final p in prodsData) {
        final sid = p['store_id'] as String;
        products.putIfAbsent(sid, () => []);
        products[sid]!.add(ProductModel.fromMap(p));
      }

      // Load orders
      final isPremium = user.isPremium || user.role == 'sadmin';
      final daysToKeep = isPremium ? 365 : 3;
      final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));
      PostgrestFilterBuilder ordersQuery = _supabase
          .from('orders')
          .select()
          .gte('time', cutoff.toIso8601String());
      if (storeId != null) {
        ordersQuery = ordersQuery.eq('store_id', storeId);
      }
      final ordersData = await ordersQuery.order('time', ascending: false);
      orders = (ordersData as List).map((o) => OrderModel.fromMap(o)).toList();

      // Load notifications
      final notiData = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', user.username)
          .order('time', ascending: false);
      notifications =
          (notiData as List).map((n) => NotificationModel.fromMap(n)).toList();

      // Load upgrade requests
      final upgradeData = await _supabase
          .from('upgrade_requests')
          .select()
          .order('time', ascending: false);
      upgradeRequests = (upgradeData as List)
          .map((r) => UpgradeRequestModel.fromMap(r))
          .toList();

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
      return 'success';
    } catch (e) {
      debugPrint('[login] $e');
      return 'invalid';
    }
  }

  // ── Register ────────────────────────────────────────────
  Future<String> register({
    required String fullname,
    required String phone,
    required String storeName,
    required String username,
    required String password,
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
      await _supabase.from('store_infos').insert({
        'store_id': username,
        'name': storeName.isNotEmpty ? storeName : fullname,
        'phone': phone,
        'is_premium': false,
      });

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
    cart = [];
    selectedTable = '';
    authNotifier.notify();
    notifyListeners();
  }

  // ── Update User ─────────────────────────────────────────
  Future<void> updateUser(String username, Map<String, dynamic> updatedData) async {
    final dbData = <String, dynamic>{};
    if (updatedData.containsKey('fullname')) dbData['fullname'] = updatedData['fullname'];
    if (updatedData.containsKey('phone')) dbData['phone'] = updatedData['phone'];
    if (updatedData.containsKey('pass')) dbData['pass'] = updatedData['pass'];
    if (updatedData.containsKey('isPremium')) dbData['is_premium'] = updatedData['isPremium'];
    if (updatedData.containsKey('expiresAt')) dbData['expires_at'] = updatedData['expiresAt'];
    if (updatedData.containsKey('showVipExpired')) dbData['show_vip_expired'] = updatedData['showVipExpired'];
    if (updatedData.containsKey('showVipCongrat')) dbData['show_vip_congrat'] = updatedData['showVipCongrat'];
    if (updatedData.containsKey('avatar')) dbData['avatar'] = updatedData['avatar'];

    try {
      await _supabase.from('users').update(dbData).eq('username', username);
      showToast('Cập nhật thông tin thành công!');

      // Update local state
      users = users.map((u) {
        if (u.username == username) {
          return UserModel(
            username: u.username,
            pass: updatedData['pass'] ?? u.pass,
            role: u.role,
            fullname: updatedData['fullname'] ?? u.fullname,
            phone: updatedData['phone'] ?? u.phone,
            avatar: updatedData['avatar'] ?? u.avatar,
            isPremium: updatedData['isPremium'] ?? u.isPremium,
            expiresAt: updatedData['expiresAt'] ?? u.expiresAt,
            createdBy: u.createdBy,
            showVipExpired: updatedData['showVipExpired'] ?? u.showVipExpired,
            showVipCongrat: updatedData['showVipCongrat'] ?? u.showVipCongrat,
          );
        }
        return u;
      }).toList();

      if (currentUser?.username == username) {
        currentUser = users.firstWhere((u) => u.username == username);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[updateUser] $e');
      showToast('Có lỗi kết nối CSDL', 'error');
    }
  }

  // ── Delete User ─────────────────────────────────────────
  Future<void> deleteUser(String username) async {
    try {
      await _supabase.from('users').delete().eq('username', username);
      showToast('Đã xoá người dùng $username');
      users.removeWhere((u) => u.username == username);
      notifyListeners();
    } catch (e) {
      debugPrint('[deleteUser] $e');
      showToast('Xoá hỏng do lỗi mạng', 'error');
    }
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
  Future<void> updateStoreInfo(StoreInfoModel info) async {
    final storeId = getStoreId();
    final dbData = {
      'name': info.name,
      'phone': info.phone,
      'address': info.address,
      'logo_url': info.logoUrl,
      'bank_id': info.bankId,
      'bank_account': info.bankAccount,
      'bank_owner': info.bankOwner,
    };
    dbData.removeWhere((k, v) => v.toString().isEmpty);
    await _supabase
        .from('store_infos')
        .upsert({'store_id': storeId, ...dbData});
    storeInfos[storeId] = info;
    notifyListeners();
  }

  // ── Tables ──────────────────────────────────────────────
  Future<void> addTable(String tableName) async {
    final storeId = getStoreId();
    final currentTablesList = storeTables[storeId] ?? [];
    if (currentTablesList.contains(tableName)) return;
    await _supabase.from('store_tables').insert({
      'store_id': storeId,
      'name': tableName,
      'sort_order': currentTablesList.length,
    });
    storeTables.putIfAbsent(storeId, () => []);
    storeTables[storeId]!.add(tableName);
    notifyListeners();
  }

  Future<void> removeTable(String tableName) async {
    final storeId = getStoreId();
    await _supabase
        .from('store_tables')
        .delete()
        .eq('store_id', storeId)
        .eq('name', tableName);
    storeTables[storeId]?.remove(tableName);
    if (selectedTable == tableName) {
      selectedTable = storeTables[storeId]?.isNotEmpty == true
          ? storeTables[storeId]!.first
          : '';
    }
    notifyListeners();
  }

  Future<void> updateTable(String oldName, String newName) async {
    if (oldName.isEmpty || newName.isEmpty || oldName == newName) return;
    final storeId = getStoreId();
    await _supabase
        .from('store_tables')
        .update({'name': newName})
        .eq('store_id', storeId)
        .eq('name', oldName);
    final tablesList = storeTables[storeId] ?? [];
    final idx = tablesList.indexOf(oldName);
    if (idx >= 0) tablesList[idx] = newName;
    if (selectedTable == oldName) selectedTable = newName;
    notifyListeners();
  }

  // ── Categories ──────────────────────────────────────────
  Future<void> addCategory(String categoryName) async {
    final storeId = getStoreId();
    final newCat = {
      'id': 'cat_${DateTime.now().millisecondsSinceEpoch}',
      'store_id': storeId,
      'name': categoryName,
    };
    await _supabase.from('categories').insert(newCat);
    categories.putIfAbsent(storeId, () => []);
    categories[storeId]!.add(CategoryModel.fromMap(newCat));
    notifyListeners();
  }

  Future<void> updateCategory(CategoryModel updatedCategory) async {
    final storeId = getStoreId();
    await _supabase
        .from('categories')
        .update({'name': updatedCategory.name})
        .eq('id', updatedCategory.id);
    categories[storeId] = (categories[storeId] ?? [])
        .map((c) => c.id == updatedCategory.id ? updatedCategory : c)
        .toList();
    notifyListeners();
  }

  Future<void> deleteCategory(String categoryId) async {
    final storeId = getStoreId();
    await _supabase.from('categories').delete().eq('id', categoryId);
    await _supabase
        .from('products')
        .update({'category': ''})
        .eq('store_id', storeId)
        .eq('category', categoryId);
    categories[storeId]?.removeWhere((c) => c.id == categoryId);
    products[storeId] = (products[storeId] ?? []).map((p) {
      return p.category == categoryId ? p.copyWith(category: '') : p;
    }).toList();
    notifyListeners();
  }

  // ── Products ────────────────────────────────────────────
  Future<void> addProduct(ProductModel product) async {
    final storeId = getStoreId();
    final newProd = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'store_id': storeId,
      'name': product.name,
      'price': product.price,
      'image': product.image,
      'category': product.category,
      'description': product.description,
    };
    await _supabase.from('products').insert(newProd);
    products.putIfAbsent(storeId, () => []);
    products[storeId]!.insert(0, product.copyWith(id: newProd['id'] as String, storeId: storeId));
    notifyListeners();
  }

  Future<void> updateProduct(ProductModel updatedProduct) async {
    final storeId = getStoreId();
    await _supabase.from('products').update({
      'name': updatedProduct.name,
      'price': updatedProduct.price,
      'image': updatedProduct.image,
      'category': updatedProduct.category,
      'description': updatedProduct.description,
    }).eq('id', updatedProduct.id);
    products[storeId] = (products[storeId] ?? [])
        .map((p) => p.id == updatedProduct.id ? updatedProduct : p)
        .toList();
    notifyListeners();
  }

  Future<void> deleteProduct(String productId) async {
    final storeId = getStoreId();
    await _supabase.from('products').delete().eq('id', productId);
    products[storeId]?.removeWhere((p) => p.id == productId);
    notifyListeners();
  }

  // ── Orders ──────────────────────────────────────────────
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _supabase.from('orders').update({'status': status}).eq('id', orderId);
    orders = orders
        .map((o) => o.id == orderId ? o.copyWith(status: status) : o)
        .toList();
    notifyListeners();
  }

  Future<void> updateOrderPaymentStatus(
      String orderId, String paymentStatus) async {
    await _supabase
        .from('orders')
        .update({'payment_status': paymentStatus})
        .eq('id', orderId);
    orders = orders
        .map((o) =>
            o.id == orderId ? o.copyWith(paymentStatus: paymentStatus) : o)
        .toList();
    notifyListeners();
  }

  Future<void> updateOrderItemStatus(
      String orderId, String itemId, bool isDone) async {
    final order = orders.firstWhere((o) => o.id == orderId,
        orElse: () => const OrderModel(id: ''));
    if (order.id.isEmpty) return;
    final newItems =
        order.items.map((i) => i.id == itemId ? i.copyWith(isDone: isDone) : i).toList();
    await _supabase
        .from('orders')
        .update({'items': newItems.map((i) => i.toMap()).toList()})
        .eq('id', orderId);
    orders = orders
        .map((o) => o.id == orderId ? o.copyWith(items: newItems) : o)
        .toList();
    notifyListeners();
  }

  Future<void> updateOrderItems(
      String orderId, List<OrderItemModel> newItems, double newTotal) async {
    await _supabase.from('orders').update({
      'items': newItems.map((i) => i.toMap()).toList(),
      'total_amount': newTotal,
    }).eq('id', orderId);
    orders = orders
        .map((o) => o.id == orderId
            ? o.copyWith(items: newItems, totalAmount: newTotal)
            : o)
        .toList();
    notifyListeners();
  }

  Future<void> cancelOrder(String orderId) async {
    await _supabase.from('orders').delete().eq('id', orderId);
    orders.removeWhere((o) => o.id == orderId);
    notifyListeners();
  }

  Future<void> checkoutOrder({String paymentStatus = 'unpaid'}) async {
    if (cart.isEmpty) return;

    final totalAmount = getCartTotal();
    final storeId = getStoreId();
    final orderId =
        'ORD-${Random().nextInt(10000).toString().padLeft(4, '0')}';

    final newOrder = {
      'id': orderId,
      'store_id': storeId,
      'table_name': selectedTable,
      'items': cart.map((item) => item.copyWith(isDone: false).toMap()).toList(),
      'status': 'pending',
      'payment_status': paymentStatus,
      'time': DateTime.now().toIso8601String(),
      'total_amount': totalAmount,
      'created_by': currentUser?.username ?? 'unknown',
    };

    try {
      await _supabase.from('orders').insert(newOrder);
      orders.insert(0, OrderModel.fromMap(newOrder));
      cart.clear();
      notifyListeners();
    } catch (e) {
      showToast('Tạo đơn thất bại', 'error');
    }
  }

  // ── Cart ────────────────────────────────────────────────
  void addToCart(ProductModel product) {
    final existingIdx = cart.indexWhere((item) => item.id == product.id);
    if (existingIdx >= 0) {
      cart[existingIdx] =
          cart[existingIdx].copyWith(quantity: cart[existingIdx].quantity + 1);
    } else {
      cart.add(OrderItemModel(
        id: product.id,
        name: product.name,
        price: product.price,
        quantity: 1,
        note: '',
        image: product.image,
      ));
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    cart.removeWhere((item) => item.id == productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int amount) {
    final idx = cart.indexWhere((item) => item.id == productId);
    if (idx >= 0) {
      final newQty = cart[idx].quantity + amount;
      if (newQty <= 0) {
        cart.removeAt(idx);
      } else {
        cart[idx] = cart[idx].copyWith(quantity: newQty);
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
    cart.clear();
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
    notifyListeners();
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
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
        notifyListeners();
      }
    });
  }

  // ── Confirm Dialog ──────────────────────────────────────
  void showConfirm(String message, VoidCallback onConfirm) {
    confirmDialog = ConfirmDialogData(message: message, onConfirm: onConfirm);
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
  Future<void> markNotificationAsRead(String id) async {
    await _supabase.from('notifications').update({'read': true}).eq('id', id);
    notifications = notifications
        .map((n) => n.id == id ? n.copyWith(read: true) : n)
        .toList();
    notifyListeners();
  }

  Future<void> clearNotifications(String userId) async {
    await _supabase.from('notifications').delete().eq('user_id', userId);
    notifications.removeWhere((n) => n.userId == userId);
    notifyListeners();
  }

  // ── VIP ─────────────────────────────────────────────────
  Future<void> clearVipCongrat(String username) async {
    await _supabase
        .from('users')
        .update({'show_vip_congrat': false})
        .eq('username', username);
    users = users
        .map((u) =>
            u.username == username ? u.copyWith(showVipCongrat: false) : u)
        .toList();
    if (currentUser?.username == username) {
      currentUser = currentUser!.copyWith(showVipCongrat: false);
    }
    notifyListeners();
  }

  Future<void> closeVipExpiredModal(String username) async {
    await _supabase
        .from('users')
        .update({'show_vip_expired': false})
        .eq('username', username);
    users = users
        .map((u) =>
            u.username == username ? u.copyWith(showVipExpired: false) : u)
        .toList();
    if (currentUser?.username == username) {
      currentUser = currentUser!.copyWith(showVipExpired: false);
    }
    notifyListeners();
  }

  // ── Upgrade Requests ────────────────────────────────────
  Future<void> requestUpgrade(
      String username, int planIndex, String planName, int months) async {
    if (upgradeRequests.any((r) => r.username == username)) {
      showToast('Bạn đã có yêu cầu đang chờ duyệt!', 'error');
      return;
    }
    final newReq = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'username': username,
      'plan_index': planIndex,
      'plan_name': planName,
      'months': months,
      'time': DateTime.now().toIso8601String(),
    };
    await _supabase.from('upgrade_requests').insert(newReq);
    showToast('Đã gửi yêu cầu nâng cấp $planName!');
    upgradeRequests.add(UpgradeRequestModel.fromMap(newReq));
    isUpgradeModalOpen = false;
    notifyListeners();
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

  Future<void> rejectUpgrade(String requestId) async {
    await _supabase.from('upgrade_requests').delete().eq('id', requestId);
    upgradeRequests.removeWhere((r) => r.id == requestId);
    showToast('Đã từ chối yêu cầu nâng cấp', 'error');
    notifyListeners();
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
      callback: (payload) {
        if (payload.eventType == PostgresChangeEvent.insert) {
          final newOrder = OrderModel.fromMap(payload.newRecord);
          if (!orders.any((o) => o.id == newOrder.id)) {
            orders.insert(0, newOrder);
            notifyListeners();
          }
        } else if (payload.eventType == PostgresChangeEvent.update) {
          final updated = OrderModel.fromMap(payload.newRecord);
          orders = orders
              .map((o) => o.id == updated.id ? updated : o)
              .toList();
          notifyListeners();
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          orders.removeWhere((o) => o.id == payload.oldRecord['id']);
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
          products.putIfAbsent(p.storeId, () => []);
          if (!products[p.storeId]!.any((x) => x.id == p.id)) {
            products[p.storeId]!.insert(0, p);
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
            products[sid]?.removeWhere((x) => x.id == pid);
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

    // Upgrade requests realtime (sadmin only)
    if (user.role == 'sadmin') {
      _upgradeChannel = _supabase.channel('upgrade-requests').onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'upgrade_requests',
        callback: (payload) {
          final r = UpgradeRequestModel.fromMap(payload.newRecord);
          upgradeRequests.insert(0, r);
          notifyListeners();
        },
      ).subscribe();
    }
  }

  void _removeRealtimeChannels() {
    if (_ordersChannel != null) _supabase.removeChannel(_ordersChannel!);
    if (_productsChannel != null) _supabase.removeChannel(_productsChannel!);
    if (_notiChannel != null) _supabase.removeChannel(_notiChannel!);
    if (_upgradeChannel != null) _supabase.removeChannel(_upgradeChannel!);
    _ordersChannel = null;
    _productsChannel = null;
    _notiChannel = null;
    _upgradeChannel = null;
  }

  // ── Kitchen Badges ──────────────────────────────────────
  List<String> get storeUsernames {
    if (currentUser == null) return [];
    final sid = getStoreId();
    if (currentUser!.role == 'sadmin') {
      if (sid == 'sadmin') return users.map((u) => u.username).toList();
      return users
          .where((u) => u.username == sid || u.createdBy == sid)
          .map((u) => u.username)
          .toList();
    }
    final owner = currentUser!.role == 'staff'
        ? (currentUser!.createdBy ?? currentUser!.username)
        : currentUser!.username;
    return users
        .where((u) => u.username == owner || u.createdBy == owner)
        .map((u) => u.username)
        .toList();
  }

  List<OrderModel> get storeOrders =>
      orders.where((o) => storeUsernames.contains(o.createdBy)).toList();

  int get pendingKitchen =>
      storeOrders.where((o) => o.status == 'pending').length;

  int get unpaidTables =>
      storeOrders.where((o) => o.status == 'cooking').length;

  // ── Visible Orders ──────────────────────────────────────
  List<OrderModel> get visibleOrders {
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
    return list;
  }
}

class ConfirmDialogData {
  final String message;
  final VoidCallback onConfirm;
  const ConfirmDialogData({required this.message, required this.onConfirm});
}

/// Lightweight [ChangeNotifier] that fires ONLY on auth state changes.
/// Used by GoRouter.refreshListenable so the router doesn't
/// re-evaluate redirects on every cart/toast/search update.
class AuthNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
