import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:moimoi_pos/features/auth/models/user_model.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/features/notifications/models/notification_model.dart';
import 'package:moimoi_pos/features/premium/models/premium_payment_model.dart';
import 'package:moimoi_pos/features/premium/models/upgrade_request_model.dart';

/// Dedicated store for Sadmin (Super Admin) — completely isolated from POS store logic.
/// This store handles sadmin dashboard data, store management, and VIP approval.
class SadminStore extends ChangeNotifier {
  SupabaseClient get supabaseClient => Supabase.instance.client;

  // ── Current user (sadmin) ──
  UserModel? currentUser;

  // ── State (sadmin-only, NOT shared with ManagementStore) ──
  List<UserModel> adminUsers = [];
  List<UserModel> get users => adminUsers; // Alias for UI compatibility
  Map<String, StoreInfoModel> storeInfos = {};
  List<UpgradeRequestModel> upgradeRequests = [];
  List<PremiumPaymentModel> premiumPayments = [];
  List<NotificationModel> notifications = [];

  // ── Toast ──
  void Function(String message, [String type])? externalShowToast;

  void showToast(String message, [String type = 'success']) {
    if (externalShowToast != null) {
      externalShowToast!(message, type);
    }
  }

  // ── Init: lightweight fetch for sadmin dashboard ──
  Future<void> init(UserModel user) async {
    currentUser = user;
    try {
      final results = await Future.wait([
        // 1. Only fetch admin users (store owners)
        supabaseClient
            .from('users')
            .select('username, role, fullname, phone, is_premium, expires_at, created_by, show_vip_expired, show_vip_congrat, is_online')
            .eq('role', 'admin')
            .catchError((e) { debugPrint('SadminStore users error: $e'); return <Map<String, dynamic>>[]; }),
        // 2. Store infos — lightweight columns only
        supabaseClient
            .from('store_infos')
            .select('store_id, name, logo_url, phone, is_premium, is_store_open, is_online, premium_activated_at, premium_expires_at, total_offline_days, created_at')
            .isFilter('deleted_at', null)
            .catchError((e) { debugPrint('SadminStore storeInfos error: $e'); return <Map<String, dynamic>>[]; }),
        // 3. Upgrade requests (pending only)
        supabaseClient
            .from('upgrade_requests')
            .select()
            .eq('status', 'pending')
            .catchError((e) { debugPrint('SadminStore upgradeRequests error: $e'); return <Map<String, dynamic>>[]; }),
        // 4. Premium payments
        supabaseClient
            .from('premium_payments')
            .select()
            .order('paid_at', ascending: false)
            .catchError((e) { debugPrint('SadminStore premiumPayments error: $e'); return <Map<String, dynamic>>[]; }),
        // 5. Sadmin notifications
        supabaseClient
            .from('notifications')
            .select()
            .eq('user_id', user.username)
            .order('time', ascending: false)
            .limit(50)
            .catchError((e) { debugPrint('SadminStore notifications error: $e'); return <Map<String, dynamic>>[]; }),
      ]);

      adminUsers = results[0].map((u) => UserModel.fromMap(u)).toList();

      storeInfos = {};
      for (final s in results[1]) {
        final sid = s['store_id']?.toString() ?? '';
        if (sid.isNotEmpty) {
          storeInfos[sid] = StoreInfoModel.fromMap(s);
        }
      }

      // Auto-downgrade expired premium stores
      for (final entry in storeInfos.entries.toList()) {
        final info = entry.value;
        if (info.isPremium && info.isExpired) {
          storeInfos[entry.key] = info.copyWith(isPremium: false);
          supabaseClient
              .from('store_infos')
              .update({'is_premium': false})
              .eq('store_id', entry.key)
              .then((_) => debugPrint('⚠️ Auto-downgraded expired store: ${entry.key}'))
              .catchError((e) => debugPrint('❌ Failed to downgrade store ${entry.key}: $e'));
        }
      }

      upgradeRequests = results[2].map((ur) => UpgradeRequestModel.fromMap(ur)).toList();
      premiumPayments = results[3].map((p) => PremiumPaymentModel.fromMap(p)).toList();
      notifications = results[4].map((n) => NotificationModel.fromMap(n)).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('[SadminStore.init] $e');
    }
  }

  // ── Fetch full store info (lazy, on detail page) ──
  Future<StoreInfoModel?> fetchFullStoreInfo(String storeId) async {
    try {
      final res = await supabaseClient
          .from('store_infos')
          .select()
          .eq('store_id', storeId)
          .maybeSingle();
      if (res != null) return StoreInfoModel.fromMap(res);
    } catch (e) {
      debugPrint('[SadminStore.fetchFullStoreInfo] $e');
    }
    return null;
  }

  // ── Fetch staff count for a store (lazy) ──
  Future<int> fetchStaffCount(String storeId) async {
    try {
      final res = await supabaseClient
          .from('users')
          .select('id')
          .eq('created_by', storeId)
          .neq('role', 'admin');
      return res.length;
    } catch (e) {
      debugPrint('[SadminStore.fetchStaffCount] $e');
      return 0;
    }
  }

