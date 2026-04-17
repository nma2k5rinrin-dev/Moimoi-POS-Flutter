import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moimoi_pos/features/auth/models/user_model.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/features/settings/models/app_role_model.dart';
import 'package:moimoi_pos/features/notifications/models/notification_model.dart';
import 'package:moimoi_pos/features/premium/models/premium_payment_model.dart';
import 'package:moimoi_pos/features/premium/models/upgrade_request_model.dart';
import 'package:moimoi_pos/core/state/base_mixin.dart';
import 'package:moimoi_pos/core/utils/quota_helper.dart';
import 'package:moimoi_pos/features/premium/presentation/widgets/upgrade_dialog.dart';

import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';

/// Manages Users CRUD, Store Info, Tables, Notifications, and Premium operations.
class ManagementStore extends ChangeNotifier with BaseMixin {
  final AuthStore authStore;
  final QuotaDataProvider quotaProvider;

  ManagementStore({
    required this.authStore,
    required this.quotaProvider,
  });

  @override
  String getStoreId() => quotaProvider.getStoreId();

  // ── State (Managed by AuthStore, required by ManagementStore) ──
  List<UserModel> get users => authStore.users;
  set users(List<UserModel> value) => authStore.users = value;
  
  UserModel? get currentUser => authStore.currentUser;
  set currentUser(UserModel? value) => authStore.currentUser = value;

  Map<String, StoreInfoModel> storeInfos = {
    'sadmin': const StoreInfoModel(name: 'Nhà Hàng Của Tôi', isPremium: true),
  };
  Map<String, List<String>> storeTables = {'sadmin': []};

  List<NotificationModel> notifications = [];
  List<PremiumPaymentModel> premiumPayments = [];
  List<AppRoleModel> appRoles = [];
  List<UpgradeRequestModel> upgradeRequests = [];

  bool hasPermission(String key) {
    if (currentUser?.role == 'admin' || currentUser?.role == 'sadmin') {
      return true;
    }
    final roleId = currentUser?.role;
    if (roleId == null || roleId.isEmpty) return false;
    
    // Backward compatibility with legacy string-based roles
    if (roleId == 'manager') {
      return true; // Managers had full access historically
    }
    if (roleId == 'cashier' || roleId == 'staff') {
      if (key == 'tab_pos' || key == 'tab_orders') return true;
      return false;
    }
    if (roleId == 'kitchen') {
      if (key == 'tab_orders') return true;
      return false;
    }

    try {
      final role = appRoles.firstWhere((r) => r.id == roleId);
      return role.hasPermission(key);
    } catch (_) {
      return false; // Role not found or no permission
    }
  }

  void clearManagementState() {
    users = [];
    currentUser = null;
    storeInfos = {
      'sadmin': const StoreInfoModel(name: 'Nhà Hàng Của Tôi', isPremium: true),
    };
    storeTables = {'sadmin': []};
    notifications = [];
    premiumPayments = [];
    appRoles = [];
    upgradeRequests = [];
  }

