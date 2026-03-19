import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage>
    with SingleTickerProviderStateMixin {
  int _selectedPlan = 1; // Default to 3-month (popular)
  late AnimationController _shimmerCtrl;

  static const List<_PlanInfo> _plans = [
    _PlanInfo(
      name: '1 Tháng',
      totalPrice: 250000,
      pricePerMonth: 250000,
      discount: 0,
      badge: '',
      badgeColor: Colors.transparent,
      icon: Icons.calendar_today,
    ),
    _PlanInfo(
      name: '3 Tháng',
      totalPrice: 600000,
      pricePerMonth: 200000,
      discount: 20,
      badge: 'Phổ biến',
      badgeColor: Color(0xFF10B981),
      icon: Icons.event_available,
    ),
    _PlanInfo(
      name: '6 Tháng',
      totalPrice: 900000,
      pricePerMonth: 150000,
      discount: 40,
      badge: 'Tốt nhất',
      badgeColor: Color(0xFFD97706),
      icon: Icons.star,
    ),
    _PlanInfo(
      name: '1 Năm',
      totalPrice: 1500000,
      pricePerMonth: 125000,
      discount: 50,
      badge: 'Siêu tiết kiệm',
      badgeColor: Color(0xFF7C3AED),
      icon: Icons.diamond,
    ),
  ];

  static const List<_FeatureItem> _features = [
    _FeatureItem(Icons.people, 'Nhân viên không giới hạn'),
    _FeatureItem(Icons.table_bar, 'Bàn & khu vực không giới hạn'),
    _FeatureItem(Icons.restaurant_menu, 'Sản phẩm không giới hạn'),
    _FeatureItem(Icons.receipt_long, 'Đơn hàng không giới hạn'),
    _FeatureItem(Icons.qr_code, 'Thanh toán QR ngân hàng'),
    _FeatureItem(Icons.support_agent, 'Hỗ trợ ưu tiên 24/7'),
    _FeatureItem(Icons.analytics, 'Báo cáo nâng cao'),
    _FeatureItem(Icons.cloud_sync, 'Đồng bộ đa thiết bị'),
  ];

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) buffer.write('.');
    }
    return '${buffer.toString().split('').reversed.join('')}đ';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    final plan = _plans[_selectedPlan];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ── Gradient Header ──
          SliverToBoxAdapter(child: _buildHeader(isWide)),

          // ── Content ──
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 40 : 16,
              vertical: 24,
            ),
            sliver: SliverToBoxAdapter(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Features
                        Expanded(flex: 4, child: _buildFeatureCard()),
                        const SizedBox(width: 24),
                        // Right: Plans + CTA
                        Expanded(flex: 6, child: _buildPlansSection(plan)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildFeatureCard(),
                        const SizedBox(height: 20),
                        _buildPlansSection(plan),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader(bool isWide) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isWide ? 40 : 20,
        isWide ? 40 : 24,
        isWide ? 40 : 20,
        isWide ? 36 : 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF065F46),
            Color(0xFF047857),
            Color(0xFF10B981),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back + Title row
            Row(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.workspace_premium,
                              color: Color(0xFFFCD34D), size: 28),
                          const SizedBox(width: 8),
                          Text(
                            'Moimoi Premium',
                            style: TextStyle(
                              fontSize: isWide ? 26 : 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mở khóa toàn bộ tính năng, phát triển cửa hàng không giới hạn',
                        style: TextStyle(
                          fontSize: isWide ? 15 : 13,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Feature Card ──
  Widget _buildFeatureCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified,
                    color: AppColors.emerald500, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tính năng Premium',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(_features.length, (i) {
            final f = _features[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(f.icon, size: 16, color: AppColors.emerald500),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      f.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate700,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const Icon(Icons.check_circle,
                      size: 18, color: AppColors.emerald500),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Plans Section ──
  Widget _buildPlansSection(_PlanInfo plan) {
    return Column(
      children: [
        // Plan Cards
        ...List.generate(_plans.length, (i) => _buildPlanCard(i)),

        const SizedBox(height: 20),

        // CTA Button
        AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (context, child) {
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF047857),
                    Color(0xFF10B981),
                    Color(0xFF047857),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emerald500.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    // TODO: Integrate payment
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Column(
                      children: [
                        Text(
                          'Đăng ký ngay — ${_formatCurrency(plan.totalPrice)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan.discount > 0
                              ? 'Chỉ ${_formatCurrency(plan.pricePerMonth)}/tháng • Tiết kiệm ${plan.discount}%'
                              : '${_formatCurrency(plan.pricePerMonth)}/tháng',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 14),

        // Disclaimer
        Text(
          'Hủy bất kỳ lúc nào. Không tự động gia hạn.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.slate400,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Plan Card ──
  Widget _buildPlanCard(int index) {
    final plan = _plans[index];
    final isSelected = _selectedPlan == index;
    final hasDiscount = plan.discount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => setState(() => _selectedPlan = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
            border: Border.all(
              color: isSelected ? AppColors.emerald500 : AppColors.slate200,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.emerald500.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Radio
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.emerald500
                        : AppColors.slate300,
                    width: isSelected ? 7 : 2,
                  ),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),

              // Plan info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(plan.icon,
                            size: 18,
                            color: isSelected
                                ? AppColors.emerald600
                                : AppColors.slate500),
                        const SizedBox(width: 8),
                        Text(
                          plan.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.emerald700
                                : AppColors.slate800,
                          ),
                        ),
                        if (plan.badge.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: plan.badgeColor,
                              borderRadius: BorderRadius.circular(6),
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
                    if (hasDiscount) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.red50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '-${plan.discount}%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.red500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tiết kiệm ${_formatCurrency((250000 * _getMonths(index)) - plan.totalPrice)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(plan.totalPrice),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? AppColors.emerald600
                          : AppColors.slate800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatCurrency(plan.pricePerMonth)}/th',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.slate400,
                      fontWeight: FontWeight.w500,
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

  int _getMonths(int planIndex) {
    switch (planIndex) {
      case 0:
        return 1;
      case 1:
        return 3;
      case 2:
        return 6;
      case 3:
        return 12;
      default:
        return 1;
    }
  }
}

// ── Data Models ──
class _PlanInfo {
  final String name;
  final int totalPrice;
  final int pricePerMonth;
  final int discount;
  final String badge;
  final Color badgeColor;
  final IconData icon;

  const _PlanInfo({
    required this.name,
    required this.totalPrice,
    required this.pricePerMonth,
    required this.discount,
    required this.badge,
    required this.badgeColor,
    required this.icon,
  });
}

class _FeatureItem {
  final IconData icon;
  final String label;
  const _FeatureItem(this.icon, this.label);
}
