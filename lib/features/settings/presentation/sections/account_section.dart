import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moimoi_pos/core/state/app_store.dart';
import 'package:moimoi_pos/features/auth/models/user_model.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/services/api/cloudflare_service.dart';

Uint8List _decodeAvatar(String dataUri) {
  final base64Part = dataUri.split(',').last;
  return base64Decode(base64Part);
}

class AccountSection extends StatefulWidget {
  const AccountSection({super.key});

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

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _phoneController.text = store.currentUser?.phone ?? '';
    if (store.currentUser?.role == 'sadmin') {
      final sadminInfo = store.storeInfos['sadmin'] ?? const StoreInfoModel();
      _bankNameController.text = sadminInfo.bankId;
      _bankAccountController.text = sadminInfo.bankAccount;
      _bankOwnerController.text = sadminInfo.bankOwner;
    }
    _initBiometricState();
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
        if (!context.mounted) return;
        final store = context.read<AppStore>();
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
    final store = context.read<AppStore>();

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
            'error');
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
    final store = context.watch<AppStore>();
    final user = store.currentUser;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      children: [
                        _buildAvatarSection(store, user),
                        const SizedBox(height: 28),
                        _buildIdentitySection(user),
                        const SizedBox(height: 16),
                        _buildSecuritySeparator(),
                        const SizedBox(height: 16),
                        _buildSecurityRows(store),
                      ],
                    ),
                  ),
                  if (user?.role == 'sadmin') ...[
                    const SizedBox(height: 24),
                    _buildBankSection(store),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
        _buildBottomActions(store, user),
      ],
    );
  }

  Widget _buildAvatarSection(AppStore store, UserModel? user) {
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
                            placeholder: (_, _) => const CircularProgressIndicator(),
                            errorWidget: (_, _, _) => const Icon(Icons.error),
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
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emerald600),
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
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, size: 13, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              user?.fullname.isNotEmpty == true ? user!.fullname : (user?.username ?? 'User'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slate800),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _showEditFullnameDialog(context, store, user),
              child: const Icon(Icons.edit, size: 16, color: AppColors.emerald500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Kích hoạt: ${_formatCreatedAt(user?.createdAt)}',
          style: const TextStyle(fontSize: 13, color: AppColors.slate400),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.emerald50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded, size: 14, color: AppColors.emerald500),
              const SizedBox(width: 4),
              Text(
                _getRoleName(user?.role),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.emerald600),
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
        Expanded(child: _buildReadonlyField('Tên đăng nhập', user?.username ?? '', Icons.alternate_email_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _buildEditableField('Số điện thoại', _phoneController, Icons.phone_outlined, '0912 345 678')),
      ],
    );
  }

  Widget _buildReadonlyField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.slate400),
              const SizedBox(width: 8),
              Text(value, style: const TextStyle(fontSize: 14, color: AppColors.slate500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, IconData icon, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.slate400),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: const TextStyle(color: AppColors.slate300)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySeparator() {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.slate200)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('Bảo mật', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate400)),
        ),
        Expanded(child: Divider(color: AppColors.slate200)),
      ],
    );
  }

  Widget _buildSecurityRows(AppStore store) {
    return Column(
      children: [
        _SecurityRow(
          icon: Icons.lock_outline_rounded,
          label: 'Đổi mật khẩu',
          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.slate400),
          onTap: () => _showChangePasswordDialog(context, store),
        ),
        const SizedBox(height: 10),
        _SecurityRow(
          icon: Icons.fingerprint_rounded,
          label: 'Vân tay / FaceID',
          trailing: _biometricAvailable
              ? Switch(value: _biometricEnabled, activeTrackColor: AppColors.emerald500, onChanged: _toggleBiometric)
              : const Text('Không hỗ trợ', style: TextStyle(fontSize: 13, color: AppColors.slate400)),
        ),
      ],
    );
  }

  Widget _buildBankSection(AppStore store) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(child: Divider(color: AppColors.slate200)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Thanh toán ngân hàng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate400)),
              ),
              Expanded(child: Divider(color: AppColors.slate200)),
            ],
          ),
          const SizedBox(height: 16),
          _buildEditableField('Tên ngân hàng', _bankNameController, Icons.account_balance_outlined, 'VD: TECHCOMBANK'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildEditableField('Số tài khoản', _bankAccountController, Icons.credit_card_outlined, 'VD: 19034153150012')),
              const SizedBox(width: 12),
              Expanded(child: _buildEditableField('Chủ tài khoản', _bankOwnerController, Icons.person_outline, 'VD: NGUYEN VAN A')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(AppStore store, UserModel? user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _phoneController.text = user?.phone ?? '',
                child: const Text('Hủy bỏ'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                   store.updateUser(user!.username, {'phone': _phoneController.text});
                   store.showToast('Đã lưu thay đổi');
                },
                child: const Text('Lưu thay đổi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---
  String _getRoleName(String? role) {
    switch (role) {
      case 'sadmin': return 'Super Admin';
      case 'admin': return 'Admin';
      default: return 'Nhân viên';
    }
  }

  String _formatCreatedAt(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) { return dateStr; }
  }

  void _showAvatarPicker(BuildContext context, AppStore store, dynamic user) {
    // Full logic from settings_page.dart (abbreviated here for visibility)
    // In real implementation, include the full showDialog + _pickAndCropAvatar logic
  }

  void _showEditFullnameDialog(BuildContext context, AppStore store, UserModel? user) {
     // TODO: Implement edit fullname dialog
  }
  void _showChangePasswordDialog(BuildContext context, AppStore store) {
     // TODO: Implement change password dialog
  }
}

class _SecurityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;
  const _SecurityRow({required this.icon, required this.label, required this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.slate500),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.slate700))),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: child,
    );
  }
}
