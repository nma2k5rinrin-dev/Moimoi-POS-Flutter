import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../utils/constants.dart';
import '../../utils/format.dart';
import '../../models/order_model.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _timeRange = 'today';
  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final allOrders = store.visibleOrders;
    final paidOrders =
        allOrders.where((o) => o.paymentStatus == 'paid').toList();
    final filteredOrders = _filterByTime(paidOrders);

    final totalRevenue =
        filteredOrders.fold(0.0, (acc, o) => acc + o.totalAmount);
    final totalOrders = filteredOrders.length;
    final avgOrder = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;
    final bestSellers = _getBestSellers(filteredOrders);
    final weekData = _getWeekData(paidOrders);

    return Container(
      color: const Color(0xFFFAFBFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.insights_rounded,
                      color: AppColors.blue500, size: 24),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Báo Cáo Doanh Thu',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slate800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Phân tích hiệu quả kinh doanh',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Time Range Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TimeChip(
                      label: 'Hôm nay',
                      isActive: _timeRange == 'today',
                      onTap: () =>
                          setState(() => _timeRange = 'today')),
                  _TimeChip(
                      label: 'Tháng này',
                      isActive: _timeRange == 'month',
                      onTap: () =>
                          setState(() => _timeRange = 'month')),
                ],
              ),
            ),

            const SizedBox(height: 12),
            _DateRangePicker(
              dateFrom: _dateFrom,
              dateTo: _dateTo,
              onFromChanged: (d) => setState(() => _dateFrom = d),
              onToChanged: (d) => setState(() => _dateTo = d),
            ),

            const SizedBox(height: 20),

            // Stats Cards — 1 large + 2 small
            _StatCard(
              label: 'Doanh thu',
              value: formatCurrency(totalRevenue),
              icon: Icons.trending_up_rounded,
              gradient: const [Color(0xFF10B981), Color(0xFF059669)],
              width: double.infinity,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Tổng đơn',
                    value: '$totalOrders',
                    icon: Icons.receipt_long_rounded,
                    gradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    width: double.infinity,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _StatCard(
                    label: 'TB/đơn',
                    value: _formatShortCurrency(avgOrder),
                    icon: Icons.analytics_outlined,
                    gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                    width: double.infinity,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Charts Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _RevenueChart(weekData: weekData),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            _BestSellersCard(items: bestSellers),
                            const SizedBox(height: 14),
                            _StaffRankingCard(orders: filteredOrders),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _RevenueChart(weekData: weekData),
                    const SizedBox(height: 14),
                    _BestSellersCard(items: bestSellers),
                    const SizedBox(height: 14),
                    _StaffRankingCard(orders: filteredOrders),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<OrderModel> _filterByTime(List<OrderModel> orders) {
    final now = DateTime.now();
    return orders.where((o) {
      final dt = DateTime.tryParse(o.time);
      if (dt == null) return false;
      switch (_timeRange) {
        case 'today':
          return dt.day == now.day &&
              dt.month == now.month &&
              dt.year == now.year;
        case 'month':
          return dt.month == now.month && dt.year == now.year;
        case 'year':
          return dt.year == now.year;
        case 'range':
          final from =
              DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
          final to = DateTime(
              _dateTo.year, _dateTo.month, _dateTo.day, 23, 59, 59);
          return dt.isAfter(from.subtract(const Duration(seconds: 1))) &&
              dt.isBefore(to.add(const Duration(seconds: 1)));
        default:
          return false;
      }
    }).toList();
  }

  List<_BestSellerItem> _getBestSellers(List<OrderModel> orders) {
    final Map<String, _BestSellerItem> map = {};
    for (final o in orders) {
      for (final item in o.items) {
        if (map.containsKey(item.id)) {
          map[item.id] = _BestSellerItem(
            name: item.name,
            sold: map[item.id]!.sold + item.quantity,
            revenue: map[item.id]!.revenue + (item.price * item.quantity),
          );
        } else {
          map[item.id] = _BestSellerItem(
            name: item.name,
            sold: item.quantity,
            revenue: item.price * item.quantity,
          );
        }
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => b.sold.compareTo(a.sold));
    return list.take(5).toList();
  }

  List<_WeekDay> _getWeekData(List<OrderModel> orders) {
    final days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    final totals = List.filled(7, 0.0);
    for (final o in orders) {
      final dt = DateTime.tryParse(o.time);
      if (dt == null) continue;
      if (DateTime.now().difference(dt).inDays < 7) {
        totals[dt.weekday % 7] += o.totalAmount;
      }
    }
    return [
      _WeekDay(name: days[1], total: totals[1]),
      _WeekDay(name: days[2], total: totals[2]),
      _WeekDay(name: days[3], total: totals[3]),
      _WeekDay(name: days[4], total: totals[4]),
      _WeekDay(name: days[5], total: totals[5]),
      _WeekDay(name: days[6], total: totals[6]),
      _WeekDay(name: days[0], total: totals[0]),
    ];
  }

  String _formatShortCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return '${amount.toInt()}';
  }
}

// ─── Time Chip (pill style) ─────────────────────────
class _TimeChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _TimeChip(
      {required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppColors.slate800 : AppColors.slate500,
          ),
        ),
      ),
    );
  }
}