  Future<void> initManagementStore(String? storeId, UserModel user) async {
    try {
      var usersQuery = supabaseClient
          .from('users')
          .select(
            'username, role, fullname, phone, is_premium, expires_at, created_by, show_vip_expired, show_vip_congrat',
          );
      if (user.role != 'sadmin') {
        final owner = user.role == 'admin'
            ? user.username
            : (user.createdBy ?? '');
        if (owner.isNotEmpty) {
          usersQuery = usersQuery.or('username.eq.$owner,created_by.eq.$owner');
        }
      }

      var storeInfoQuery = supabaseClient.from('store_infos').select(
        'store_id, name, phone, address, logo_url, tax_id, open_hours, bank_id, bank_account, bank_owner, qr_image_url, is_premium, show_total_products, is_online, premium_activated_at, premium_expires_at, total_offline_days, created_at',
      );
      if (storeId != null) {
        storeInfoQuery = storeInfoQuery
            .eq('store_id', storeId)
            .isFilter('deleted_at', null);
      }

      final tablesQuery = (storeId == null)
          ? Future.value([])
          : supabaseClient
                .from('store_tables')
                .select()
                .eq('store_id', storeId)
                .isFilter('deleted_at', null)
                .order('sort_order');

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      supabaseClient
          .from('notifications')
          .delete()
          .eq('user_id', user.username)
          .lt('time', thirtyDaysAgo)
          .catchError((_) => null);

      final notificationsQuery = supabaseClient
          .from('notifications')
          .select()
          .eq('user_id', user.username)
          .order('time', ascending: false)
          .limit(50);

      var ppQuery = supabaseClient.from('premium_payments').select();
      if (storeId != null && user.role != 'sadmin') {
        ppQuery = ppQuery.eq('store_id', storeId).isFilter('deleted_at', null);
      }

      var urQuery = supabaseClient.from('upgrade_requests').select().eq('status', 'pending');

      var rolesQuery = supabaseClient.from('app_roles').select();
      if (storeId != null && user.role != 'sadmin') {
        rolesQuery = rolesQuery.eq('store_id', storeId);
      }

      final results = await Future.wait([
        usersQuery.catchError((e) { debugPrint('Users error: $e'); return <Map<String,dynamic>>[]; }),
        storeInfoQuery.catchError((e) { debugPrint('StoreInfo error: $e'); return <Map<String,dynamic>>[]; }),
        tablesQuery.catchError((e) { debugPrint('Tables error: $e'); return <Map<String,dynamic>>[]; }),
        notificationsQuery.catchError((e) { debugPrint('Notifications error: $e'); return <Map<String,dynamic>>[]; }),
        ppQuery.order('paid_at', ascending: false).catchError((e) { debugPrint('PremiumPayments error: $e'); return <Map<String,dynamic>>[]; }),
        rolesQuery.catchError((e) { debugPrint('AppRoles error: $e'); return <Map<String,dynamic>>[]; }),
        urQuery.catchError((e) { debugPrint('UpgradeRequests error: $e'); return <Map<String,dynamic>>[]; }),
      ]);

      users = results[0].map((u) => UserModel.fromMap(u)).toList();

      storeInfos = {
        'sadmin': const StoreInfoModel(
          name: 'Nhà Hàng Của Tôi',
          isPremium: true,
        ),
      };
      for (final s in results[1]) {
        final sid = s['store_id']?.toString() ?? '';
        if (sid.isNotEmpty) {
          storeInfos[sid] = StoreInfoModel.fromMap(s);
        }
      }

      for (final entry in storeInfos.entries.toList()) {
        if (entry.key == 'sadmin') continue;
        final info = entry.value;
        if (info.isPremium && info.isExpired) {
          storeInfos[entry.key] = info.copyWith(isPremium: false);
          supabaseClient
              .from('store_infos')
              .update({'is_premium': false})
              .eq('store_id', entry.key)
              .then(
                (_) => debugPrint(
                  '⚠️ Auto-downgraded expired store: ${entry.key}',
                ),
              )
              .catchError(
                (e) =>
                    debugPrint('❌ Failed to downgrade store ${entry.key}: $e'),
              );
        }
      }

      storeTables = {};
      for (final t in results[2]) {
        final sid = t['store_id']?.toString() ?? '';
        final tName = t['table_name']?.toString() ?? '';
        if (sid.isNotEmpty && tName.isNotEmpty) {
          storeTables.putIfAbsent(sid, () => []);
          storeTables[sid]!.add(tName);
        }
      }

      notifications = results[3]
          .map((n) => NotificationModel.fromMap(n))
          .toList();

      premiumPayments = results[4]
          .map((p) => PremiumPaymentModel.fromMap(p))
          .toList();
      appRoles = results[5]
          .map((r) => AppRoleModel.fromMap(r))
          .toList();
      upgradeRequests = results[6]
          .map((ur) => UpgradeRequestModel.fromMap(ur))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('[initManagementStore] $e');
    }
  }

  // ── Realtime Notifications ─────────────────────────────────
  RealtimeChannel? _notiChannel;

