import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moimoi_pos/features/auth/models/user_model.dart';
import 'package:moimoi_pos/core/state/base_mixin.dart';

/// Mixin to handle Authentication and User management in AppStore.
mixin AuthStore on ChangeNotifier, BaseMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  UserModel? currentUser;
  List<UserModel> users = [];
  String sadminViewStoreId = 'all';

  @override
  void notifyListeners() {
    super.notifyListeners();
  }

  /// Users visible to admin/staff — never includes sadmin accounts.
  List<UserModel> get visibleUsers =>
      users.where((u) => u.role != 'sadmin').toList();

  /// Lightweight notifier that ONLY fires when auth state changes (login/logout).
  final AuthNotifier authNotifier = AuthNotifier();

  /// Abstract method to be implemented by AppStore to load data after login.
  Future<void> loadInitialData(UserModel user);

  // ── Auth Logic ──────────────────────────────────────────

  Future<String> login(String username, String password) async {
    final cleanUsername = username.toLowerCase().replaceAll(RegExp(r'\s'), '');
    final fakeEmail = '$cleanUsername@moimoi.local';

    try {
      final authResponse = await _supabase.auth.signInWithPassword(
        email: fakeEmail,
        password: password,
      );

      if (authResponse.user == null) return 'invalid';

      // Lấy Profile public.users
      final userResponse = await _supabase
          .from('users')
          .select()
          .eq('id', authResponse.user!.id)
          .maybeSingle();

      if (userResponse == null) return 'invalid';

      var user = UserModel.fromMap(userResponse);

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
      
      // Update last_login_at in Supabase
      try {
        final nowIso = DateTime.now().toIso8601String();
        await _supabase.from('users').update({'last_login_at': nowIso}).eq('username', user.username);
        if (user.role == 'admin') {
          await _supabase.from('store_infos').update({
            'last_login_at': nowIso,
            'is_online': true,
          }).eq('store_id', user.username);
        }
      } catch (e) {
        debugPrint('[Auth] Failed to update last_login_at: $e');
      }

      authNotifier.notify();
      notifyListeners();
      
      await loadInitialData(user);

      // Cache credentials for biometric login
      await saveLoginCredentials(cleanUsername, password);

      return 'success';
    } catch (e) {
      debugPrint('[Auth] Login error: $e');
      return 'invalid';
    }
  }

  Future<String> register({
    required String fullname,
    required String phone,
    required String storeName,
    required String username,
    required String password,
    String address = '',
  }) async {
    final cleanUsername = username.toLowerCase().replaceAll(RegExp(r'\s'), '');
    final fakeEmail = '$cleanUsername@moimoi.local';

    try {
      final authResponse = await _supabase.auth.signUp(
        email: fakeEmail,
        password: password,
      );

      if (authResponse.user == null) {
        showToast('Tên đăng nhập đã tồn tại hoặc lỗi mạng', 'error');
        return 'error';
      }

      final newUser = {
        'id': authResponse.user!.id,
        'username': cleanUsername,
        'pass': password,
        'role': 'admin',
        'fullname': fullname,
        'phone': phone,
        'is_premium': false,
      };

      await _supabase.from('users').insert(newUser);

      final storeData = <String, dynamic>{
        'store_id': cleanUsername,
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
    } on AuthException catch (e) {
      debugPrint('[Auth] Register error: $e');
      if (e.message.contains('already registered') || e.message.contains('User already registered')) {
        showToast('Tên đăng nhập đã tồn tại', 'error');
        return 'exists';
      }
      showToast('Đăng ký thất bại: ${e.message}', 'error');
      return 'error';
    } catch (e) {
      debugPrint('[Auth] Register error: $e');
      showToast('Đăng ký thất bại: $e', 'error');
      return 'error';
    }
  }

  void logout() {
    currentUser = null;
    users = [];
    authNotifier.notify();
    notifyListeners();
  }

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
    if (updatedData.containsKey('createdBy') && updatedData['createdBy'] != null) {
      dbData['created_by'] = updatedData['createdBy'];
    }

    final oldUsers = List<UserModel>.from(users);
    final oldCurrentUser = currentUser;

    optimistic(
      apply: () {
        users = users.map((u) {
          if (u.username == username) {
             return u.copyWith(
                pass: updatedData['pass'],
                role: updatedData['role'],
                fullname: updatedData['fullname'],
                phone: updatedData['phone'],
                isPremium: updatedData['isPremium'],
                expiresAt: updatedData['expiresAt'],
                showVipExpired: updatedData['showVipExpired'],
                showVipCongrat: updatedData['showVipCongrat'],
                avatar: updatedData['avatar'],
                createdBy: updatedData['createdBy'],
             );
          }
          return u;
        }).toList();
        if (currentUser?.username == username) {
           currentUser = users.firstWhere((u) => u.username == username, orElse: () => currentUser!);
        }
      },
      remote: () async {
        if (dbData.containsKey('pass')) {
          await _supabase.rpc('update_user_password', params: {
            'p_username': username,
            'p_new_password': dbData['pass'],
          });
          dbData.remove('pass'); // `update_user_password` handles both `auth.users` and `public.users` pass column
        }
        if (dbData.isNotEmpty) {
          await _supabase.from('users').update(dbData).eq('username', username);
        }
      },
      rollback: () {
        users = oldUsers;
        currentUser = oldCurrentUser;
      },
    );
  }

  // ── Biometric Helpers ─────────────────────────────────────
  static const _kBioUser = 'bio_username';
  static const _kBioPass = 'bio_password';

  Future<void> saveLoginCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBioUser, username);
    await prefs.setString(_kBioPass, password);
  }

  Future<Map<String, String>?> getCachedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final u = prefs.getString(_kBioUser);
    final p = prefs.getString(_kBioPass);
    if (u != null && p != null) return {'username': u, 'password': p};
    return null;
  }

  Future<void> clearCachedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBioUser);
    await prefs.remove(_kBioPass);
  }

  Future<String> loginWithBiometric() async {
    final creds = await getCachedCredentials();
    if (creds == null) return 'no_credentials';
    return login(creds['username']!, creds['password']!);
  }
}

/// Helper notifier for GoRouter refreshListenable.
class AuthNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
