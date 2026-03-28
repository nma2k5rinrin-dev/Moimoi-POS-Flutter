import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/core/state/app_store.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/widgets/animated_dialogs.dart';

/// Shows the upgrade prompt when a quota limit is hit.
/// Returns true if user chose to view plans, false otherwise.
Future<bool> showUpgradePrompt(BuildContext context, String limitMsg) async {
  final result = await showAnimatedDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.workspace_premium,
                  size: 32, color: Color(0xFFD97706)),
            ),
            const SizedBox(height: 16),
            Text(
              'Nâng cấp Premium',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.slate800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              limitMsg,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.slate500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn có muốn mở khóa full tính năng của cửa hàng không?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.slate800,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.slate500,
                      side: BorderSide(color: AppColors.slate200),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Để sau',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text('Xem gói Premium',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (result == true && context.mounted) {
    await showPricingDialog(context);
  }
  return result ?? false;
}

/// Pricing plans dialog with monthly/yearly options.
Future<void> showPricingDialog(BuildContext context) {
  return showAnimatedDialog(
    context: context,
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

  static const List<_PlanInfo> _plans = [
    _PlanInfo(
      name: '1 Tháng',
      price: '250.000đ',
      pricePerMonth: '250.000đ/tháng',
      badge: '',
      savings: '',
    ),
    _PlanInfo(
      name: '3 Tháng',
      price: '600.000đ',
      pricePerMonth: '200.000đ/tháng',
      badge: 'Phổ biến',
      savings: 'Tiết kiệm 20%',
    ),
    _PlanInfo(
      name: '6 Tháng',
      price: '900.000đ',
      pricePerMonth: '150.000đ/tháng',
      badge: 'Tốt nhất',
      savings: 'Tiết kiệm 40%',
    ),
    _PlanInfo(
      name: '1 Năm',
      price: '1.500.000đ',
      pricePerMonth: '125.000đ/tháng',
      badge: 'Siêu tiết kiệm',
      savings: 'Tiết kiệm 50%',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 6),
              Text(
                'Mở khóa toàn bộ tính năng, không giới hạn',
                style: TextStyle(fontSize: 13, color: AppColors.slate500),
              ),
              const SizedBox(height: 20),

              // Feature list
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _featureRow(Icons.people, 'Nhân viên không giới hạn'),
                    const SizedBox(height: 10),
                    _featureRow(Icons.table_bar, 'Bàn & khu vực không giới hạn'),
                    const SizedBox(height: 10),
                    _featureRow(Icons.restaurant_menu, 'Sản phẩm không giới hạn'),
                    const SizedBox(height: 10),
                    _featureRow(Icons.receipt_long, 'Đơn hàng không giới hạn'),
                    const SizedBox(height: 10),
                    _featureRow(Icons.qr_code, 'Thanh toán QR ngân hàng'),
                    const SizedBox(height: 10),
                    _featureRow(Icons.support_agent, 'Hỗ trợ ưu tiên 24/7'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Plans
              ...List.generate(_plans.length, (i) {
                final plan = _plans[i];
                final isSelected = _selectedPlan == i;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPlan = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.emerald500
                              : AppColors.slate200,
                          width: isSelected ? 2 : 1,
                        ),
                        color: isSelected
                            ? const Color(0xFFF0FDF4)
                            : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: isSelected
                                ? AppColors.emerald500
                                : AppColors.slate300,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
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
                                            ? AppColors.emerald700
                                            : AppColors.slate800,
                                      ),
                                    ),
                                    if (plan.badge.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: i == 2
                                              ? const Color(0xFFD97706)
                                              : AppColors.emerald500,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          plan.badge,
                                          style: const TextStyle(
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
                                      color: AppColors.emerald600,
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
                                      ? AppColors.emerald600
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

              const SizedBox(height: 10),

              // Subscribe button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final store = context.read<AppStore>();
                    const planMonths = [1, 3, 6, 12];
                    store.requestUpgrade(
                      store.currentUser?.username ?? '',
                      _selectedPlan,
                      _plans[_selectedPlan].name,
                      planMonths[_selectedPlan],
                    );
                    Navigator.pop(context);
                    if (context.mounted) {
                      context.go('/settings?tab=premium');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: Text(
                    'Đăng ký ${_plans[_selectedPlan].name} - ${_plans[_selectedPlan].price}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'Hủy bất kỳ lúc nào. Không tự động gia hạn.',
                style: TextStyle(fontSize: 11, color: AppColors.slate400),
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
        Icon(icon, size: 18, color: AppColors.emerald500),
        const SizedBox(width: 10),
        Text(text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.slate800,
            )),
      ],
    );
  }
}

class _PlanInfo {
  final String name;
  final String price;
  final String pricePerMonth;
  final String badge;
  final String savings;

  const _PlanInfo({
    required this.name,
    required this.price,
    required this.pricePerMonth,
    required this.badge,
    required this.savings,
  });
}
