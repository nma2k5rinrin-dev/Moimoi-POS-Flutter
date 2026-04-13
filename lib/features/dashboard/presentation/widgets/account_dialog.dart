import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';
import 'package:moimoi_pos/core/state/ui_store.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/services/api/cloudflare_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moimoi_pos/features/premium/presentation/widgets/payment_history_dialog.dart';
import 'package:moimoi_pos/core/utils/image_helper.dart';

/// Shows the Account Dialog as a popup anchored near the avatar.
/// For admin/sadmin: shows subscription section.
/// For staff: hides subscription section.
void showAccountDialog(BuildContext context) {
  final store = context.read<AuthStore>();
  final user = store.currentUser;
  if (user == null) return;

  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (ctx) => Consumer<AuthStore>(
      builder: (context, store, _) => _AccountDialogContent(store: store),
    ),
  );
}

class _AccountDialogContent extends StatelessWidget {
  final AuthStore store;
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

  Widget _buildDialogAvatar() {
    const double radius = 28;
    final avatar = store.currentUser?.avatar ?? '';
    final letter = _avatarLetter;

    Widget fallback() => CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.emerald100,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.emerald600,
        ),
      ),
    );

    if (avatar.isEmpty) return fallback();

    // Cloudflare / network URL
    if (CloudflareService.isUrl(avatar)) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatar,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (_, _) => SizedBox(
            width: 56,
            height: 56,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (_, _, _) => fallback(),
        ),
      );
    }

    // Base64
    try {
      final base64Part = avatar.contains(',') ? avatar.split(',').last : avatar;
      final bytes = base64Decode(base64Part);
      return ClipOval(
        child: Image.memory(
          bytes,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback(),
        ),
      );
    } catch (_) {
      return fallback();
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
              width: 320,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
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

                  // ── Dark Mode Toggle ──
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              context.watch<UIStore>().isDarkMode
                                  ? Icons.dark_mode
                                  : Icons.light_mode,
                              size: 20,
                              color: AppColors.slate500,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Giao diện tối',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate800,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: context.watch<UIStore>().isDarkMode,
                          onChanged: (val) {
                            context.read<UIStore>().toggleTheme();
                          },
                          activeColor: AppColors.emerald500,
                        ),
                      ],
                    ),
                  ),
                  _divider(),

                  // â”€â”€ Background Service Toggle â”€â”€
                  if (!kIsWeb)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                size: 20,
                                color: AppColors.slate500,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Bật nhận đơn dưới nền',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.slate800,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: context.watch<UIStore>().isBackgroundServiceEnabled,
                            onChanged: (val) {
                              context.read<UIStore>().toggleBackgroundService(val);
                            },
                            activeColor: AppColors.emerald500,
                          ),
                        ],
                      ),
                    ),
                  if (!kIsWeb) _divider(),

                  // ── Menu Items ──
                  if (store.currentUser?.role != 'sadmin')
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
        padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          children: [
            _buildDialogAvatar(),
            SizedBox(height: 8),
            Text(
              _displayName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.slate800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _roleLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate400,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 14, color: AppColors.slate400),
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
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.slate500),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate800,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.slate400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionSection(BuildContext context) {
    final user = store.currentUser!;
    final isPremium = user.isPremium || user.role == 'sadmin';
    final planLabel = isPremium ? 'Premium' : 'Miễn phí';

    // Calculate expiry — prefer store_infos.premiumExpiresAt (same source as sadmin dashboard)
    String expiryDate = '—';
    int daysLeft = 0;
    bool hasExpiry = false;
    final storeInfo = (context.watch<ManagementStore>().storeInfos[context.watch<ManagementStore>().getStoreId()] ?? const StoreInfoModel());
    DateTime? expiry;
    if (storeInfo.premiumExpiresAt != null) {
      expiry = storeInfo.premiumExpiresAt;
    } else if (user.expiresAt != null && user.expiresAt!.isNotEmpty) {
      try {
        expiry = DateTime.parse(user.expiresAt!);
      } catch (_) {}
    }
    if (expiry != null) {
      expiryDate =
          '${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}';
      daysLeft = expiry.difference(DateTime.now()).inDays;
      hasExpiry = true;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Padding(
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
                child: Icon(
                  Icons.workspace_premium,
                  size: 16,
                  color: AppColors.emerald500,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Gói',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate500,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPremium ? AppColors.emerald500 : AppColors.slate300,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  planLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          // Expiry row
          if (hasExpiry)
            Row(
              children: [
                Icon(Icons.event, size: 18, color: AppColors.slate400),
                SizedBox(width: 10),
                Text(
                  'Hết hạn:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate500,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  expiryDate,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: daysLeft <= 7 ? AppColors.red50 : AppColors.orange50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Còn $daysLeft ngày',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: daysLeft <= 7
                          ? AppColors.red500
                          : AppColors.orange500,
                    ),
                  ),
                ),
              ],
            ),
          SizedBox(height: 12),

          // Renew button (hide for sadmin)
          if (store.currentUser?.role != 'sadmin') ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/settings?tab=premium');
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.emerald500, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Gia hạn / Nâng cấp gói',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emerald600,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),

            // Payment history link
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context); // Close the account dialog
                  showPaymentHistoryDialog(
                    context,
                  ); // Show payment history dialog
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lịch sử thanh toán & Hóa đơn',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.slate400,
                    ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          store.logout();
          context.go('/login');
        },
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        splashColor: AppColors.red100,
        highlightColor: AppColors.red50,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.red50,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 20, color: AppColors.red600),
              SizedBox(width: 10),
              Text(
                'Đăng xuất',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.red600,
                ),
              ),
            ],
          ),
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
    final storeInfo = (context.watch<ManagementStore>().storeInfos[context.watch<ManagementStore>().getStoreId()] ?? const StoreInfoModel());
    final hasQrImage = storeInfo.qrImageUrl.isNotEmpty;
    final hasBankInfo = storeInfo.bankAccount.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 480,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_2, size: 48, color: AppColors.emerald500),
              SizedBox(height: 12),
              Text(
                'QR Thanh toán',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                ),
              ),
              SizedBox(height: 16),
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
                  child: SmartImage(
                    imageData: storeInfo.qrImageUrl,
                    fit: BoxFit.contain,
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ] else if (hasBankInfo) ...[
                Text(
                  'Ngân hàng: ${storeInfo.bankId}',
                  style: TextStyle(fontSize: 13, color: AppColors.slate600),
                ),
                SizedBox(height: 4),
                Text(
                  'STK: ${storeInfo.bankAccount}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Chủ TK: ${storeInfo.bankOwner}',
                  style: TextStyle(fontSize: 13, color: AppColors.slate600),
                ),
              ] else
                Text(
                  'Chưa cài đặt thông tin ngân hàng.\nVào Cài đặt > Cửa hàng để thêm.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.slate500),
                ),
              SizedBox(height: 16),
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
                  child: Text(
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
