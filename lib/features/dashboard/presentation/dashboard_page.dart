import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';
import 'package:moimoi_pos/core/state/order_filter_store.dart';
import 'package:moimoi_pos/features/cashflow/logic/cashflow_store_standalone.dart';
import 'package:moimoi_pos/core/state/ui_store.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/utils/format.dart';
import 'package:moimoi_pos/features/pos_order/models/order_model.dart';
import 'package:moimoi_pos/core/widgets/date_range_picker_dialog.dart';
import 'package:moimoi_pos/features/cashflow/models/transaction_model.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _timeRange = 'range';
  DateTime _dateFrom = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  DateTime _dateTo = DateTime.now();

  bool _isLoadingReport = false;
  List<OrderModel> _historicalOrders = [];

  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _scrollToTopSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchHistoricalOrders();
      _scrollToTopSub = context.read<UIStore>().scrollToTopStream.listen((
        path,
      ) {
        if ((path == '/dashboard' || path == '/admin') && mounted) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollToTopSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistoricalOrders() async {
    final fromDate = DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    if (fromDate.isBefore(today)) {
      setState(() => _isLoadingReport = true);
      final store = context.read<OrderStore>();
      final hist = await store.fetchReportOrders(_dateFrom, _dateTo);
      if (mounted) {
        setState(() {
          _historicalOrders = hist;
          _isLoadingReport = false;
        });
      }
    } else {
      if (_historicalOrders.isNotEmpty) {
        setState(() => _historicalOrders = []);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderStore>(
      builder: (context, store, _) {
        final localOrders = context.watch<OrderFilterStore>().visibleOrders;
        final isLoading = store.isLoading || _isLoadingReport;

        // Combine local and historical orders (deduplicate by id)
        final allOrdersMap = <String, OrderModel>{};
        for (final o in localOrders) {
          allOrdersMap[o.id] = o;
        }
        for (final o in _historicalOrders) {
          allOrdersMap[o.id] = o;
        }
        final allOrders = allOrdersMap.values.toList();

        final completedPaidOrders = allOrders
            .where((o) => o.status == 'completed' && o.paymentStatus == 'paid')
            .toList();
        final filteredOrders = _filterByTime(completedPaidOrders);
        final cancelledOrders = _filterByTime(
          allOrders.where((o) => o.status == 'cancelled').toList(),
        );

        final totalRevenue = filteredOrders.fold(
          0.0,
          (acc, o) => acc + o.calculatedTotal,
        );
        final totalOrders = filteredOrders.length;
        final totalCancelled = cancelledOrders.length;
        final cashRevenue = filteredOrders
            .where((o) => o.paymentMethod == 'cash')
            .fold(0.0, (acc, o) => acc + o.calculatedTotal);
        final transferRevenue = filteredOrders
            .where((o) => o.paymentMethod == 'transfer')
            .fold(0.0, (acc, o) => acc + o.calculatedTotal);
        final bestSellers = _getBestSellers(filteredOrders);
        final hourlyData = _getHourlyData(filteredOrders);

        final mainContent = Container(
          color: AppColors.scaffoldBg,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 9, right: 9, top: 24, bottom: 20),
                child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.emerald50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.trending_up_rounded,
                            color: AppColors.emerald600,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Báo Cáo Doanh Thu',
                                style: TextStyle(
                                  fontSize: 20,
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
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(9, 0, 9, 24),
                      child: LayoutBuilder(
                        builder: (context, outerConstraints) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDatePicker(),

                    SizedBox(height: 20),

                    // ── Stats Cards (responsive) ──
                    Builder(
                      builder: (context) {
                        final isLandscape = outerConstraints.maxWidth > 600;

                        final cashCard = _MobileMiniCard(
                          icon: Icons.payments_rounded,
                          label: 'Tiền mặt',
                          value: formatCurrency(cashRevenue),
                          gradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        );
                        final transferCard = _MobileMiniCard(
                          icon: Icons.account_balance_rounded,
                          label: 'Chuyển khoản',
                          value: formatCurrency(transferRevenue),
                          gradient: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                        );
                        final ordersCard = _MobileMiniCard(
                          icon: Icons.receipt_long_rounded,
                          label: 'Tổng đơn',
                          value: '$totalOrders',
                          gradient: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          subtitle: totalCancelled > 0
                              ? 'Đơn hủy: $totalCancelled'
                              : null,
                          subtitleColor: const Color(0xFFEF4444),
                        );
                        final avgCard = _MobileMiniCard(
                          icon: Icons.analytics_rounded,
                          label: 'TB/đơn',
                          value: totalOrders > 0
                              ? _formatShortCurrency(totalRevenue / totalOrders)
                              : '0',
                          gradient: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                        );

                        if (isLandscape) {
                          // Landscape: all 5 cards in one row
                          return Row(
                            children: [
                              Expanded(
                                child: _MobileMiniCard(
                                  icon: Icons.trending_up_rounded,
                                  label: 'Tổng doanh thu',
                                  value: formatCurrency(totalRevenue),
                                  gradient: [
                                    Color(0xFF10B981),
                                    Color(0xFF059669),
                                  ],
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(child: cashCard),
                              SizedBox(width: 10),
                              Expanded(child: transferCard),
                              SizedBox(width: 10),
                              Expanded(child: ordersCard),
                              SizedBox(width: 10),
                              Expanded(child: avgCard),
                            ],
                          );
                        }

                        // Portrait: revenue banner + 2×2 grid
                        return Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF059669),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.cardBg.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.trending_up_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tổng doanh thu',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withValues(
                                              alpha: 0.85,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          formatCurrency(totalRevenue),
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      cashCard,
                                      SizedBox(height: 12),
                                      ordersCard,
                                    ],
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    children: [
                                      transferCard,
                                      SizedBox(height: 12),
                                      avgCard,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    SizedBox(height: 24),

                    // ── Charts (responsive) ──────────────────────
                    Builder(
                      builder: (context) {
                        final isLandscape = outerConstraints.maxWidth > 600;

                        if (isLandscape) {
                          return Column(
                            children: [
                              // Row 1: Hourly (left) + Daily (right)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _HourlyRevenueChart(
                                      hourlyData: hourlyData,
                                    ),
                                  ),
                                  SizedBox(width: 14),
                                  Expanded(
                                    child: _CashFlowChart(
                                      orders: filteredOrders,
                                      transactions: context.watch<CashflowStore>().transactions,
                                      dateFrom: _dateFrom,
                                      dateTo: _dateTo,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 14),
                              // Row 2: Best sellers + Staff ranking
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _BestSellersCard(items: bestSellers),
                                  ),
                                  SizedBox(width: 14),
                                  Expanded(
                                    child: _StaffRankingCard(
                                      orders: filteredOrders,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }

                        // Portrait: stacked vertical
                        return Column(
                          children: [
                            _HourlyRevenueChart(hourlyData: hourlyData),
                            SizedBox(height: 14),
                            _CashFlowChart(
                              orders: filteredOrders,
                              transactions: context.watch<CashflowStore>().transactions,
                              dateFrom: _dateFrom,
                              dateTo: _dateTo,
                            ),
                            SizedBox(height: 14),
                            _BestSellersCard(items: bestSellers),
                            SizedBox(height: 14),
                            _StaffRankingCard(orders: filteredOrders),
                          ],
                        );
                      },
                    ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
        );

        return Skeletonizer(enabled: isLoading, child: mainContent);
      },
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showCompactDateRangePicker(
          context: context,
          initialStart: _dateFrom,
          initialEnd: _dateTo,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            _dateFrom = picked.start;
            _dateTo = picked.end;
            _timeRange = 'range';
          });
          _fetchHistoricalOrders();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(width: 16), // Balance the right icon
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: AppColors.emerald600,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${_dateFrom.day.toString().padLeft(2, '0')}/${_dateFrom.month.toString().padLeft(2, '0')}/${_dateFrom.year}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.slate800,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.slate400,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${_dateTo.day.toString().padLeft(2, '0')}/${_dateTo.month.toString().padLeft(2, '0')}/${_dateTo.year}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.slate800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.slate400,
            ),
          ],
        ),
      ),
    );
  }

  List<OrderModel> _filterByTime(List<OrderModel> orders) {
    return orders.where((o) {
      final parsed = DateTime.tryParse(o.time);
      if (parsed == null) return false;
      // Reconstruct as local — timestamps stored as local values
      // but Supabase may return with +00:00 suffix
      final dt = DateTime(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
      );
      final from = DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
      final to = DateTime(_dateTo.year, _dateTo.month, _dateTo.day, 23, 59, 59);
      return dt.isAfter(from.subtract(const Duration(seconds: 1))) &&
          dt.isBefore(to.add(const Duration(seconds: 1)));
    }).toList();
  }

  List<_BestSellerItem> _getBestSellers(List<OrderModel> orders) {
    final Map<String, _BestSellerItem> map = {};
    for (final o in orders) {
      for (final item in o.items) {
        if (map.containsKey(item.id)) {
          final existing = map[item.id]!;
          map[item.id] = _BestSellerItem(
            name: item.name,
            sold: existing.sold + item.quantity,
            revenue: existing.revenue + (item.price * item.quantity),
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
    return list;
  }

  List<_HourSlot> _getHourlyData(List<OrderModel> orders) {
    // Group revenue by 2-hour time slots
    final slots = <_HourSlot>[
      _HourSlot(label: '6-8', total: 0),
      _HourSlot(label: '8-10', total: 0),
      _HourSlot(label: '10-12', total: 0),
      _HourSlot(label: '12-14', total: 0),
      _HourSlot(label: '14-16', total: 0),
      _HourSlot(label: '16-18', total: 0),
      _HourSlot(label: '18-20', total: 0),
      _HourSlot(label: '20-22', total: 0),
      _HourSlot(label: '22-0', total: 0),
    ];
    for (final o in orders) {
      final dt = DateTime.tryParse(o.time);
      if (dt == null) continue;
      final h = dt.hour;
      int idx;
      if (h < 6) {
        continue; // skip very early hours
      } else if (h < 8) {
        idx = 0;
      } else if (h < 10) {
        idx = 1;
      } else if (h < 12) {
        idx = 2;
      } else if (h < 14) {
        idx = 3;
      } else if (h < 16) {
        idx = 4;
      } else if (h < 18) {
        idx = 5;
      } else if (h < 20) {
        idx = 6;
      } else if (h < 22) {
        idx = 7;
      } else {
        idx = 8;
      }
      slots[idx] = _HourSlot(
        label: slots[idx].label,
        total: slots[idx].total + o.calculatedTotal,
      );
    }
    return slots;
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
  const _TimeChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.cardBg : Colors.transparent,
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
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.date_range_rounded, size: 18, color: AppColors.emerald500),
          SizedBox(width: 10),
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
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.slate700,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: AppColors.slate400,
            ),
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
              style: TextStyle(
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
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
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
                color: AppColors.tintedBg(gradient[0]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: gradient[0], size: 26),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppColors.slate500,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
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

// ─── Hourly Revenue Chart ────────────────────────────
class _HourlyRevenueChart extends StatelessWidget {
  final List<_HourSlot> hourlyData;
  const _HourlyRevenueChart({required this.hourlyData});

  @override
  Widget build(BuildContext context) {
    final maxVal = hourlyData.fold(
      0.0,
      (max, d) => d.total > max ? d.total : max,
    );
    // Find peak hour slot
    int peakIdx = 0;
    for (int i = 1; i < hourlyData.length; i++) {
      if (hourlyData[i].total > hourlyData[peakIdx].total) peakIdx = i;
    }

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
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
              Icon(
                Icons.schedule_rounded,
                size: 20,
                color: AppColors.emerald500,
              ),
              SizedBox(width: 8),
              Text(
                'Doanh thu theo khung giờ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                ),
              ),
            ],
          ),
          SizedBox(height: 28),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(hourlyData.length, (i) {
                final d = hourlyData[i];
                final fraction = maxVal > 0 ? d.total / maxVal : 0.0;
                final isPeak = i == peakIdx && d.total > 0;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d.total > 0)
                          Text(
                            d.total >= 1000000
                                ? '${(d.total / 1000000).toStringAsFixed(1)}M'
                                : d.total >= 1000
                                ? '${(d.total / 1000).toStringAsFixed(0)}K'
                                : d.total.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 9,
                              color: isPeak
                                  ? AppColors.emerald600
                                  : AppColors.slate400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: (130 * fraction).clamp(4.0, 130.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isPeak
                                  ? [AppColors.emerald400, AppColors.emerald600]
                                  : fraction > 0
                                  ? [
                                      const Color(0xFF93C5FD),
                                      const Color(0xFF3B82F6),
                                    ]
                                  : [AppColors.slate200, AppColors.slate300],
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                            boxShadow: isPeak
                                ? [
                                    BoxShadow(
                                      color: AppColors.emerald500.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        SizedBox(height: 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isPeak
                                ? AppColors.emerald50
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            d.label,
                            style: TextStyle(
                              fontSize: 10,
                              color: isPeak
                                  ? AppColors.emerald600
                                  : AppColors.slate500,
                              fontWeight: isPeak
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
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
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
              Icon(
                Icons.local_fire_department_rounded,
                size: 20,
                color: AppColors.orange500,
              ),
              SizedBox(width: 8),
              Text(
                'Món bán chạy',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          if (items.isEmpty)
            Container(
              padding: EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_food_beverage_outlined,
                    size: 40,
                    color: AppColors.slate300,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Chưa có dữ liệu',
                    style: TextStyle(
                      color: AppColors.slate400,
                      fontWeight: FontWeight.w500,
                    ),
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
              final unitLabel =
                  item.name.toLowerCase().contains('trà') ||
                      item.name.toLowerCase().contains('cà phê') ||
                      item.name.toLowerCase().contains('nước')
                  ? 'ly'
                  : 'phần';
              return Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: i < 3
                                ? AppColors.emerald600
                                : AppColors.slate500,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.slate800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${item.sold} $unitLabel',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.slate500,
                          ),
                        ),
                        SizedBox(width: 8),
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
                    SizedBox(height: 6),
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
                  onPressed: () => _showAllBestSellersDialog(context, items),
                  icon: Text(
                    'Xem thêm',
                    style: TextStyle(
                      color: AppColors.emerald600,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  label: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.emerald600,
                  ),
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

  static void _showAllBestSellersDialog(
    BuildContext context,
    List<_BestSellerItem> items,
  ) {
    final barColors = [
      [const Color(0xFF10B981), const Color(0xFF059669)],
      [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
      [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
      [const Color(0xFFEC4899), const Color(0xFFDB2777)],
    ];
    final maxSold = items.isNotEmpty ? items.first.sold : 1;

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 480,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(24, 20, 12, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 22,
                      color: Color(0xFFF59E0B),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xếp hạng sản phẩm bán chạy',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tổng ${items.length} sản phẩm',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.slate400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.of(dialogCtx, rootNavigator: true).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              const Divider(height: 1),
              // List
              Flexible(
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => SizedBox(height: 14),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final fraction = maxSold > 0 ? item.sold / maxSold : 0.0;
                    final colors = barColors[i % barColors.length];
                    return Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: i < 3
                                    ? colors[0].withValues(alpha: 0.12)
                                    : AppColors.slate50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: i < 3 ? colors[0] : AppColors.slate500,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.slate800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${item.sold} phần',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.slate500,
                              ),
                            ),
                            SizedBox(width: 8),
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
                        SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 5,
                            backgroundColor: AppColors.slate100,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colors[0],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BestSellerItem {
  final String name;
  final int sold;
  final double revenue;
  const _BestSellerItem({
    required this.name,
    required this.sold,
    required this.revenue,
  });
}

class _HourSlot {
  final String label;
  final double total;
  const _HourSlot({required this.label, required this.total});
}

class _DailySlot {
  final String label;
  final double total;
  const _DailySlot({required this.label, required this.total});
}

// ─── Mini Stat Card ─────────────────────────────────
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mobile Mini Card (for 2x2 grid) ───────────────
class _MobileMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradient;
  final String? subtitle;
  final Color? subtitleColor;
  const _MobileMiniCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
    this.subtitle,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = gradient[0];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              // Tinted Background: accent color at 15% opacity
              color: AppColors.tintedBg(accentColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.slate500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.slate800,
              letterSpacing: -0.5,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: subtitleColor ?? AppColors.slate400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Daily Revenue Chart (7 days) ───────────────────
// ─── Cash Flow Chart (Timeline) ───────────────────
class _CashFlowChart extends StatelessWidget {
  final List<OrderModel> orders;
  final List<Transaction> transactions;
  final DateTime dateFrom;
  final DateTime dateTo;

  const _CashFlowChart({
    required this.orders,
    required this.transactions,
    required this.dateFrom,
    required this.dateTo,
  });

  DateTime? _parseLocal(String timeStr) {
    var s = timeStr;
    if (s.endsWith('Z')) s = s.substring(0, s.length - 1);
    final plussIdx = s.indexOf('+');
    if (plussIdx != -1) s = s.substring(0, plussIdx);
    return DateTime.tryParse(s);
  }

  @override
  Widget build(BuildContext context) {
    final totalDays = dateTo.difference(dateFrom).inDays;
    final groupByMonth = totalDays >= 31;

    final Map<String, Map<String, double>> groupedData = {};

    // Seed ordered map
    if (groupByMonth) {
      DateTime current = DateTime(dateFrom.year, dateFrom.month);
      while (current.isBefore(dateTo) ||
          (current.year == dateTo.year && current.month == dateTo.month)) {
        final key =
            '${current.month.toString().padLeft(2, '0')}/${current.year}';
        groupedData[key] = {'thu': 0.0, 'chi': 0.0};
        current = DateTime(current.year, current.month + 1);
      }
    } else {
      DateTime current = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
      while (current.isBefore(dateTo) ||
          current.isAtSameMomentAs(
            DateTime(dateTo.year, dateTo.month, dateTo.day),
          )) {
        final key =
            '${current.day.toString().padLeft(2, '0')}/${current.month.toString().padLeft(2, '0')}';
        groupedData[key] = {'thu': 0.0, 'chi': 0.0};
        current = current.add(const Duration(days: 1));
      }
    }

    // Process Orders (Thu)
    for (final order in orders) {
      if (order.paymentStatus != 'paid' || order.status == 'cancelled') {
        continue;
      }
      final dt = _parseLocal(order.time);
      if (dt == null) continue;
      final key = groupByMonth
          ? '${dt.month.toString().padLeft(2, '0')}/${dt.year}'
          : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
      if (groupedData.containsKey(key)) {
        groupedData[key]!['thu'] =
            groupedData[key]!['thu']! + order.totalAmount;
      }
    }

    // Process Transactions (Thu/Chi)
    for (final txn in transactions) {
      final dt = _parseLocal(txn.time);
      if (dt == null) continue;
      if (dt.isBefore(dateFrom.subtract(const Duration(days: 1))) ||
          dt.isAfter(dateTo.add(const Duration(days: 1)))) {
        continue;
      }

      final key = groupByMonth
          ? '${dt.month.toString().padLeft(2, '0')}/${dt.year}'
          : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
      if (groupedData.containsKey(key)) {
        if (txn.type == 'thu') {
          groupedData[key]!['thu'] = groupedData[key]!['thu']! + txn.amount;
        } else {
          groupedData[key]!['chi'] = groupedData[key]!['chi']! + txn.amount;
        }
      }
    }

    final keys = groupedData.keys.toList();
    if (keys.isEmpty) return SizedBox.shrink();

    double maxVal = 0;
    for (final vals in groupedData.values) {
      if (vals['thu']! > maxVal) maxVal = vals['thu']!;
      if (vals['chi']! > maxVal) maxVal = vals['chi']!;
    }
    if (maxVal == 0) maxVal = 10000;

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];
      final thu = groupedData[key]!['thu']!;
      final chi = groupedData[key]!['chi']!;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: thu,
              color: AppColors.emerald500,
              width: 10,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: chi,
              color: AppColors.red500,
              width: 10,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 20,
                    color: AppColors.emerald500,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Mức lưu chuyển tiền',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate800,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.emerald500,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Thu',
                    style: TextStyle(fontSize: 11, color: AppColors.slate500),
                  ),
                  SizedBox(width: 12),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.red500,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Chi',
                    style: TextStyle(fontSize: 11, color: AppColors.slate500),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxVal * 1.15,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.slate800,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final isThu = rodIndex == 0;
                      return BarTooltipItem(
                        '${isThu ? 'Thu' : 'Chi'}: ${_formatShortRevenue(rod.toY)}\n${keys[groupIndex]}',
                        TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= keys.length) {
                          return SizedBox.shrink();
                        }
                        String text = keys[index];
                        if (keys.length > 7) {
                          if (index % (keys.length ~/ 5) != 0 &&
                              index != keys.length - 1) {
                            return SizedBox.shrink();
                          }
                        }
                        return Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            text,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.slate500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return SizedBox.shrink();
                        return Padding(
                          padding: EdgeInsets.only(right: 6.0),
                          child: Text(
                            _formatShortRevenue(value),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.slate500,
                            ),
                          ),
                        );
                      },
                      reservedSize: 36,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: AppColors.slate100, strokeWidth: 1),
                ),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatShortRevenue(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}tr';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return '${amount.toInt()}';
  }
}

// ─── Staff Ranking ──────────────────────────────────
class _StaffRankingCard extends StatelessWidget {
  final List<OrderModel> orders;
  const _StaffRankingCard({required this.orders});

  @override
  Widget build(BuildContext context) {
    // Aggregate staff data from orders
    final Map<String, int> staffOrders = {};
    final Map<String, double> staffRevenue = {};
    for (final o in orders) {
      final name = o.createdBy.isEmpty ? 'Nhân viên' : o.createdBy;
      staffOrders[name] = (staffOrders[name] ?? 0) + 1;
      staffRevenue[name] = (staffRevenue[name] ?? 0) + o.calculatedTotal;
    }
    final sorted = staffOrders.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topStaff = sorted.take(5).toList();

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
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
              Icon(
                Icons.military_tech_rounded,
                size: 20,
                color: Color(0xFF8B5CF6),
              ),
              SizedBox(width: 8),
              Text(
                'BXH Nhân sự',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (topStaff.isEmpty)
            Padding(
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
              final revenue = staffRevenue[entry.key] ?? 0;
              final rankBgColors = [
                AppColors.amber100, // gold
                const Color(0xFFF1F5F9), // slate
                const Color(0xFFF1F5F9), // slate
              ];
              final avatarBgColors = [
                AppColors.emerald100,
                const Color(0xFFE0E7FF), // indigo-100
                const Color(0xFFFCE7F3), // pink-100
              ];
              final rankColor = i == 0
                  ? const Color(0xFFD97706)
                  : AppColors.slate500;
              final initial = entry.key.isNotEmpty
                  ? entry.key[0].toUpperCase()
                  : '?';
              final isLast = i == topStaff.length - 1;
              return Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(bottom: BorderSide(color: AppColors.slate100)),
                ),
                child: Row(
                  children: [
                    // Rank badge
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: i < 3 ? rankBgColors[i] : AppColors.slate50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: rankColor,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Avatar
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: i < 3 ? avatarBgColors[i] : AppColors.slate100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: i == 0
                              ? AppColors.emerald600
                              : i == 1
                              ? const Color(0xFF4F46E5)
                              : i == 2
                              ? const Color(0xFFDB2777)
                              : AppColors.slate500,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Name
                    Expanded(
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.slate800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Revenue + Orders count
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatShortRevenue(revenue),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${entry.value} đơn',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
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
    return '${amount.toInt()}đ';
  }
}