// ─── Date Range Picker ──────────────────────────────
class _DateRangePicker extends StatelessWidget {
  final DateTime dateFrom;
  final DateTime dateTo;
  final ValueChanged<DateTime> onFromChanged;
  final ValueChanged<DateTime> onToChanged;

  const _DateRangePicker({
    required this.dateFrom,
    required this.dateTo,
    required this.onFromChanged,
    required this.onToChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.date_range_rounded,
              size: 18, color: AppColors.emerald500),
          const SizedBox(width: 10),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: dateFrom,
                firstDate: DateTime(2020),
                lastDate: dateTo,
              );
              if (picked != null) onFromChanged(picked);
            },
            child: Text(
              '${dateFrom.day.toString().padLeft(2, '0')}/${dateFrom.month.toString().padLeft(2, '0')}/${dateFrom.year}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.slate700,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.arrow_forward_rounded,
                size: 16, color: AppColors.slate400),
          ),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: dateTo,
                firstDate: dateFrom,
                lastDate: DateTime.now(),
              );
              if (picked != null) onToChanged(picked);
            },
            child: Text(
              '${dateTo.day.toString().padLeft(2, '0')}/${dateTo.month.toString().padLeft(2, '0')}/${dateTo.year}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.slate700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Card (gradient icon) ──────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  final double width;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.slate100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.slate500,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Revenue Chart ──────────────────────────────────
class _RevenueChart extends StatelessWidget {
  final List<_WeekDay> weekData;
  const _RevenueChart({required this.weekData});

  @override
  Widget build(BuildContext context) {
    final maxVal =
        weekData.fold(0.0, (max, d) => d.total > max ? d.total : max);
    // Map weekday to our display index (Mon=0...Sun=6)
    final todayDisplayIdx =
        DateTime.now().weekday == 7 ? 6 : DateTime.now().weekday - 1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              const Icon(Icons.bar_chart_rounded,
                  size: 20, color: AppColors.emerald500),
              const SizedBox(width: 8),
              const Text(
                'Doanh thu 7 ngày gần nhất',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(weekData.length, (i) {
                final d = weekData[i];
                final fraction = maxVal > 0 ? d.total / maxVal : 0.0;
                final isToday = i == todayDisplayIdx;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d.total > 0)
                          Text(
                            d.total >= 1000000
                                ? '${(d.total / 1000000).toStringAsFixed(1)}M'
                                : d.total >= 1000
                                    ? '${(d.total / 1000).toStringAsFixed(0)}K'
                                    : '${d.total.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isToday
                                  ? AppColors.emerald600
                                  : AppColors.slate400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: (180 * fraction).clamp(4.0, 180.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isToday
                                  ? [
                                      AppColors.emerald400,
                                      AppColors.emerald600
                                    ]
                                  : [
                                      AppColors.slate200,
                                      AppColors.slate300
                                    ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                            boxShadow: isToday
                                ? [
                                    BoxShadow(
                                      color: AppColors.emerald500
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppColors.emerald50
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            d.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: isToday
                                  ? AppColors.emerald600
                                  : AppColors.slate500,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Best Sellers ───────────────────────────────────
class _BestSellersCard extends StatelessWidget {
  final List<_BestSellerItem> items;
  const _BestSellersCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              const Icon(Icons.local_fire_department_rounded,
                  size: 20, color: AppColors.orange500),
              const SizedBox(width: 8),
              const Text(
                'Bán Chạy Nhất',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.emoji_food_beverage_outlined,
                      size: 40, color: AppColors.slate300),
                  const SizedBox(height: 8),
                  const Text(
                    'Chưa có dữ liệu',
                    style: TextStyle(
                        color: AppColors.slate400,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          else ...[
            ...List.generate(items.length > 4 ? 4 : items.length, (i) {
              final item = items[i];
              final maxSold = items.first.sold;
              final fraction = maxSold > 0 ? item.sold / maxSold : 0.0;
              final barColors = [
                [const Color(0xFF10B981), const Color(0xFF059669)], // emerald
                [const Color(0xFF3B82F6), const Color(0xFF2563EB)], // blue
                [const Color(0xFFF59E0B), const Color(0xFFD97706)], // amber
                [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)], // violet
                [const Color(0xFFEC4899), const Color(0xFFDB2777)], // pink
              ];
              final colors = barColors[i % barColors.length];
              final unitLabel = item.name.toLowerCase().contains('trà') ||
                      item.name.toLowerCase().contains('cà phê') ||
                      item.name.toLowerCase().contains('nước')
                  ? 'ly'
                  : 'phần';
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: i < 3 ? AppColors.emerald600 : AppColors.slate500,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.slate800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${item.sold} $unitLabel',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatShortRevenue(item.revenue),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: colors[0],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 6,
                        backgroundColor: AppColors.slate100,
                        valueColor: AlwaysStoppedAnimation<Color>(colors[0]),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (items.length > 4)
              Center(
                child: TextButton.icon(
                  onPressed: () {},
                  icon: const Text('Xem thêm',
                      style: TextStyle(
                          color: AppColors.emerald600,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  label: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: AppColors.emerald600),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _formatShortRevenue(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return '${amount.toInt()}';
  }
}

class _BestSellerItem {
  final String name;
  final int sold;
  final double revenue;
  const _BestSellerItem(
      {required this.name, required this.sold, required this.revenue});
}

class _WeekDay {
  final String name;
  final double total;
  const _WeekDay({required this.name, required this.total});
}

// ─── Staff Ranking ──────────────────────────────────
class _StaffRankingCard extends StatelessWidget {
  final List<OrderModel> orders;
  const _StaffRankingCard({required this.orders});

  @override
  Widget build(BuildContext context) {
    // Aggregate staff data from orders
    final Map<String, int> staffOrders = {};
    for (final o in orders) {
      final name = o.createdBy.isEmpty ? 'Nhân viên' : o.createdBy;
      staffOrders[name] = (staffOrders[name] ?? 0) + 1;
    }
    final sorted = staffOrders.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topStaff = sorted.take(5).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              const Icon(Icons.emoji_events_rounded,
                  size: 20, color: AppColors.amber500),
              const SizedBox(width: 8),
              const Text(
                'Bảng Xếp Hạng NV',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (topStaff.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Chưa có dữ liệu',
                  style: TextStyle(
                    color: AppColors.slate400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            ...List.generate(topStaff.length, (i) {
              final entry = topStaff[i];
              final medals = ['🥇', '🥈', '🥉'];
              final colors = [
                const Color(0xFFFFFBEB),
                const Color(0xFFF0F9FF),
                const Color(0xFFFFF1F2),
              ];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: i < 3 ? colors[i] : AppColors.slate50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: i < 3
                          ? Text(medals[i],
                              style: const TextStyle(fontSize: 16))
                          : Text(
                              '#${i + 1}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.slate400,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.slate800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.blue50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.value} đơn',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.blue500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
