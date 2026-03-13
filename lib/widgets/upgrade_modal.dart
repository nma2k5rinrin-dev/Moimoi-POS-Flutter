import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store/app_store.dart';
import '../utils/constants.dart';

class UpgradeModal extends StatelessWidget {
  const UpgradeModal({super.key});

  static const List<_PlanInfo> _plans = [
    _PlanInfo(
      name: 'Basic',
      price: '0₫',
      features: [
        '5 sản phẩm',
        '3 nhân viên',
        '2 bàn',
        'Lưu 3 ngày',
      ],
      isCurrent: false,
      color: AppColors.slate500,
    ),
    _PlanInfo(
      name: 'VIP',
      price: '99.000₫/tháng',
      features: [
        'Không giới hạn sản phẩm',
        'Không giới hạn nhân viên',
        'Không giới hạn bàn',
        'Lưu 1 năm',
        'Quản lý khu vực',
      ],
      isCurrent: false,
      color: AppColors.amber500,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '💎 Nâng Cấp Tài Khoản',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Mở khóa tất cả tính năng premium',
                style: TextStyle(
                  color: AppColors.slate500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              ...List.generate(_plans.length, (i) {
                final plan = _plans[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: i == 1
                          ? AppColors.amber400
                          : AppColors.slate200,
                      width: i == 1 ? 2 : 1,
                    ),
                    color: i == 1
                        ? AppColors.amber100.withValues(alpha: 0.3)
                        : Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            plan.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: plan.color,
                            ),
                          ),
                          Text(
                            plan.price,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: plan.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...plan.features.map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: plan.color,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  f,
                                  style: const TextStyle(
                                    color: AppColors.slate600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )),
                      if (i == 1) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              store.requestUpgrade(
                                store.currentUser?.username ?? '',
                                1,
                                'VIP',
                                1,
                              );
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.amber500,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text(
                              'Đăng Ký VIP',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  store.setUpgradeModalOpen(false);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Để sau',
                  style: TextStyle(color: AppColors.slate500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanInfo {
  final String name;
  final String price;
  final List<String> features;
  final bool isCurrent;
  final Color color;

  const _PlanInfo({
    required this.name,
    required this.price,
    required this.features,
    required this.isCurrent,
    required this.color,
  });
}
