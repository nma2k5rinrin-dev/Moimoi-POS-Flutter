import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/features/premium/logic/premium_store_standalone.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/widgets/animated_dialogs.dart';
import 'package:moimoi_pos/core/router/app_router.dart';

/// Shows the upgrade prompt when a quota limit is hit.
/// Returns true if user chose to view plans, false otherwise.
Future<bool> showUpgradePrompt(BuildContext context, String limitMsg) async {
  // Prefer rootNavigatorKey context (inside MaterialApp, has MaterialLocalizations)
  final navContext = rootNavigatorKey.currentContext;
  final effectiveContext = navContext ?? context;
  
  final result = await showAnimatedDialog<bool>(
    context: effectiveContext,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      insetPadding: EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: EdgeInsets.all(24),
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
                Icons.workspace_premium,
                size: 32,
                color: Color(0xFFD97706),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Nâng cấp Premium',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.slate800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              limitMsg,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.slate500,
                height: 1.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Bạn có muốn mở khóa full tính năng của cửa hàng không?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.slate800,
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.slate500,
                        side: BorderSide(color: AppColors.slate200),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Để sau',
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
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Xem gói Premium',
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
  if (result == true && effectiveContext.mounted) {
    await showPricingDialog(effectiveContext);
  }
  return result ?? false;
}

/// Pricing plans dialog with monthly/yearly options.
Future<void> showPricingDialog(BuildContext context) {
  final navCtx = rootNavigatorKey.currentContext;
  return showAnimatedDialog(
    context: navCtx ?? context,
    builder: (ctx) => const _PricingDialog(),
  );
}

class _PricingDialog extends StatefulWidget {
  const _PricingDialog();

  @override
  State<_PricingDialog> createState() => _PricingDialogState();
}

class _PricingDialogState extends State<_PricingDialog> {
  int _selectedPlan = 0;

  static const List<_PlanInfo> _fallbackPlans = [
    _PlanInfo(
      id: 'premium_1_month',
      name: '1 Tháng',
      price: '299.000đ',
      pricePerMonth: '299.000đ/tháng',
      badge: '',
      savings: '',
    ),
    _PlanInfo(
      id: 'premium_3_months',
      name: '3 Tháng',
      price: '749.000đ',
      pricePerMonth: '249.000đ/tháng',
      badge: 'Phổ biến',
      savings: 'Tiết kiệm 16%',
    ),
    _PlanInfo(
      id: 'premium_6_months',
      name: '6 Tháng',
      price: '1.099.000đ',
      pricePerMonth: '183.000đ/tháng',
      badge: 'Tốt nhất',
      savings: 'Tiết kiệm 38%',
    ),
    _PlanInfo(
      id: 'premium_12_months',
      name: '1 Năm',
      price: '1.799.000đ',
      pricePerMonth: '149.000đ/tháng',
      badge: 'Siêu tiết kiệm',
      savings: 'Tiết kiệm 50%',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PremiumStore>();

    List<_PlanInfo> displayPlans = _fallbackPlans.toList();


    if (_selectedPlan >= displayPlans.length) {
      _selectedPlan = 0;
    }

    return Dialog(
      insetPadding: EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chọn gói Premium',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: AppColors.slate400),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Mở khóa toàn bộ tính năng, không giới hạn',
                style: TextStyle(fontSize: 13, color: AppColors.slate500),
              ),
              SizedBox(height: 20),

              // Feature list
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _featureRow(Icons.people, 'Nhân viên không giới hạn'),
                    SizedBox(height: 10),
                    _featureRow(
                      Icons.table_bar,
                      'Bàn & khu vực không giới hạn',
                    ),
                    SizedBox(height: 10),
                    _featureRow(
                      Icons.inventory_2_rounded,
                      'Sản phẩm không giới hạn',
                    ),
                    SizedBox(height: 10),
                    _featureRow(Icons.receipt_long, 'Đơn hàng không giới hạn'),
                    SizedBox(height: 10),
                    _featureRow(Icons.qr_code, 'Thanh toán QR ngân hàng'),
                    SizedBox(height: 10),
                    _featureRow(Icons.support_agent, 'Hỗ trợ ưu tiên 24/7'),
                  ],
                ),
              ),
              SizedBox(height: 20),

              if (displayPlans.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),

              ...List.generate(displayPlans.length, (i) {
                final plan = displayPlans[i];
                final isSelected = _selectedPlan == i;
                return Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPlan = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary500
                              : AppColors.slate200,
                          width: isSelected ? 2 : 1,
                        ),
                        color: isSelected ? AppColors.primary50 : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: isSelected
                                ? AppColors.primary500
                                : AppColors.slate300,
                            size: 22,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      plan.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? AppColors.primary700
                                            : AppColors.slate800,
                                      ),
                                    ),
                                    if (plan.badge.isNotEmpty) ...[
                                      SizedBox(width: 8),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: i == 2
                                              ? const Color(0xFFD97706)
                                              : AppColors.primary500,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          plan.badge,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (plan.savings.isNotEmpty)
                                  Text(
                                    plan.savings,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                plan.price,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? AppColors.primary600
                                      : AppColors.slate800,
                                ),
                              ),
                              Text(
                                plan.pricePerMonth,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.slate400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              SizedBox(height: 10),

              // Subscribe button
              if (displayPlans.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: store.isLoading
                        ? null
                        : () async {
                            final plan = displayPlans[_selectedPlan];
                            final storeId = store.getStoreId();
                            if (storeId.isEmpty) return;

                            try {
                              final now = DateTime.now();
                              final cleanStr = plan.price.replaceAll(RegExp(r'[^0-9]'), '');
                              final amt = int.tryParse(cleanStr) ?? 0;

                              await store.supabaseClient.from('upgrade_requests').insert({
                                'username': storeId,
                                'plan_name': plan.name,
                                'amount': amt,
                                'status': 'pending',
                                'transfer_content': '',
                                'created_at': now.toIso8601String(),
                              });
                            } catch (e) {
                              store.showToast('Lỗi gửi Data: $e', 'error');
                              return; // Stop if core table fails
                            }

                            try {
                              final now = DateTime.now();
                              await store.supabaseClient.from('notifications').insert({
                                'id': const Uuid().v4(),
                                'user_id': 'sadmin',
                                'title': 'Yêu cầu nâng cấp Premium',
                                'message': 'Cửa hàng $storeId yêu cầu đăng ký gói ${plan.name}.',
                                'time': now.toIso8601String(),
                                'read': false,
                              });
                            } catch (_) {
                              // Ignore RLS errors for admin sending to sadmin
                            }

                            store.showToast('Vui lòng liên hệ Hotline/Zalo: 033.9524.898 để hướng dẫn thanh toán', 'info');
                            if (context.mounted) Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: store.isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.cardBg,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Đăng ký ${displayPlans[_selectedPlan].name} - ${displayPlans[_selectedPlan].price}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

              SizedBox(height: 8),
              Text(
                'Hủy bất kỳ lúc nào. Không tự động gia hạn.',
                style: TextStyle(fontSize: 11, color: AppColors.slate400),
              ),


              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business_center, size: 16, color: AppColors.slate600),
                        SizedBox(width: 8),
                        Text(
                          'Chuỗi Cửa hàng / Ưu đãi Doanh nghiệp',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Cần xuất VAT hoặc ưu đãi khi mua chuỗi cửa hàng? Vui lòng liên hệ Hotline/Zalo kỹ thuật: 033.9524.898',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.slate600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary500),
        SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.slate800,
          ),
        ),
      ],
    );
  }
}

class _PlanInfo {
  final String id;
  final String name;
  final String price;
  final String pricePerMonth;
  final String badge;
  final String savings;

  const _PlanInfo({
    required this.id,
    required this.name,
    required this.price,
    required this.pricePerMonth,
    required this.badge,
    required this.savings,
  });
}
