import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/features/premium/logic/premium_store_standalone.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/features/premium/presentation/widgets/upgrade_dialog.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/services/api/cloudflare_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  static const List<_FeatureItem> _features = [
    _FeatureItem(Icons.group, 'Nhân viên không giới hạn'),
    _FeatureItem(Icons.table_bar, 'Bàn & khu vực không giới hạn'),
    _FeatureItem(Icons.inventory_2_rounded, 'Sản phẩm không giới hạn'),
    _FeatureItem(Icons.receipt_long, 'Đơn hàng không giới hạn'),
    _FeatureItem(Icons.qr_code, 'Thanh toán QR ngân hàng'),
    _FeatureItem(Icons.menu_open, 'Menu QR'),
    _FeatureItem(Icons.edit_note, 'Sổ Thu/Chi tiện lợi'),
    _FeatureItem(Icons.notifications_active, 'Âm thanh thanh toán'),
    _FeatureItem(Icons.support_agent, 'Hỗ trợ ưu tiên 24/7'),
  ];

  void _handleRegister() {
    showPricingDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PremiumStore>();
    final user = store.currentUser;
    bool isPremium = (store.storeInfos[store.getStoreId()] ?? const StoreInfoModel(name: 'No store', isPremium: false)).isPremium;
    final String fn = user?.fullname ?? '';
    final String ph = user?.phone ?? '';
    final String userName = fn.isNotEmpty ? fn : (ph.isNotEmpty ? ph : 'User');
    final userInitials = userName[0].toUpperCase();

    String expiryText = "Vĩnh viễn";

    if (user?.role == 'sadmin') {
      isPremium = true;
      expiryText = 'Vĩnh viễn';
    } else {
      if (isPremium) {
        final days = (store.storeInfos[store.getStoreId()] ?? const StoreInfoModel(name: 'No store', isPremium: false)).daysUntilExpiry;
        if (days != null) {
          if (days > 0) {
            expiryText = 'Còn $days ngày';
          } else if (days == 0) {
            expiryText = 'Hết hạn hôm nay';
          } else {
            // Expired -> fallback to basic visually
            isPremium = false;
            expiryText = 'Vĩnh viễn';
          }
        } else {
          expiryText = 'Đang sử dụng';
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg, // slate-50
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Account Card
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Row(
                children: [
                  _buildUserAvatar(store, userInitials),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tài khoản của bạn',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Gói hiện tại: ${isPremium ? "Premium" : "Miễn phí (Basic)"}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.slate500,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Thời hạn: $expiryText',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),

            // Limits Card
            if (!isPremium) ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.red50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Giới hạn của gói Basic',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildLimitLine('Giới hạn 1 nhân viên'),
                    _buildLimitLine('Giới hạn 2 bàn & 2 danh mục sản phẩm'),
                    _buildLimitLine('Giới hạn 5 sản phẩm & 10 đơn hàng/ngày'),
                    _buildLimitLine('Không có Sổ Thu/Chi'),
                    _buildLimitLine('Không có Menu QR'),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],

            // Premium Features Card
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.verified,
                          color: AppColors.primary500,
                          size: 16,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Gói Premium',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ...List.generate(_features.length, (i) {
                    final f = _features[i];
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.primary50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              f.icon,
                              size: 13,
                              color: AppColors.primary500,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              f.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppColors.primary500,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            SizedBox(height: 20),

            // CTA Button
            if (!isPremium)
              GestureDetector(
                onTap: _handleRegister,
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [Color(0xFF047857), Color(0xFF10B981)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Mở khóa Premium ngay',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tận hưởng trải nghiệm không giới hạn',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      color: AppColors.primary500,
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Bạn đang tận hưởng dịch vụ Premium',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Cảm ơn bạn đã đồng hành cùng Moimoi POS!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary600,
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () => _handleRegister(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary700,
                              side: BorderSide(color: AppColors.primary400),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 24),
                            ),
                            child: Text(
                              'Gia hạn thêm',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            SizedBox(height: 24),

            // Disclaimer
            Text(
              '📞 Hỗ trợ kỹ thuật 24/7\nHotline: 033.9524.898',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary600,
                height: 1.5,
              ),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitLine(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock, size: 16, color: Color(0xFFDC2626)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7F1D1D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(PremiumStore store, String fallbackInitial) {
    final avatar = store.currentUser?.avatar ?? '';
    Widget fallback = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          fallbackInitial,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary600,
          ),
        ),
      ),
    );

    if (avatar.isEmpty) return fallback;

    if (CloudflareService.isUrl(avatar)) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatar,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          placeholder: (_, _) => fallback,
          errorWidget: (_, _, _) => fallback,
        ),
      );
    }

    try {
      final base64Part = avatar.contains(',') ? avatar.split(',').last : avatar;
      return ClipOval(
        child: Image.memory(
          base64Decode(base64Part),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    } catch (e) {
      return fallback;
    }
  }
}

class _FeatureItem {
  final IconData icon;
  final String label;
  const _FeatureItem(this.icon, this.label);
}
