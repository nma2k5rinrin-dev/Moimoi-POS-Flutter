import 'dart:convert';
import 'dart:math' as math;
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
import 'package:moimoi_pos/features/premium/presentation/widgets/upgrade_dialog.dart';
import 'package:moimoi_pos/core/utils/image_helper.dart';
import 'package:moimoi_pos/core/widgets/thematic_motif_painter.dart';
import 'package:moimoi_pos/features/notifications/presentation/notification_bell.dart';
import 'package:moimoi_pos/core/utils/notification_helper.dart';

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
        return 'Chủ cửa hàng';
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
      backgroundColor: AppColors.primary100,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.primary600,
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
              width: 360,
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 32,
              ),
              decoration: BoxDecoration(
                gradient: store.currentUser?.isPremium == true || store.currentUser?.role == 'sadmin'
                    ? LinearGradient(
                        colors: [AppColors.primary100, AppColors.blue50, AppColors.primary50],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : LinearGradient(
                        colors: [AppColors.slate100, AppColors.blue50, AppColors.slate200],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
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
              child: Stack(
                children: [
                   // Thematic Motif Layer for the entire dialog
                   Positioned.fill(
                     child: ClipRRect(
                       borderRadius: BorderRadius.circular(20),
                       child: ThematicMotifWidget(
                         theme: context.watch<UIStore>().activeTheme,
                         overrideColor: (store.currentUser?.isPremium == true || store.currentUser?.role == 'sadmin') ? AppColors.primary500 : AppColors.slate400,
                       ),
                     ),
                   ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── User Header ──
                  _buildUserHeader(context),

                  // ── Group 0: Quick Actions ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 1. Notification
                        _buildQuickAction(
                          context,
                          icon: Consumer<ManagementStore>(
                            builder: (ctx, mStore, _) {
                              final unreadCount = mStore.notifications.where((n) => !n.read).length;
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(Icons.notifications_rounded, color: AppColors.slate700, size: 24),
                                  if (unreadCount > 0)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.red500,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                        child: Text(
                                          '${unreadCount > 99 ? '99+' : unreadCount}',
                                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }
                          ),
                          label: 'Thông báo',
                          onTap: () {
                            Navigator.pop(context);
                            NotificationHelper.clearAppBadge();
                            moimoiShowNotificationDialog(context, context.read<UIStore>());
                          },
                        ),
                        // 2. Theme
                        _buildQuickAction(
                          context,
                          icon: Icon(Icons.palette_rounded, color: AppColors.slate700, size: 24),
                          label: 'Chủ đề',
                          onTap: () {
                            _showThemeDialog(context);
                          },
                        ),
                        // 3. System Theme / Dark Mode
                        Builder(
                          builder: (ctx) {
                            final isDark = context.watch<UIStore>().isDarkMode;
                            return _buildQuickAction(
                              context,
                              icon: Icon(
                                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                color: AppColors.slate700,
                                size: 24,
                              ),
                              label: isDark ? 'Nền tối' : 'Nền sáng',
                              onTap: () {
                                context.read<UIStore>().toggleTheme();
                              },
                            );
                          }
                        ),
                        // 4. Premium
                        if (store.currentUser?.role != 'sadmin' && store.currentUser?.role != 'staff')
                          _buildQuickAction(
                            context,
                            icon: Icon(Icons.workspace_premium_rounded, color: AppColors.slate700, size: 24),
                            label: 'Gia hạn gói',
                            onTap: () {
                              showPricingDialog(context, anchorTopRight: true);
                            },
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),

                  // ── Group 1: General Settings ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          // Options

                          // Xem QR
                          if (store.currentUser?.role != 'sadmin')
                            _buildMenuItem(
                              context,
                              icon: Icons.qr_code_2_rounded,
                              label: 'Xem QR thanh toán',
                              onTap: () {
                                Navigator.pop(context);
                                _showQRDialog(context);
                              },
                            ),
                          if (store.currentUser?.role != 'sadmin' && _isOwnerOrAdmin)
                            Divider(height: 1, indent: 48, color: AppColors.slate200),
                          
                          // Settings
                          if (_isOwnerOrAdmin)
                            _buildMenuItem(
                              context,
                              icon: Icons.settings_rounded,
                              label: 'Cài đặt hệ thống',
                              onTap: () {
                                Navigator.pop(context);
                                context.push('/settings');
                              },
                            ),
                           // Lịch sử thanh toán
                           if (store.currentUser?.role != 'sadmin' && _isOwnerOrAdmin) ...[
                             Divider(height: 1, indent: 48, color: AppColors.slate200),
                             _buildMenuItem(
                                context,
                                icon: Icons.history_edu_rounded,
                                label: 'Lịch sử thanh toán & hóa đơn',
                                onTap: () {
                                  Navigator.pop(context);
                                  showPaymentHistoryDialog(context);
                                }
                             ),
                           ],
                        ],
                      ),
                    ),
                  ),

                  // ── Group 2: Subscription Section (Moved into Header) ──

                  SizedBox(height: 24),

                  // ── Group 3: Logout ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildLogoutButton(context),
                  ),
                ],
              ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserHeader(BuildContext context) {
    final user = store.currentUser!;
    final isPremium = user.isPremium || user.role == 'sadmin';
    final planLabel = isPremium ? 'Premium' : 'Miễn phí';

    String expiryDate = '—';
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
    String remainingDaysStr = '';
    if (expiry != null) {
      expiryDate = '${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}';
      hasExpiry = true;
      final diff = expiry.difference(DateTime.now()).inDays;
      if (diff > 0) {
        remainingDaysStr = ' (còn $diff ngày)';
      } else if (diff == 0) {
        remainingDaysStr = ' (hết hạn hôm nay)';
      } else {
        remainingDaysStr = ' (đã hết hạn)';
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: Column(
        children: [
          Row(
            children: [
               _buildDialogAvatar(),
               SizedBox(width: 20),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       _displayName,
                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.slate800, letterSpacing: -0.5),
                     ),
                     SizedBox(height: 10),
                     Wrap(
                       spacing: 8,
                       runSpacing: 8,
                       crossAxisAlignment: WrapCrossAlignment.center,
                       children: [
                         Container(
                           padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                           decoration: BoxDecoration(
                             color: isPremium ? AppColors.primary500 : AppColors.slate400,
                             borderRadius: BorderRadius.circular(8),
                           ),
                           child: Text(
                             planLabel.toUpperCase(),
                             style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                           ),
                         ),
                          if (hasExpiry && store.currentUser?.role != 'sadmin')
                            Text('Đến $expiryDate$remainingDaysStr', style: TextStyle(fontSize: 13, color: AppColors.slate600, fontWeight: FontWeight.w600)),
                       ],
                     ),
                   ]
                 ),
               ),
            ]
          ),

        ],
      ), // Column
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Icon(icon, size: 18, color: AppColors.slate700),
              ),
              SizedBox(width: 12),
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
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.red100,
        highlightColor: AppColors.red50,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.red50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.red100),
          ),
          padding: EdgeInsets.symmetric(vertical: 16),
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
              Icon(Icons.qr_code_2, size: 48, color: AppColors.primary500),
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

  Widget _buildQuickAction(
    BuildContext context, {
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.5)),
              boxShadow: [
                 BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))
              ]
            ),
            alignment: Alignment.center,
            child: icon,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.slate800,
            ),
          )
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Chọn Giao Diện', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate800)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: AppTheme.values.map((theme) {
                  final uiStore = context.watch<UIStore>();
                  final isSelected = uiStore.activeTheme == theme;
                  Color themeColor = AppColors.emerald500;
                  switch (theme) {
                    case AppTheme.blue: themeColor = AppColors.blue500; break;
                    case AppTheme.violet: themeColor = AppColors.violet500; break;
                    case AppTheme.amber: themeColor = AppColors.amber500; break;
                    case AppTheme.rose: themeColor = AppColors.rose500; break;
                    case AppTheme.emerald: themeColor = AppColors.emerald500; break;
                  }
                  return GestureDetector(
                    onTap: () => context.read<UIStore>().changeColorTheme(theme),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: themeColor,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: AppColors.slate800, width: 3) : Border.all(color: Colors.transparent, width: 3),
                        boxShadow: [
                          if (isSelected) BoxShadow(color: themeColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: isSelected ? const Icon(Icons.check_rounded, size: 20, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.slate100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Đóng', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountHeaderWaveClipper extends CustomClipper<Path> {
  final double yOffset;
  final double phaseOffset; // Left/Right phase shift
  final double frequency; // Wave loop frequency
  final double amplitude; // Height of hills/valleys
  final AppTheme theme;

  _AccountHeaderWaveClipper({
    this.yOffset = 0, 
    this.phaseOffset = 0, 
    this.frequency = 1.0,
    this.amplitude = 20.0,
    this.theme = AppTheme.emerald,
  });

  @override
  Path getClip(Size size) {
    var path = Path();
    
    // The base horizon height
    double baseHeight = size.height - 48 + yOffset;
    path.lineTo(0.0, baseHeight);

    double f = frequency;
    double a = amplitude;
    
    switch(theme) {
      case AppTheme.blue:
        f *= 0.6; // Wide ocean waves
        a *= 0.9;
        break;
      case AppTheme.violet:
        f *= 1.4; // High interference multi-wave
        a *= 0.8;
        break;
      case AppTheme.amber:
        f *= 0.8; // Deep, steep cuts
        a *= 1.6;
        break;
      case AppTheme.rose:
        f *= 1.8; // Bouncy multiple shallow jumps
        a *= 0.5;
        break;
      case AppTheme.emerald:
        break; // Default fluid tech waves
    }

    // Plot points for continuous true sine wave
    for (double i = 0.0; i <= size.width; i += 2.0) {
      double pct = i / size.width;
      
      double rad = (pct * 2 * math.pi * f) + phaseOffset;
      
      double yOffsetWave = 0.0;
      switch(theme) {
        case AppTheme.amber:
          // Negative absolute sine creates sharp desert "dunes/points"
          yOffsetWave = -math.sin(rad).abs() * a;
          break;
        case AppTheme.violet:
          // Cosmic chaos: intersecting multiple distinct sine waves
          yOffsetWave = (math.sin(rad) * a) + (math.cos(rad * 2.3) * a * 0.4);
          break;
        case AppTheme.rose:
          // Smooth pulsating bouncing curves
          yOffsetWave = math.sin(rad).abs() * a;
          break;
        case AppTheme.blue:
        case AppTheme.emerald:
          yOffsetWave = math.sin(rad) * a;
          break;
      }
      
      double y = baseHeight + yOffsetWave;
      path.lineTo(i, y);
    }

    // Top Right
    path.lineTo(size.width, 0.0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(_AccountHeaderWaveClipper oldClipper) {
    return oldClipper.yOffset != yOffset ||
           oldClipper.phaseOffset != phaseOffset ||
           oldClipper.frequency != frequency ||
           oldClipper.amplitude != amplitude;
  }
}
