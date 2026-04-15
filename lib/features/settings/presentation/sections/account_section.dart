import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_auth;
import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';
import 'package:moimoi_pos/features/auth/models/user_model.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/widgets/animated_dialogs.dart';
import 'package:moimoi_pos/services/api/cloudflare_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moimoi_pos/core/widgets/crop/avatar_crop_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

Uint8List _decodeAvatar(String dataUri) {
  final base64Part = dataUri.split(',').last;
  return base64Decode(base64Part);
}

class AccountSection extends StatefulWidget {
  final VoidCallback? onCancel;
  const AccountSection({super.key, this.onCancel});

  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  final _phoneController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankOwnerController = TextEditingController();
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _widgetSyncEnabled = true;

  @override
  void initState() {
    super.initState();
    final store = context.read<AuthStore>();
    _phoneController.text = store.currentUser?.phone ?? '';
    if (store.currentUser?.role == 'sadmin') {
      final sadminInfo = context.read<ManagementStore>().storeInfos['sadmin'] ?? const StoreInfoModel();
      _bankNameController.text = sadminInfo.bankId;
      _bankAccountController.text = sadminInfo.bankAccount;
      _bankOwnerController.text = sadminInfo.bankOwner;
    }
    _initBiometricState();
    _initWidgetSync();
  }