  // ── Update Store Info by ID (sadmin editing a store) ──
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
      'is_store_open': info.isStoreOpen,
    };
    final keepKeys = {'qr_image_url', 'show_total_products'};
    dbData.removeWhere((k, v) => !keepKeys.contains(k) && v.toString().isEmpty);

    storeInfos[storeId] = info;
    notifyListeners();

    supabaseClient.from('store_infos').upsert({
      'store_id': storeId,
      ...dbData,
    }).then((_) {}).catchError((e) {
      debugPrint('[SadminStore] updateStoreInfoById error: $e');
      if (oldInfo != null) {
        storeInfos[storeId] = oldInfo;
      } else {
        storeInfos.remove(storeId);
      }
      notifyListeners();
      showToast('Cập nhật thông tin cửa hàng thất bại, đã hoàn tác', 'error');
    });
  }

  // ── Delete Store ──
  void deleteStore(String storeId) {
    final oldStoreInfos = Map<String, StoreInfoModel>.from(storeInfos);
    final oldUsers = List<UserModel>.from(adminUsers);
    final staffToDelete = adminUsers
        .where((u) => u.createdBy == storeId)
        .map((u) => u.username)
        .toList();

    storeInfos.remove(storeId);
    adminUsers.removeWhere((u) => u.username == storeId || u.createdBy == storeId);
    notifyListeners();

    () async {
      try {
        for (final staffUsername in staffToDelete) {
          await supabaseClient.rpc('admin_delete_user', params: {'p_username': staffUsername});
        }
        await supabaseClient.rpc('admin_delete_user', params: {'p_username': storeId});
        await supabaseClient.from('store_infos').delete().eq('store_id', storeId).isFilter('deleted_at', null);
      } catch (e) {
        debugPrint('[SadminStore] deleteStore error: $e');
        storeInfos = oldStoreInfos;
        adminUsers = oldUsers;
        notifyListeners();
        showToast('Xoá cửa hàng thất bại, đã hoàn tác', 'error');
      }
    }();
  }

  // ── Add Store Owner Account (sadmin only) ──
  Future<void> addStaff({
    required String fullname,
    required String phone,
    required String username,
    required String password,
    String? storeName,
    String role = 'staff',
    String? createdBy,
  }) async {
    if (adminUsers.any((u) => u.username == username)) {
      showToast('Tên đăng nhập đã tồn tại', 'error');
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
      adminUsers.add(UserModel.fromMap(newStaffRow));
      notifyListeners();
    } catch (e) {
      debugPrint('[SadminStore.addStaff] $e');
      showToast('Thêm tài khoản thất bại', 'error');
    }
  }

  // ── Broadcast Notification ──
  Future<void> broadcastNotification({
    required String title,
    required String message,
    String? target,
  }) async {
    final storeIdToNoti = target ?? 'all_stores';
    try {
      Iterable<UserModel> targetStaff;

      if (storeIdToNoti == 'all_users') {
        targetStaff = adminUsers; // sadmin only has admin users
      } else if (storeIdToNoti == 'all_stores' || storeIdToNoti == 'all') {
        targetStaff = adminUsers;
      } else {
        targetStaff = adminUsers.where((u) => u.username == storeIdToNoti || u.createdBy == storeIdToNoti);
      }

      final payload = targetStaff.map((u) {
        return {
          'id': const Uuid().v4(),
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
      debugPrint('[SadminStore] Error broadcasting notification: $e');
    }
  }

  // ── Approve VIP Request ──
  Future<void> approveVIPRequest(String requestId) async {
    final request = upgradeRequests.firstWhere((r) => r.id == requestId);
    try {
      final now = DateTime.now();

      int months = 1;
      if (request.planName.contains('3 Tháng')) months = 3;
      if (request.planName.contains('6 Tháng')) months = 6;
      if (request.planName.contains('1 Năm')) months = 12;
      final durationDays = months * 30;

      DateTime baseDate = now;
      final targetUser = adminUsers.where((u) => u.username == request.storeId || u.createdBy == request.storeId).firstOrNull;
      if (targetUser?.expiresAt != null) {
        final currentExpiry = DateTime.tryParse(targetUser!.expiresAt!) ?? now;
        if (currentExpiry.isAfter(now)) {
          baseDate = currentExpiry;
        }
      }

      final expiresAt = baseDate.add(Duration(days: durationDays));

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
        'id': const Uuid().v4(),
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
      debugPrint('[SadminStore] Approve Premium error: $e');
    }
  }

  // ── Reject VIP Request ──
  Future<void> rejectVIPRequest(String requestId) async {
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
      debugPrint('[SadminStore] Reject Premium error: $e');
    }
  }

  // ── Realtime Notifications ──
  RealtimeChannel? _notiChannel;

  void setupNotificationsRealtime(String username) {
    _notiChannel = supabaseClient
        .channel('sadmin-notifications-$username')
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

  void removeNotificationsRealtime() {
    if (_notiChannel != null) supabaseClient.removeChannel(_notiChannel!);
    _notiChannel = null;
  }

  // ── Notification CRUD ──
  void markNotificationAsRead(String id) {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    notifications[idx] = notifications[idx].copyWith(read: true);
    notifyListeners();
    supabaseClient.from('notifications').update({'read': true}).eq('id', id).catchError((e) {});
  }

  void markAllNotificationsAsRead(String userId) {
    for (var i = 0; i < notifications.length; i++) {
      if (!notifications[i].read) {
        notifications[i] = notifications[i].copyWith(read: true);
      }
    }
    notifyListeners();
    supabaseClient.from('notifications').update({'read': true}).eq('user_id', userId).eq('read', false).catchError((e) {});
  }

  void deleteNotification(String id) {
    notifications.removeWhere((n) => n.id == id);
    notifyListeners();
    supabaseClient.from('notifications').delete().eq('id', id).catchError((e) {});
  }

  void clearNotifications(String userId) {
    notifications.clear();
    notifyListeners();
    supabaseClient.from('notifications').delete().eq('user_id', userId).catchError((e) {});
  }

  // ── Cleanup ──
  void clear() {
    adminUsers = [];
    storeInfos = {};
    upgradeRequests = [];
    premiumPayments = [];
    notifications = [];
    removeNotificationsRealtime();
  }

  @override
  void dispose() {
    removeNotificationsRealtime();
    super.dispose();
  }
}