  void setupNotificationsRealtime(String username) {
    _notiChannel = supabaseClient
        .channel('notifications-$username')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: username,
          ),
          callback: (payload) {
            final n = NotificationModel.fromMap(payload.newRecord);
            notifications.insert(0, n);
            notifyListeners();
          },
        )
        .subscribe();
  }

  Future<void> broadcastNotification({
    required String title,
    required String message,
    String? target,
  }) async {
    final storeIdToNoti = target ?? 'all_stores';
    final nId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      Iterable<UserModel> targetStaff;

      if (storeIdToNoti == 'all_users') {
        targetStaff = users.where((u) => u.role != 'sadmin');
      } else if (storeIdToNoti == 'all_stores' || storeIdToNoti == 'all') {
        targetStaff = users.where((u) => u.role == 'admin');
      } else {
        targetStaff = users.where((u) => u.username == storeIdToNoti || u.createdBy == storeIdToNoti);
      }

      final payload = targetStaff.map((u) {
        final assignedStoreId = (u.role == 'admin') ? u.username : (u.createdBy ?? '');
        return {
          'id': '${nId}_${u.username}',
          'user_id': u.username,
          'title': title,
          'message': message,
          'time': DateTime.now().toIso8601String(),
          'read': false,
        };
      }).toList();

      if (payload.isNotEmpty) {
        await supabaseClient.from('notifications').insert(payload);
      }
    } catch (e) {
      debugPrint('[ManagementStore] Error broadcasting notification: $e');
    }
  }

  void removeNotificationsRealtime() {
    if (_notiChannel != null) supabaseClient.removeChannel(_notiChannel!);
    _notiChannel = null;
  }

  // ── Derived ───────────────────────────────────────────────
  StoreInfoModel get currentStoreInfo =>
      storeInfos[getStoreId()] ??
      const StoreInfoModel(name: 'Nhà Hàng Của Tôi');

  List<String> get currentTables => storeTables[getStoreId()] ?? [];

  // ── Update User ─────────────────────────────────────────
  void updateUser(String username, Map<String, dynamic> updatedData) {
    final dbData = <String, dynamic>{};
    if (updatedData.containsKey('fullname')) {
      dbData['fullname'] = updatedData['fullname'];
    }
    if (updatedData.containsKey('phone')) {
      dbData['phone'] = updatedData['phone'];
    }
    if (updatedData.containsKey('pass')) dbData['pass'] = updatedData['pass'];
    if (updatedData.containsKey('isPremium')) {
      dbData['is_premium'] = updatedData['isPremium'];
    }
    if (updatedData.containsKey('expiresAt')) {
      dbData['expires_at'] = updatedData['expiresAt'];
    }
    if (updatedData.containsKey('showVipExpired')) {
      dbData['show_vip_expired'] = updatedData['showVipExpired'];
    }
    if (updatedData.containsKey('showVipCongrat')) {
      dbData['show_vip_congrat'] = updatedData['showVipCongrat'];
    }
    if (updatedData.containsKey('avatar')) {
      dbData['avatar'] = updatedData['avatar'];
    }
    if (updatedData.containsKey('role')) dbData['role'] = updatedData['role'];
    if (updatedData.containsKey('createdBy') &&
        updatedData['createdBy'] != null &&
        (updatedData['createdBy'] as String).isNotEmpty) {
      dbData['created_by'] = updatedData['createdBy'];
    }

    final oldUsers = List<UserModel>.from(users);
    final oldCurrentUser = currentUser;

    optimistic(
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
      remote: () async {
        final res = await supabaseClient
            .from('users')
            .update(dbData)
            .eq('username', username)
            .select();
        if (res.isEmpty) {
          throw Exception('RLS block: Không có quyền cập nhật người dùng này.');
        }
      },
      rollback: () {
        users = oldUsers;
        currentUser = oldCurrentUser;
      },
      errorMsg: 'Cập nhật thất bại, đã hoàn tác',
    );
  }

  // ── Delete User ─────────────────────────────────────────
  void deleteUser(String username) {
    if (username == currentUser?.username) {
      showToast('Không thể tự xóa bản thân', 'error');
      return;
    }
    final oldUsers = List<UserModel>.from(users);
    optimistic(
      apply: () {
        users.removeWhere((u) => u.username == username);
      },
      remote: () => supabaseClient.rpc(
        'admin_delete_user',
        params: {'p_username': username},
      ),
      rollback: () {
        users = oldUsers;
      },
      errorMsg: 'Xoá người dùng thất bại, đã hoàn tác',
    );
  }

  // ── Add Staff ───────────────────────────────────────────
  Future<void> addStaff({
    required String fullname,
    required String phone,
    required String username,
    required String password,
    String? storeName,
    String role = 'staff',
    String? createdBy,
  }) async {
    if (users.any((u) => u.username == username)) {
      showToast('Tên đăng nhập đã tồn tại', 'error');
      return;
    }

    final quota = QuotaHelper(quotaProvider);
    if (!quota.canAddStaff) {
      final ctx = rootContext;
      if (ctx != null) await showUpgradePrompt(ctx, quota.staffLimitMsg);
      return;
    }

    try {
      final response = await supabaseClient.rpc(
        'admin_create_user',
        params: {
          'p_username': username,
          'p_password': password,
          'p_role': role,
          'p_fullname': fullname,
          'p_phone': phone,
          'p_created_by': createdBy ?? currentUser?.username,
        },
      );

      final newUserId = response.toString();

      final newStaffRow = {
        'id': newUserId,
        'username': username,
        'role': role,
        'fullname': fullname,
        'phone': phone,
        'avatar': '',
        'is_premium': false,
        'created_by': createdBy ?? currentUser?.username,
      };

      if (role == 'admin') {
        final newStoreInfo = {
          'store_id': username,
          'name': storeName?.isNotEmpty == true
              ? storeName!
              : (fullname.isNotEmpty ? fullname : username),
          'phone': phone,
          'is_premium': false,
          'created_at': DateTime.now().toIso8601String(),
        };
        await supabaseClient.from('store_infos').insert(newStoreInfo);
        storeInfos[username] = StoreInfoModel.fromMap(newStoreInfo);
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
      'show_total_products': info.showTotalProducts,
    };
    // Keep qr_image_url even if empty (user may want to clear it)
    final keepKeys = {'qr_image_url', 'show_total_products'};
    dbData.removeWhere((k, v) => !keepKeys.contains(k) && v.toString().isEmpty);
    optimistic(
      apply: () {
        storeInfos[storeId] = info;
      },
      remote: () => supabaseClient.from('store_infos').upsert({
        'store_id': storeId,
        ...dbData,
      }),
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
      'show_total_products': info.showTotalProducts,
    };
    // Keep qr_image_url even if empty (user may want to clear it)
    final keepKeys = {'qr_image_url', 'show_total_products'};
    dbData.removeWhere((k, v) => !keepKeys.contains(k) && v.toString().isEmpty);
    optimistic(
      apply: () {
        storeInfos[storeId] = info;
      },
      remote: () => supabaseClient.from('store_infos').upsert({
        'store_id': storeId,
        ...dbData,
      }),
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

  void deleteStore(String storeId) {
    final oldStoreInfos = Map<String, StoreInfoModel>.from(storeInfos);
    final oldUsers = List<UserModel>.from(users);
    final staffToDelete = users
        .where((u) => u.createdBy == storeId)
        .map((u) => u.username)
        .toList();

    optimistic(
      apply: () {
        storeInfos.remove(storeId);
        users.removeWhere(
          (u) => u.username == storeId || u.createdBy == storeId,
        );
      },
      remote: () async {
        for (final staffUsername in staffToDelete) {
          await supabaseClient.rpc(
            'admin_delete_user',
            params: {'p_username': staffUsername},
          );
        }
        await supabaseClient.rpc(
          'admin_delete_user',
          params: {'p_username': storeId},
        );
        await supabaseClient
            .from('store_infos')
            .delete()
            .eq('store_id', storeId)
            .isFilter('deleted_at', null);
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
    final quota = QuotaHelper(quotaProvider);
    if (!quota.canAddTable) {
      final ctx = rootContext;
      if (ctx != null) await showUpgradePrompt(ctx, quota.tableLimitMsg);
      return;
    }
    final storeId = getStoreId();
    final currentTablesList = storeTables[storeId] ?? [];
    if (currentTablesList.contains(tableName)) return;
    optimistic(
      apply: () {
        storeTables.putIfAbsent(storeId, () => []);
        storeTables[storeId]!.add(tableName);
      },
      remote: () => supabaseClient.from('store_tables').insert({
        'store_id': storeId,
        'table_name': tableName,
        'sort_order': currentTablesList.length,
      }),
      rollback: () {
        storeTables[storeId]?.remove(tableName);
      },
      errorMsg: 'Thêm bàn thất bại, đã hoàn tác',
    );
  }

  void removeTable(String tableName) {
    final storeId = getStoreId();
    final oldTables = List<String>.from(storeTables[storeId] ?? []);
    optimistic(
      apply: () {
        storeTables[storeId]?.remove(tableName);
      },
      remote: () => supabaseClient
          .from('store_tables')
          .delete()
          .eq('store_id', storeId)
          .isFilter('deleted_at', null)
          .eq('table_name', tableName),
      rollback: () {
        storeTables[storeId] = oldTables;
      },
      errorMsg: 'Xoá bàn thất bại, đã hoàn tác',
    );
  }

  void updateTable(String oldName, String newName) {
    if (oldName.isEmpty || newName.isEmpty || oldName == newName) return;
    final storeId = getStoreId();
    final oldTables = List<String>.from(storeTables[storeId] ?? []);
    optimistic(
      apply: () {
        final tablesList = storeTables[storeId] ?? [];
        final idx = tablesList.indexOf(oldName);
        if (idx >= 0) tablesList[idx] = newName;
      },
      remote: () => supabaseClient
          .from('store_tables')
          .update({'table_name': newName})
          .eq('store_id', storeId)
          .isFilter('deleted_at', null)
          .eq('table_name', oldName),
      rollback: () {
        storeTables[storeId] = oldTables;
      },
      errorMsg: 'Cập nhật bàn thất bại, đã hoàn tác',
    );
  }

  void renameArea(String oldArea, String newArea) {
    if (oldArea.isEmpty || newArea.isEmpty || oldArea == newArea) return;
    final storeId = getStoreId();
    final oldTables = List<String>.from(storeTables[storeId] ?? []);
    final tablesList = storeTables[storeId] ?? [];
    final prefix = '$oldArea · ';
    final renamePairs = <MapEntry<String, String>>[];
    for (int i = 0; i < tablesList.length; i++) {
      if (tablesList[i].startsWith(prefix)) {
        final tablePart = tablesList[i].substring(prefix.length);
        final oldFullName = tablesList[i];
        final newFullName = '$newArea · $tablePart';
        renamePairs.add(MapEntry(oldFullName, newFullName));
      }
    }
    optimistic(
      apply: () {
        for (final pair in renamePairs) {
          final idx = tablesList.indexOf(pair.key);
          if (idx >= 0) tablesList[idx] = pair.value;
        }
      },
      remote: () async {
        for (final pair in renamePairs) {
          await supabaseClient
              .from('store_tables')
              .update({'table_name': pair.value})
              .eq('store_id', storeId)
              .isFilter('deleted_at', null)
              .eq('table_name', pair.key);
        }
      },
      rollback: () {
        storeTables[storeId] = oldTables;
      },
      errorMsg: 'Đổi tên khu vực thất bại, đã hoàn tác',
    );
  }

  // ── Notifications ───────────────────────────────────────
  void markNotificationAsRead(String id) {
    final oldNotifications = List<NotificationModel>.from(notifications);
    optimistic(
      apply: () {
        notifications = notifications
            .map((n) => n.id == id ? n.copyWith(read: true) : n)
            .toList();
      },
      remote: () => supabaseClient
          .from('notifications')
          .update({'read': true})
          .eq('id', id),
      rollback: () {
        notifications = oldNotifications;
      },
    );
  }

  void deleteNotification(String id) {
    final oldNotifications = List<NotificationModel>.from(notifications);
    optimistic(
      apply: () {
        notifications.removeWhere((n) => n.id == id);
      },
      remote: () => supabaseClient.from('notifications').delete().eq('id', id),
      rollback: () {
        notifications = oldNotifications;
      },
    );
  }

  void clearNotifications(String userId) {
    final oldNotifications = List<NotificationModel>.from(notifications);
    optimistic(
      apply: () {
        notifications.removeWhere((n) => n.userId == userId);
      },
      remote: () =>
          supabaseClient.from('notifications').delete().eq('user_id', userId),
      rollback: () {
        notifications = oldNotifications;
      },
    );
  }

  // ── Premium ─────────────────────────────────────────────────
  void clearVipCongrat(String username) {
    final oldUsers = List<UserModel>.from(users);
    final oldCurrentUser = currentUser;
    optimistic(
      apply: () {
        users = users
            .map(
              (u) => u.username == username
                  ? u.copyWith(showVipCongrat: false)
                  : u,
            )
            .toList();
        if (currentUser?.username == username && currentUser != null) {
          currentUser = currentUser?.copyWith(showVipCongrat: false);
        }
      },
      remote: () => supabaseClient
          .from('users')
          .update({'show_vip_congrat': false})
          .eq('username', username),
      rollback: () {
        users = oldUsers;
        currentUser = oldCurrentUser;
      },
    );
  }

  void closeVipExpiredModal(String username) {
    final oldUsers = List<UserModel>.from(users);
    final oldCurrentUser = currentUser;
    optimistic(
      apply: () {
        users = users
            .map(
              (u) => u.username == username
                  ? u.copyWith(showVipExpired: false)
                  : u,
            )
            .toList();
        if (currentUser?.username == username && currentUser != null) {
          currentUser = currentUser?.copyWith(showVipExpired: false);
        }
      },
      remote: () => supabaseClient
          .from('users')
          .update({'show_vip_expired': false})
          .eq('username', username),
      rollback: () {
        users = oldUsers;
        currentUser = oldCurrentUser;
      },
    );
  }

  Future<void> approveVIPRequest(String requestId) async {
    final request = upgradeRequests.firstWhere((r) => r.id == requestId);
    try {
      final now = DateTime.now();
      
      int months = 1;
      if (request.planName.contains('3 Tháng')) months = 3;
      if (request.planName.contains('6 Tháng')) months = 6;
      if (request.planName.contains('1 Năm')) months = 12;
      final durationDays = months * 30;
      final expiresAt = now.add(Duration(days: durationDays));

      await supabaseClient.from('upgrade_requests').update({'status': 'approved'}).eq('id', requestId);

      await supabaseClient.from('users').update({
        'is_premium': true,
        'expires_at': expiresAt.toIso8601String(),
        'show_vip_congrat': true,
      }).eq('username', request.storeId);

      await supabaseClient.from('store_infos').update({
        'is_premium': true,
        'premium_expires_at': expiresAt.toIso8601String(),
      }).eq('store_id', request.storeId);

      await supabaseClient.from('premium_payments').insert({
        'id': 'pay_${now.millisecondsSinceEpoch}',
        'store_id': request.storeId,
        'amount': request.amount,
        'plan_name': request.planName,
        'months': months,
        'paid_at': now.toIso8601String(),
      }).catchError((e) { debugPrint('err payment insert: $e'); });

      await broadcastNotification(
        title: '💎 Nâng cấp Premium thành công',
        message: 'Cảm ơn quý khách! Dịch vụ phần mềm gói ${request.planName} đã được kích hoạt. Xin cảm ơn và chúc quý khách mua may bán đắt.',
        target: request.storeId,
      );

      upgradeRequests.removeWhere((r) => r.id == requestId);
      notifyListeners();
    } catch (e) {
      debugPrint('[ManagementStore] Approve Premium error: $e');
    }
  }

  Future<void> rejectVIPRequest(String requestId) async {
    if (currentUser?.role != 'sadmin') return;
    try {
      await supabaseClient.from('upgrade_requests').update({'status': 'rejected'}).eq('id', requestId);
      final req = upgradeRequests.firstWhere((r) => r.id == requestId, orElse: () => throw Exception('Not found'));
      
      await broadcastNotification(
        title: 'Yêu cầu không được phê duyệt',
        message: 'Đăng ký gói Premium chưa được duyệt (trùng khớp sai thông tin hoặc chưa thấy thanh toán). Vui lòng liên hệ Hotline/Zalo kỹ thuật (033.9524.898).',
        target: req.storeId,
      );
      
      upgradeRequests.removeWhere((r) => r.id == requestId);
      notifyListeners();
    } catch (e) {
      debugPrint('[ManagementStore] Reject Premium error: $e');
    }
  }
}
