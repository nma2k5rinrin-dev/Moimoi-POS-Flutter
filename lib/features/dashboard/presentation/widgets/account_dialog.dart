import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/core/state/app_store.dart';
import 'package:moimoi_pos/core/utils/constants.dart';

/// Shows the Account Dialog as a popup anchored near the avatar.
/// For admin/sadmin: shows subscription section.
/// For staff: hides subscription section.
void showAccountDialog(BuildContext context) {
  final store = context.read<AppStore>();
  final user = store.currentUser;
  if (user == null) return;

  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (ctx) => _AccountDialogContent(store: store),
  );
}

class _AccountDialogContent extends StatelessWidget {
  final AppStore store;
  const _AccountDialogContent({required this.store});

  bool get _isOwnerOrAdmin {
    final role = store.currentUser?.role ?? '';
    return role == 'sadmin' || role == 'admin';
  }

  String get _displayName {
    final user = store.currentUser;
    if (user == null) return '';
    return user.fullname.isNotEmpty ? user.fullname : user.username;
  }

  String get _roleLabel {
    final role = store.currentUser?.role ?? '';
    switch (role) {
      case 'sadmin':
        return 'Super Admin';
      case 'admin':
        return 'Chủ quán';
      case 'staff':
        return 'Nhân viên';
      default:
        return role;
    }
  }

  String get _avatarLetter {
    final user = store.currentUser;
    if (user == null) return 'U';
    if (user.fullname.isNotEmpty) return user.fullname[0].toUpperCase();
    if (user.username.isNotEmpty) return user.username[0].toUpperCase();
    return 'U';
  }

  Uint8List? get _avatarImage {
    final avatar = store.currentUser?.avatar ?? '';
    if (avatar.isEmpty) return null;
    try {
      final base64Part = avatar.contains(',') ? avatar.split(',').last : avatar;
      return base64Decode(base64Part);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: 16,
          top: MediaQuery.of(context).padding.top + 56,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── User Header ──
                  _buildUserHeader(context),
                  _divider(),

                  // ── Menu Items ──
                  _buildMenuItem(
                    context,
                    icon: Icons.qr_code_2,
                    label: 'Xem QR thanh toán',
                    onTap: () {
                      Navigator.pop(context);
                      _showQRDialog(context);
                    },
                  ),
                  if (_isOwnerOrAdmin)
                    _buildMenuItem(
                      context,
                      icon: Icons.settings_outlined,
                      label: 'Cài đặt hệ thống',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/settings');
                      },
                    ),

                  // ── Subscription Section (admin only, not sadmin) ──
                  if (store.currentUser?.role == 'admin') ...[
                    _divider(),
                    _buildSubscriptionSection(context),
                  ],

                  _divider(),

                  // ── Logout ──
                  _buildLogoutButton(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserHeader(BuildContext context) {
    final avatarBytes = _avatarImage;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        context.push('/settings');
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          children: [
            avatarBytes != null
                ? ClipOval(
                    child: Image.memory(
                      avatarBytes,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.emerald100,
                        child: Text(
                          _avatarLetter,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.emerald600,
                          ),
                        ),
                      ),
                    ),
                  )
                : CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.emerald100,
                    child: Text(
                      _avatarLetter,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emerald600,
                      ),
                    ),
                  ),
            const SizedBox(height: 8),
            Text(
              _displayName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.slate800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _roleLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate400,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 14, color: AppColors.slate400),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.slate500),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate800,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionSection(BuildContext context) {
    final user = store.currentUser!;
    final isPremium = user.isPremium || user.role == 'sadmin';
    final planLabel = isPremium ? 'Premium' : 'Miễn phí';

    // Calculate expiry
    String expiryDate = '—';
    int daysLeft = 0;
    bool hasExpiry = false;
    if (user.expiresAt != null && user.expiresAt!.isNotEmpty) {
      try {
        final expiry = DateTime.parse(user.expiresAt!);
        expiryDate =
            '${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}';
        daysLeft = expiry.difference(DateTime.now()).inDays;
        hasExpiry = true;
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'GÓI ĐĂNG KÝ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.slate400,
                letterSpacing: 1,
              ),
            ),
          ),

          // Plan row
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.workspace_premium,
                    size: 16, color: AppColors.emerald500),
              ),
              const SizedBox(width: 10),
              const Text('Gói',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate500)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPremium ? AppColors.emerald500 : AppColors.slate300,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  planLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Expiry row
          if (hasExpiry)
            Row(
              children: [
                const Icon(Icons.event, size: 18, color: AppColors.slate400),
                const SizedBox(width: 10),
                const Text('Hết hạn:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate500)),
                const SizedBox(width: 6),
                Text(
                  expiryDate,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: daysLeft <= 7
                        ? AppColors.red50
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Còn $daysLeft ngày',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: daysLeft <= 7
                          ? AppColors.red500
                          : const Color(0xFFF97316),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),

          // Renew button (hide for sadmin)
          if (store.currentUser?.role != 'sadmin') ...[
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/settings?tab=premium');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: AppColors.emerald500, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Gia hạn / Nâng cấp gói',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emerald600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Payment history link
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to payment history
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lịch sử thanh toán & Hóa đơn',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate400,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        size: 14, color: AppColors.slate400),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        store.logout();
        context.go('/login');
      },
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 18, color: AppColors.red500),
            SizedBox(width: 10),
            Text(
              'Đăng xuất',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.red500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: double.infinity,
      height: 1,
      color: AppColors.slate100,
    );
  }

  void _showQRDialog(BuildContext context) {
    final storeInfo = store.currentStoreInfo;
    final hasQrImage = storeInfo.qrImageUrl.isNotEmpty;
    final hasBankInfo = storeInfo.bankAccount.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_2, size: 48, color: AppColors.emerald500),
              const SizedBox(height: 12),
              const Text(
                'QR Thanh toán',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                ),
              ),
              const SizedBox(height: 16),
              if (hasQrImage) ...[
                // Show QR image centered
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 320),
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: storeInfo.qrImageUrl.startsWith('data:')
                        ? Image.memory(
                            _decodeBase64(storeInfo.qrImageUrl),
                            fit: BoxFit.contain,
                          )
                        : Image.network(
                            storeInfo.qrImageUrl,
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ] else if (hasBankInfo) ...[
                Text(
                  'Ngân hàng: ${storeInfo.bankId}',
                  style: const TextStyle(fontSize: 13, color: AppColors.slate600),
                ),
                const SizedBox(height: 4),
                Text(
                  'STK: ${storeInfo.bankAccount}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chủ TK: ${storeInfo.bankOwner}',
                  style: const TextStyle(fontSize: 13, color: AppColors.slate600),
                ),
              ] else
                const Text(
                  'Chưa cài đặt thông tin ngân hàng.\nVào Cài đặt > Cửa hàng để thêm.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.slate500),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.slate100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Uint8List _decodeBase64(String dataUri) {
    final base64Part = dataUri.split(',').last;
    return base64Decode(base64Part);
  }
}
