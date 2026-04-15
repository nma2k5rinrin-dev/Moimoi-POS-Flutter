import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:moimoi_pos/features/auth/models/user_model.dart';
import 'package:moimoi_pos/core/state/base_mixin.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/services/background_service.dart';
/// Standalone class to handle Authentication and User management.
class AuthStore extends ChangeNotifier with BaseMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  String getStoreId() {
    final u = currentUser;
    if (u == null) return '';
    if (u.role == 'sadmin') return 'sadmin';
    if (u.role == 'admin') return u.username;
    final owner = u.createdBy ?? '';
    return owner.isNotEmpty ? owner : u.username;
  }

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

  /// Callback to load data after login.
  Future<void> Function(UserModel user)? onLoadInitialData;

  Future<void> _loadInitialData(UserModel user) async {
    await onLoadInitialData?.call(user);
  }

  // ── Login Attempt Monitor (Single-Device Login) ──
  RealtimeChannel? _loginAttemptChannel;

  void setupLoginAttemptRealtime() {
    if (currentUser == null || currentUser!.role == 'sadmin') return;
    _loginAttemptChannel = _supabase
        .channel('login-attempt-')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'username',
            value: currentUser!.username,
          ),
          callback: (payload) {
            final newAttempt = payload.newRecord['login_attempt_at'];
            final oldAttempt = payload.oldRecord['login_attempt_at'];
            if (newAttempt != null && newAttempt != oldAttempt) {
              debugPrint('[Realtime] ⚠️ Login attempt detected for ');
              showLoginAttemptWarning();
            }
          },
        )
        .subscribe();
  }

  void removeLoginAttemptRealtime() {
    if (_loginAttemptChannel != null) {
      _supabase.removeChannel(_loginAttemptChannel!);
    }
    _loginAttemptChannel = null;
  }

  void showLoginAttemptWarning() {
    final ctx = rootContext;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.amber100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 32,
                  color: Color(0xFFF59E0B),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Cảnh báo đăng nhập',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate800,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'Có thiết bị khác đang cố đăng nhập vào tài khoản của bạn. Nếu không phải bạn, hãy bỏ qua.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(dialogCtx).pop();
                          logout();
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Color(0xFFEF4444),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Đăng xuất',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Tiếp tục dùng',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Auth Logic ──────────────────────────────────────────

  Future<String> forgotPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email.trim());
      return 'success';
    } on AuthException catch (e) {
      debugPrint('[Auth] Forgot password AuthException: ${e.message}');
      return e.message;
    } catch (e) {
      debugPrint('[Auth] Forgot password error: $e');
      return 'Lỗi: $e';
    }
  }

  Future<String> login(String input, String password) async {
    final cleanInput = input.trim();
    // Admin login via Email, Staff login via Username
    final isEmail = cleanInput.contains('@');
    String loginEmail;
    if (isEmail) {
      loginEmail = cleanInput.toLowerCase();
    } else {
      // Dò Email thật thông qua RPC get_auth_email (nếu đây là Admin)
      try {
        final rpcEmail = await _supabase.rpc(
          'get_auth_email',
          params: {'p_username': cleanInput.toLowerCase()},
        );
        if (rpcEmail != null && rpcEmail.toString().isNotEmpty) {
          loginEmail = rpcEmail.toString();
        } else {
          loginEmail = '${cleanInput.toLowerCase()}@moimoi.local';
        }
      } catch (e) {
        debugPrint('[Auth] get_auth_email error: $e, fallback to local');
        loginEmail = '${cleanInput.toLowerCase()}@moimoi.local';
      }
    }

    try {
      final authResponse = await _supabase.auth.signInWithPassword(
        email: loginEmail,
        password: password,
      );

      if (authResponse.user == null) return 'Lỗi DB: AuthResponse user is null';

      if (authResponse.session == null) {
        return 'Email chưa được xác minh. Vui lòng kiểm tra hộp thư của bạn.';
      }

      // Lấy Profile public.users
      var userResponse = await _supabase
          .from('users')
          .select()
          .eq('id', authResponse.user!.id)
          .maybeSingle();

      // Nếu người dùng mới đăng ký (xác nhận email lần đầu), profile chưa có, ta tạo Profile từ Metadata
      if (userResponse == null && isEmail) {
        final meta = authResponse.user!.userMetadata ?? {};
        final cleanUsername = meta['username'] ?? '';

        if (cleanUsername == '') {
          return 'Lỗi DB: Dữ liệu metadata tạo cửa hàng không hợp lệ';
        }

        final newUser = {
          'id': authResponse.user!.id,
          'username': cleanUsername,
          'role': 'admin',
          'fullname': meta['fullname'] ?? '',
          'phone': meta['phone'] ?? '',
          'email': authResponse.user!.email,
          'is_premium': false,
        };
        await _supabase.from('users').insert(newUser);

        final storeData = {
          'store_id': cleanUsername,
          'name': meta['storeName'] ?? meta['fullname'] ?? '',
          'phone': meta['phone'] ?? '',
          'address': meta['address'] ?? '',
          'is_premium': false,
        };
        await _supabase.from('store_infos').insert(storeData);

        userResponse = newUser;
      } else if (userResponse == null) {
        return 'Lỗi DB: Không tìm thấy profile userResponse';
      }

      if (userResponse['deleted_at'] != null) {
        await _supabase.auth.signOut();
        if (userResponse['role'] == 'admin') {
          return 'Tài khoản sẽ hoàn tất xóa dữ liệu vĩnh viễn trong 3 ngày. Vui lòng liên hệ Admin ứng dụng để khôi phục.';
        }
        return 'Tài khoản này đã bị khóa hoặc yêu cầu xóa.';
      }

      // If staff, also check if owner admin's account has been deleted
      final createdBy = userResponse['created_by'];
      if (createdBy != null && createdBy.toString().isNotEmpty) {
        try {
          final ownerRow = await _supabase
              .from('users')
              .select('deleted_at')
              .eq('username', createdBy)
              .maybeSingle();
          if (ownerRow != null && ownerRow['deleted_at'] != null) {
            await _supabase.auth.signOut();
            return 'Cửa hàng đã ngừng hoạt động. Liên hệ chủ cửa hàng.';
          }
        } catch (_) {}
      }

      var user = UserModel.fromMap(userResponse);

      // ── Single-device login check (staff only) ──
      if (user.role != 'sadmin' && user.role != 'admin' && user.isOnline) {
        // Another device is already logged in → block this login
        // Update login_attempt_at to warn Device 1 via Realtime
        try {
          await _supabase
              .from('users')
              .update({'login_attempt_at': DateTime.now().toIso8601String()})
              .eq('username', user.username);
        } catch (_) {}
        // Sign out the Supabase auth session we just created
        try {
          await _supabase.auth.signOut();
        } catch (_) {}
        return 'already_online';
      }

      // Check VIP expiration
      if (user.role == 'admin' && user.expiresAt != null) {
        final isExpired = DateTime.now().isAfter(
          DateTime.parse(user.expiresAt!),
        );
        if (isExpired && user.isPremium) {
          user = user.copyWith(isPremium: false, showVipExpired: true);
          await _supabase
              .from('users')
              .update({'is_premium': false, 'show_vip_expired': true})
              .eq('username', user.username);
        }
      }

      currentUser = user;

      // Update last_login_at + is_online in Supabase
      try {
        final nowIso = DateTime.now().toIso8601String();
        await _supabase
            .from('users')
            .update({'login_attempt_at': nowIso, 'is_online': true})
            .eq('username', user.username);
      } catch (e) {
        debugPrint('[Auth] Failed to update login_attempt_at: $e');
      }

      // Khởi chạy Background Service để nhận đơn ngầm nếu được bật
      final prefs = await SharedPreferences.getInstance();
      final bgEnabled = prefs.getBool('isBackgroundEnabled') ?? true;
      if (bgEnabled && user.role != 'sadmin' && getStoreId().isNotEmpty) {
        await BackgroundServiceHelper.startService(getStoreId());
      }

      authNotifier.notify();
      notifyListeners();

      if (onLoadInitialData != null) await onLoadInitialData!(user);

      // Cache credentials for biometric login
      await saveLoginCredentials(cleanInput, password);

      return 'success';
    } on AuthException catch (e) {
      debugPrint('[Auth] AuthException: ${e.message}');
      if (e.message.contains('Email not confirmed')) {
        return 'email_not_confirmed';
      }
      if (e.message.contains('Invalid login credentials')) {
        return 'Sai tên đăng nhập hoặc mật khẩu';
      }
      return 'Lỗi xác thực: ${e.message}';
    } catch (e) {
      debugPrint('[Auth] Login error: $e');
      return 'Lỗi: $e';
    }
  }

  Future<String> register({
    required String email,
    required String fullname,
    required String phone,
    required String storeName,
    required String username,
    required String password,
    String address = '',
  }) async {
    final cleanUsername = username.toLowerCase().replaceAll(RegExp(r'\s'), '');

    try {
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'fullname': fullname,
          'phone': phone,
          'storeName': storeName,
          'username': cleanUsername,
          'address': address,
        },
      );

      if (authResponse.user == null) {
        showToast('Tên đăng nhập đã tồn tại hoặc lỗi mạng', 'error');
        return 'error';
      }

      if (authResponse.session == null) {
        return 'confirm_email';
      }

      return 'success';
    } on AuthException catch (e) {
      debugPrint('[Auth] Register error: $e');
      if (e.message.contains('already registered') ||
          e.message.contains('User already registered')) {
        showToast('Email này đã tồn tại trên hệ thống', 'error');
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

  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) return;

    // Soft-delete via RPC (SECURITY DEFINER) to bypass RLS
    try {
      await _supabase.rpc('soft_delete_own_account');
      debugPrint('[Auth] ✅ Soft-deleted user ${user.username}');
    } catch (e) {
      debugPrint('[Auth] ❌ Failed to soft-delete account: $e');
      showToast('Không thể xóa tài khoản: $e', 'error');
      return; // Don't logout if delete failed
    }

    // Clear cached biometric credentials so deleted account can't auto-login
    await clearCachedCredentials();

    // Then log them out
    logout();
  }

  void logout() {
    // Set is_online = false on Supabase before clearing local state
    final username = currentUser?.username;
    if (username != null) {
      _supabase
          .from('users')
          .update({'is_online': false})
          .eq('username', username)
          .then((_) {
            debugPrint('[Auth] Set is_online=false for $username');
          })
          .catchError((e) {
            debugPrint('[Auth] Failed to set is_online=false: $e');
          });
    }

    // Tắt dịch vụ chạy ngầm khi đăng xuất
    BackgroundServiceHelper.stopService();
    Supabase.instance.client.removeAllChannels();

    currentUser = null;
    users = [];
    authNotifier.notify();
    notifyListeners();
  }

  void updateUser(String username, Map<String, dynamic> updatedData) {
    final dbData = <String, dynamic>{};
    if (updatedData.containsKey('fullname')) {
      dbData['fullname'] = updatedData['fullname'];
    }
    if (updatedData.containsKey('phone')) {
      dbData['phone'] = updatedData['phone'];
    }
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
        updatedData['createdBy'] != null) {
      dbData['created_by'] = updatedData['createdBy'];
    }

    final oldUsers = List<UserModel>.from(users);
    final oldCurrentUser = currentUser;

    optimistic(
      apply: () {
        users = users.map((u) {
          if (u.username == username) {
            return u.copyWith(
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
          currentUser = users.firstWhere(
            (u) => u.username == username,
            orElse: () => currentUser!,
          );
        }
      },
      remote: () async {
        // ONLY update via RPC if explicitly passed inside dbData
        if (updatedData.containsKey('pass')) {
          await _supabase.rpc(
            'update_user_password',
            params: {
              'p_username': username,
              'p_new_password': updatedData['pass'],
            },
          );
        }
        if (dbData.isNotEmpty) {
          await _supabase.from('users').update(dbData).eq('username', username);
        }
        showToast('Cập nhật thông tin thành công');
      },
      rollback: () {
        users = oldUsers;
        currentUser = oldCurrentUser;
      },
    );
  }

  // ── Biometric Helpers ─────────────────────────────────────
  static const _storage = FlutterSecureStorage();
  static const _kBioUser = 'bio_username';
  static const _kBioPass = 'bio_password';

  Future<void> saveLoginCredentials(String username, String password) async {
    await _storage.write(key: _kBioUser, value: username);
    await _storage.write(key: _kBioPass, value: password);
    // Xóa từ kho kém bảo mật
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBioUser);
    await prefs.remove(_kBioPass);
  }

  Future<bool> hasSavedCredentials() async =>
      await getCachedCredentials() != null;

  Future<Map<String, String>?> getCachedCredentials() async {
    String? u;
    String? p;
    try {
      u = await _storage.read(key: _kBioUser);
      p = await _storage.read(key: _kBioPass);
    } catch (e) {
      debugPrint('[SecureStorage] Error reading credentials: $e');
      await _storage
          .deleteAll(); // Xóa sạch dữ liệu lỗi để tránh dính crash vĩnh viễn
    }

    // Migration từ bản cũ (rủi ro) sang bản bảo mật (chuẩn)
    if (u == null || p == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        u = prefs.getString(_kBioUser);
        p = prefs.getString(_kBioPass);
        if (u != null && p != null) {
          await saveLoginCredentials(u, p);
        }
      } catch (e) {
        debugPrint('[Migration] Error: $e');
      }
    }

    if (u != null && p != null) return {'username': u, 'password': p};
    return null;
  }

  Future<void> clearCachedCredentials() async {
    await _storage.delete(key: _kBioUser);
    await _storage.delete(key: _kBioPass);
    // Double check
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