  Future<void> _initWidgetSync() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _widgetSyncEnabled = prefs.getBool('widget_sync_enabled') ?? true;
    });
  }

  Future<void> _toggleWidgetSync(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('widget_sync_enabled', enable);
    if (!mounted) return;
    setState(() {
      _widgetSyncEnabled = enable;
    });
    // Kích hoạt đồng bộ ngay
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _bankOwnerController.dispose();
    super.dispose();
  }

  Future<void> _initBiometricState() async {
    try {
      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics;
      final isSupported = await localAuth.isDeviceSupported();
      final available = canCheck && isSupported;

      bool enabled = false;
      if (available) {
        if (!mounted) return;
        final store = context.read<AuthStore>();
        final creds = await store.getCachedCredentials();
        if (!mounted) return;
        enabled = creds != null;
      }

      if (!mounted) return;
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    } catch (_) {}
  }

  Future<void> _toggleBiometric(bool enable) async {
    final store = context.read<AuthStore>();

    if (enable) {
      try {
        final localAuth = LocalAuthentication();
        final didAuthenticate = await localAuth.authenticate(
          localizedReason: 'Xác thực để bật đăng nhập sinh trắc học',
        );
        if (!mounted) return;
        if (!didAuthenticate) {
          store.showToast('Xác thực thất bại', 'error');
          return;
        }
      } catch (e) {
        if (!mounted) return;
        store.showToast('Lỗi xác thực sinh trắc học', 'error');
        return;
      }

      final creds = await store.getCachedCredentials();
      if (!mounted) return;
      if (creds != null) {
        setState(() => _biometricEnabled = true);
        store.showToast('Đã bật đăng nhập sinh trắc học');
      } else {
        store.showToast(
          'Vui lòng đăng xuất và đăng nhập lại bằng mật khẩu để kích hoạt',
          'error',
        );
      }
    } else {
      await store.clearCachedCredentials();
      if (!mounted) return;
      setState(() => _biometricEnabled = false);
      store.showToast('Đã tắt đăng nhập sinh trắc học');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AuthStore>();
    final user = store.currentUser;
    final isSadmin = user?.role == 'sadmin';

    if (isSadmin) {
      return _buildSadminView(store, user);
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 9),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      children: [
                        _buildAvatarSection(store, user),
                        SizedBox(height: 28),
                        _buildIdentitySection(user),
                        SizedBox(height: 16),
                        _buildSecuritySeparator(),
                        SizedBox(height: 16),
                        _buildSecurityRows(store),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
        _buildBottomActions(store, user),
      ],
    );
  }

  /// Sadmin-only simplified view (no widget sync, bank, delete, policy, logout)
  Widget _buildSadminView(AuthStore store, UserModel? user) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 9),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      children: [
                        _buildAvatarSection(store, user),
                        SizedBox(height: 28),
                        _buildIdentitySection(user),
                        SizedBox(height: 16),
                        _buildSecuritySeparator(),
                        SizedBox(height: 16),
                        // Only password + biometrics for sadmin
                        _SecurityRow(
                          icon: Icons.lock_outline_rounded,
                          label: 'Đổi mật khẩu',
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppColors.slate400,
                          ),
                          onTap: () => _showChangePasswordDialog(context, store),
                        ),
                        SizedBox(height: 10),
                        _SecurityRow(
                          icon: Icons.fingerprint_rounded,
                          label: 'Vân tay / FaceID',
                          trailing: _biometricAvailable
                              ? Switch(
                                  value: _biometricEnabled,
                                  activeTrackColor: AppColors.emerald500,
                                  onChanged: _toggleBiometric,
                                )
                              : Text(
                                  'Không hỗ trợ',
                                  style: TextStyle(fontSize: 13, color: AppColors.slate400),
                                ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
        _buildBottomActions(store, user),
      ],
    );
  }

  Widget _buildAvatarSection(AuthStore store, UserModel? user) {
    return Column(
      children: [
        Stack(
          children: [
            (user?.avatar ?? '').isNotEmpty
                ? ClipOval(
                    child: CloudflareService.isUrl(user!.avatar)
                        ? CachedNetworkImage(
                            imageUrl: user.avatar,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                const CircularProgressIndicator(),
                            errorWidget: (_, _, _) => Icon(Icons.error),
                          )
                        : Image.memory(
                            _decodeAvatar(user.avatar),
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                          ),
                  )
                : CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.emerald100,
                    child: Text(
                      (user?.fullname ?? 'U').substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emerald600,
                      ),
                    ),
                  ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _showAvatarPicker(context, store, user),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.emerald500,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cardBg, width: 2),
                  ),
                  child: Icon(Icons.camera_alt, size: 13, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              user?.fullname.isNotEmpty == true
                  ? user!.fullname
                  : (user?.username ?? 'User'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.slate800,
              ),
            ),
            SizedBox(width: 6),
            GestureDetector(
              onTap: () => _showEditFullnameDialog(context, store, user),
              child: Icon(Icons.edit, size: 16, color: AppColors.emerald500),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          'Kích hoạt: ${_formatCreatedAt(user?.createdAt)}',
          style: TextStyle(fontSize: 13, color: AppColors.slate400),
        ),
        SizedBox(height: 6),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.emerald50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_rounded,
                size: 14,
                color: AppColors.emerald500,
              ),
              SizedBox(width: 4),
              Text(
                _getRoleName(user?.role),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.emerald600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdentitySection(UserModel? user) {
    return Row(
      children: [
        Expanded(
          child: _buildReadonlyField(
            'Tên đăng nhập',
            user?.username ?? '',
            Icons.alternate_email_rounded,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildEditableField(
            'Số điện thoại',
            _phoneController,
            Icons.phone_outlined,
            '0912 345 678',
          ),
        ),
      ],
    );
  }

  Widget _buildReadonlyField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.slate600,
          ),
        ),
        SizedBox(height: 6),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.slate100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.slate400),
              SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(fontSize: 14, color: AppColors.slate500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    IconData icon,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.slate600,
          ),
        ),
        SizedBox(height: 6),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.slate400),
              SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(color: AppColors.slate300),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySeparator() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.slate200)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Bảo mật',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.slate400,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.slate200)),
      ],
    );
  }

  Widget _buildSecurityRows(AuthStore store) {
    return Column(
      children: [
        _SecurityRow(
          icon: Icons.lock_outline_rounded,
          label: 'Đổi mật khẩu',
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.slate400,
          ),
          onTap: () => _showChangePasswordDialog(context, store),
        ),
        SizedBox(height: 10),
        _SecurityRow(
          icon: Icons.fingerprint_rounded,
          label: 'Vân tay / FaceID',
          trailing: _biometricAvailable
              ? Switch(
                  value: _biometricEnabled,
                  activeTrackColor: AppColors.emerald500,
                  onChanged: _toggleBiometric,
                )
              : Text(
                  'Không hỗ trợ',
                  style: TextStyle(fontSize: 13, color: AppColors.slate400),
                ),
        ),
        SizedBox(height: 10),
        _SecurityRow(
          icon: Icons.widgets_rounded,
          label: 'Hiện số liệu lên Widget',
          trailing: Switch(
            value: _widgetSyncEnabled,
            activeTrackColor: AppColors.emerald500,
            onChanged: _toggleWidgetSync,
          ),
        ),
        SizedBox(height: 10),
        _SecurityRow(
          icon: Icons.logout_rounded,
          label: 'Đăng xuất',
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.slate400,
          ),
          onTap: () {
            store.logout();
            // GoRouter should automatically redirect to /login due to authNotifier
          },
        ),
        SizedBox(height: 10),
        _SecurityRow(
          icon: Icons.no_accounts_rounded,
          label: 'Xóa tài khoản',
          labelColor: AppColors.red500,
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.red400,
          ),
          onTap: () => _showDeleteAccountDialog(context, store),
        ),
        SizedBox(height: 10),
        _SecurityRow(
          icon: Icons.privacy_tip_outlined,
          label: 'Chính sách bảo mật & Điều khoản sử dụng',
          trailing: Icon(
            Icons.open_in_new_rounded,
            size: 20,
            color: AppColors.slate400,
          ),
          onTap: () => launchUrl(
            Uri.parse(
              'https://docs.google.com/document/d/1A0i6Gq__4pY6Z8FqweItaelxnvEYGeQNRgQIabx9kks/edit?usp=sharing',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBankSection(AuthStore store) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.slate200)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Thanh toán ngân hàng',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate400,
                  ),
                ),
              ),
              Expanded(child: Divider(color: AppColors.slate200)),
            ],
          ),
          SizedBox(height: 16),
          _buildEditableField(
            'Tên ngân hàng',
            _bankNameController,
            Icons.account_balance_outlined,
            'VD: TECHCOMBANK',
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildEditableField(
                  'Số tài khoản',
                  _bankAccountController,
                  Icons.credit_card_outlined,
                  'VD: 19034153150012',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildEditableField(
                  'Chủ tài khoản',
                  _bankOwnerController,
                  Icons.person_outline,
                  'VD: NGUYEN VAN A',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(AuthStore store, UserModel? user) {
    return Padding(
      padding: EdgeInsets.fromLTRB(9, 8, 9, 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (widget.onCancel != null) {
                    widget.onCancel!();
                  } else {
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  }
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.slate500,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Hủy bỏ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  final updates = <String, dynamic>{
                    'phone': _phoneController.text,
                  };
                  store.updateUser(user!.username, updates);
                  if (user.role == 'sadmin') {
                    final info =
                        context.read<ManagementStore>().storeInfos['sadmin'] ?? const StoreInfoModel();
                    context.read<ManagementStore>().updateStoreInfo(
                      info.copyWith(
                        bankId: _bankNameController.text.trim(),
                        bankAccount: _bankAccountController.text.trim(),
                        bankOwner: _bankOwnerController.text.trim(),
                      ),
                    );
                  }
                  store.showToast('Đã lưu thay đổi');
                  if (widget.onCancel != null) {
                    widget.onCancel!();
                  } else {
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  }
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.emerald500,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Lưu thay đổi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthStore store) {
    showAnimatedDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.red100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.no_accounts_rounded,
                  size: 32,
                  color: AppColors.red500,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Xóa tài khoản',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Bạn có chắc chắn muốn yêu cầu xóa vĩnh viễn tài khoản này không? Mọi dữ liệu cá nhân của bạn sẽ bị xóa hoặc vô hiệu hóa. Chức năng này sẽ áp dụng ngay lập tức!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.slate500,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.slate500,
                          side: BorderSide(color: AppColors.slate200),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Hủy bỏ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
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
                        onPressed: () async {
                          Navigator.pop(ctx);
                          store.showToast(
                            'Đang xử lý yêu cầu xóa tài khoản...',
                            'warning',
                          );
                          await store.deleteAccount();
                          store.showToast(
                            'Đã xóa dữ liệu tài khoản.',
                            'success',
                          );
                          if (mounted && Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red500,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Xác nhận xóa',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
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

  // --- Helpers ---
  String _getRoleName(String? role) {
    switch (role) {
      case 'sadmin':
        return 'Super Admin';
      case 'admin':
        return 'Admin';
      default:
        return 'Nhân viên';
    }
  }

  String _formatCreatedAt(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _showAvatarPicker(
    BuildContext context,
    AuthStore store,
    UserModel? user,
  ) async {
    if (user == null) return;
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    if (!context.mounted) return;

    final base64Result = await showAvatarCropDialog(context, bytes);

    if (base64Result != null) {
      String imageData = base64Result;
      try {
        imageData = await CloudflareService.uploadBase64(
          base64Data: base64Result,
          folder: 'avatars',
        );
      } catch (e) {
        debugPrint('[AccountSection] Avatar upload failed: $e');
      }

      store.updateUser(user.username, {'avatar': imageData});
      store.showToast('Cập nhật ảnh đại diện thành công!');
    }
  }

  void _showEditFullnameDialog(
    BuildContext context,
    AuthStore store,
    UserModel? user,
  ) {
    final ctrl = TextEditingController(text: user?.fullname ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.edit_outlined, size: 22, color: AppColors.emerald500),
            SizedBox(width: 8),
            Text(
              'Đổi tên hiển thị',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.slate800,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tên hiển thị',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate700,
                ),
              ),
              SizedBox(height: 6),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'VD: Nguyễn Văn A',
                  hintStyle: TextStyle(color: AppColors.slate400, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.slate50,
                  prefixIcon: Icon(
                    Icons.person_outline,
                    size: 20,
                    color: AppColors.slate400,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.slate200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.emerald500,
                      width: 2,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.slate50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.slate200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.slate500,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Hủy bỏ',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final name = ctrl.text.trim();
                        if (name.isEmpty) {
                          store.showToast('Vui lòng nhập tên', 'error');
                          return;
                        }
                        store.updateUser(user!.username, {'fullname': name});
                        store.showToast('Đã cập nhật tên hiển thị');
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.emerald500,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.save_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Cập nhật',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
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

  void _showChangePasswordDialog(BuildContext context, AuthStore store) {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;

    InputDecoration buildDecor({
      required String hint,
      required IconData prefixIcon,
      required bool isObscure,
      required VoidCallback onToggle,
    }) {
      return InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.slate400, fontSize: 14),
        filled: true,
        fillColor: AppColors.slate50,
        prefixIcon: Icon(prefixIcon, size: 20, color: AppColors.slate400),
        suffixIcon: IconButton(
          icon: Icon(
            isObscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
            color: AppColors.slate400,
          ),
          onPressed: onToggle,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.emerald500, width: 2),
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (stfCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 22,
                color: AppColors.emerald500,
              ),
              SizedBox(width: 8),
              Text(
                'Đổi mật khẩu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate800,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current password
                Text(
                  'Mật khẩu hiện tại',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate700,
                  ),
                ),
                SizedBox(height: 6),
                TextField(
                  controller: currentPassCtrl,
                  obscureText: obscureCurrent,
                  style: TextStyle(fontWeight: FontWeight.w500),
                  decoration: buildDecor(
                    hint: 'Nhập mật khẩu hiện tại',
                    prefixIcon: Icons.lock_outline,
                    isObscure: obscureCurrent,
                    onToggle: () =>
                        setDialogState(() => obscureCurrent = !obscureCurrent),
                  ),
                ),
                SizedBox(height: 16),

                // New password
                Text(
                  'Mật khẩu mới',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate700,
                  ),
                ),
                SizedBox(height: 6),
                TextField(
                  controller: newPassCtrl,
                  obscureText: obscureNew,
                  style: TextStyle(fontWeight: FontWeight.w500),
                  decoration: buildDecor(
                    hint: 'Tối thiểu 6 ký tự',
                    prefixIcon: Icons.lock_rounded,
                    isObscure: obscureNew,
                    onToggle: () =>
                        setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
                SizedBox(height: 16),

                // Confirm password
                Text(
                  'Xác nhận mật khẩu mới',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate700,
                  ),
                ),
                SizedBox(height: 6),
                TextField(
                  controller: confirmPassCtrl,
                  obscureText: obscureConfirm,
                  style: TextStyle(fontWeight: FontWeight.w500),
                  decoration: buildDecor(
                    hint: 'Nhập lại mật khẩu mới',
                    prefixIcon: Icons.lock_rounded,
                    isObscure: obscureConfirm,
                    onToggle: () =>
                        setDialogState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
                SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: isLoading ? null : () => Navigator.pop(ctx),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.slate50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.slate200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.slate500,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Hủy bỏ',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: isLoading
                            ? null
                            : () async {
                                final currentPass = currentPassCtrl.text;
                                final newPass = newPassCtrl.text;
                                final confirmPass = confirmPassCtrl.text;
                                final user = store.currentUser;

                                // Validation
                                if (currentPass.isEmpty ||
                                    newPass.isEmpty ||
                                    confirmPass.isEmpty) {
                                  store.showToast(
                                    'Vui lòng điền đầy đủ thông tin',
                                    'error',
                                  );
                                  return;
                                }
                                // Securely verify password with local cache or fallback to current state if needed
                                final creds = await store
                                    .getCachedCredentials();
                                final securePass =
                                    creds?['password'] ?? user?.pass;

                                if (securePass != null &&
                                    securePass.isNotEmpty &&
                                    currentPass != securePass) {
                                  store.showToast(
                                    'Mật khẩu hiện tại không đúng',
                                    'error',
                                  );
                                  return;
                                }
                                if (newPass.length < 6) {
                                  store.showToast(
                                    'Mật khẩu mới phải có ít nhất 6 ký tự',
                                    'error',
                                  );
                                  return;
                                }
                                if (newPass != confirmPass) {
                                  store.showToast(
                                    'Mật khẩu xác nhận không khớp',
                                    'error',
                                  );
                                  return;
                                }
                                if (newPass == currentPass) {
                                  store.showToast(
                                    'Mật khẩu mới phải khác mật khẩu cũ',
                                    'error',
                                  );
                                  return;
                                }

                                setDialogState(() => isLoading = true);

                                try {
                                  // Update in Supabase (RPC handles DB/Auth syncing internally)
                                  store.updateUser(user!.username, {
                                    'pass': newPass,
                                  });
                                  try {
                                    await supabase_auth
                                        .Supabase
                                        .instance
                                        .client
                                        .auth
                                        .updateUser(
                                          supabase_auth.UserAttributes(
                                            password: newPass,
                                          ),
                                        );
                                  } catch (e) {
                                    debugPrint(
                                      '[ChangePassword] Auth update failed: $e',
                                    );
                                    // Non-fatal: users table is the primary source
                                  }

                                  // Update cached credentials for biometric
                                  await store.saveLoginCredentials(
                                    user.username,
                                    newPass,
                                  );

                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  store.showToast('Đã đổi mật khẩu thành công');
                                } catch (e) {
                                  setDialogState(() => isLoading = false);
                                  store.showToast(
                                    'Lỗi đổi mật khẩu: $e',
                                    'error',
                                  );
                                }
                              },
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.emerald500,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isLoading)
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.cardBg,
                                  ),
                                )
                              else ...[
                                Icon(
                                  Icons.save_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Đổi mật khẩu',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
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
      ),
    );
  }
}

class _SecurityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color? labelColor;
  final Color? iconColor;

  const _SecurityRow({
    super.key,
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
    this.labelColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppColors.slate500),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: labelColor ?? AppColors.slate700,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: child,
    );
  }
}
