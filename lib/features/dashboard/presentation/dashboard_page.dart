import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';
import 'package:moimoi_pos/core/state/order_filter_store.dart';

import 'package:moimoi_pos/core/state/ui_store.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/utils/format.dart';
import 'package:moimoi_pos/features/pos_order/models/order_model.dart';
import 'package:moimoi_pos/core/widgets/date_range_picker_dialog.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:moimoi_pos/features/notifications/presentation/notification_bell.dart';

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
        final topStaff = _getTopStaff(filteredOrders);
        final hourlyData = _getHourlyData(filteredOrders);

        // Build daily sparkline array for background charts
        
        List<double> totalSpots = hourlyData.map((e) => e.total).toList();
        List<double> cashSpots = hourlyData.map((e) => e.cash).toList();
        List<double> transferSpots = hourlyData.map((e) => e.transfer).toList();
    
        final mainContent = Container(
          color: AppColors.scaffoldBg, // light sleek background -> adapts
          child: Column(
            children: [
              // Sleek App Bar Header
              Container(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                color: AppColors.cardBg,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Báo Cáo Doanh Thu',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tổng quan dòng tiền',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.slate500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    _buildDatePicker(),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchHistoricalOrders,
                  color: AppColors.emerald500,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                  child: LayoutBuilder(
                    builder: (context, outerConstraints) {
                      final isLandscape = outerConstraints.maxWidth > 600;

                      // 1. Tổng Doanh Thu - full width
                      final totalCard = _SparklineCard(
                        title: 'TỔNG DOANH THU',
                        value: formatCurrency(totalRevenue),
                        accentColor: AppColors.emerald500,
                        spots: totalSpots,
                        isGradientValue: true,
                      );

                      // 1b. Tiền Mặt + Chuyển Khoản row
                      final subCards = Row(
                        children: [
                          Expanded(
                            child: _SparklineCard(
                              title: 'TIỀN MẶT',
                              value: formatCurrency(cashRevenue),
                              accentColor: AppColors.amber500,
                              spots: cashSpots,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _SparklineCard(
                              title: 'CHUYỂN KHOẢN',
                              value: formatCurrency(transferRevenue),
                              accentColor: AppColors.blue500,
                              spots: transferSpots,
                            ),
                          ),
                        ],
                      );

                      // 2. Extra metrics (Orders, Avg, Cancelled)
                      final extraMetrics = Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.slate200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(8)),
                                    child: Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.blue500),
                                  ),
                                  SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Tổng đơn', style: TextStyle(fontSize: 10, color: AppColors.slate500)),
                                      Text('$totalOrders', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slate800)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 30, color: AppColors.slate200),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: AppColors.violet50, borderRadius: BorderRadius.circular(8)),
                                    child: Icon(Icons.analytics_rounded, size: 16, color: AppColors.violet500),
                                  ),
                                  SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('TB/đơn', style: TextStyle(fontSize: 10, color: AppColors.slate500)),
                                      Text(totalOrders > 0 ? _formatShortCurrency(totalRevenue / totalOrders) : '0', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slate800)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 30, color: AppColors.slate200),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: AppColors.red50, borderRadius: BorderRadius.circular(8)),
                                    child: Icon(Icons.cancel_rounded, size: 16, color: AppColors.red500),
                                  ),
                                  SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Đơn huỷ', style: TextStyle(fontSize: 10, color: AppColors.slate500)),
                                      Text('$totalCancelled', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: totalCancelled > 0 ? AppColors.red500 : AppColors.slate800)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );

                      if (isLandscape) {
                        // ── TABLET / PC LAYOUT ──
                        // Row 1: All 3 revenue cards in one row + metrics
                        // Row 2: Hourly chart full-width
                        // Row 3: Products + Staff side by side
                        final allCardsRow = Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _SparklineCard(
                                title: 'TỔNG DOANH THU',
                                value: formatCurrency(totalRevenue),
                                accentColor: AppColors.emerald500,
                                spots: totalSpots,
                                isGradientValue: true,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _SparklineCard(
                                title: 'TIỀN MẶT',
                                value: formatCurrency(cashRevenue),
                                accentColor: AppColors.amber500,
                                spots: cashSpots,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _SparklineCard(
                                title: 'CHUYỂN KHOẢN',
                                value: formatCurrency(transferRevenue),
                                accentColor: AppColors.blue500,
                                spots: transferSpots,
                              ),
                            ),
                          ],
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            allCardsRow,
                            SizedBox(height: 12),
                            extraMetrics,
                            SizedBox(height: 16),
                            // Chart + panels in 2-column layout
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _HourlyRevenueStackedChart(hourlyData: hourlyData),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    children: [
                                      _TopProductsPanel(items: bestSellers),
                                      SizedBox(height: 12),
                                      _TopStaffPanel(staff: topStaff),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      // ── MOBILE / PORTRAIT LAYOUT ──
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          totalCard,
                          SizedBox(height: 8),
                          subCards,
                          SizedBox(height: 12),
                          extraMetrics,
                          SizedBox(height: 16),
                          _HourlyRevenueStackedChart(hourlyData: hourlyData),
                          SizedBox(height: 16),
                          _TopProductsPanel(items: bestSellers),
                          SizedBox(height: 16),
                          _TopStaffPanel(staff: topStaff),
                        ],
                      );
                    },
                  ),
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
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.emerald600),
            SizedBox(width: 8),
            Text(
              '${_dateFrom.day}/${_dateFrom.month} - ${_dateTo.day}/${_dateTo.month}/${_dateTo.year}',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.slate700),
            ),
            SizedBox(width: 8),
            Icon(Icons.unfold_more_rounded, size: 18, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }

  Widget _buildSlimStatItem(String label, String value, Color accent) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 13, color: AppColors.slate800, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatItem(IconData icon, String label, String value, Color accent, {String? subtitle, Color? subtitleColor}) {

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate800),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subtitleColor ?? AppColors.slate400),
            ),
          ]
        ],
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

  List<_StaffRankItem> _getTopStaff(List<OrderModel> orders) {
    final map = <String, _StaffRankItem>{};
    for (final o in orders) {
      final staff = (o.createdBy.isNotEmpty) ? o.createdBy : 'Admin';
      if (map.containsKey(staff)) {
        final existing = map[staff]!;
        map[staff] = _StaffRankItem(name: existing.name, revenue: existing.revenue + o.calculatedTotal, count: existing.count + 1);
      } else {
        map[staff] = _StaffRankItem(name: staff, revenue: o.calculatedTotal, count: 1);
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => b.revenue.compareTo(a.revenue));
    return list;
  }

  List<_HourSlot> _getHourlyData(List<OrderModel> orders) {
    var slots = [
      _HourSlot(label: '6-8', total: 0, cash: 0, transfer: 0),
      _HourSlot(label: '8-10', total: 0, cash: 0, transfer: 0),
      _HourSlot(label: '10-12', total: 0, cash: 0, transfer: 0),
      _HourSlot(label: '12-14', total: 0, cash: 0, transfer: 0),
      _HourSlot(label: '14-16', total: 0, cash: 0, transfer: 0),
      _HourSlot(label: '16-18', total: 0, cash: 0, transfer: 0),
      _HourSlot(label: '18-20', total: 0, cash: 0, transfer: 0),
      _HourSlot(label: '20-22', total: 0, cash: 0, transfer: 0),
      _HourSlot(label: '22-0', total: 0, cash: 0, transfer: 0),
    ];
    for (final o in orders) {
      final dt = DateTime.tryParse(o.time);
      if (dt == null) continue;
      final h = dt.hour;
      int idx;
      if (h < 6) continue;
      else if (h < 8) idx = 0;
      else if (h < 10) idx = 1;
      else if (h < 12) idx = 2;
      else if (h < 14) idx = 3;
      else if (h < 16) idx = 4;
      else if (h < 18) idx = 5;
      else if (h < 20) idx = 6;
      else if (h < 22) idx = 7;
      else idx = 8;
      
      double c = o.paymentMethod == 'cash' ? o.calculatedTotal : 0;
      double t = o.paymentMethod == 'transfer' ? o.calculatedTotal : 0;
      
      slots[idx] = _HourSlot(
        label: slots[idx].label,
        total: slots[idx].total + o.calculatedTotal,
        cash: slots[idx].cash + c,
        transfer: slots[idx].transfer + t,
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
class _SparklineCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accentColor;
  final List<double> spots;
  final bool isGradientValue;

  const _SparklineCard({
    required this.title,
    required this.value,
    required this.accentColor,
    required this.spots,
    this.isGradientValue = false,
  });

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) spots.add(0);
    double maxVal = spots.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 1;

    List<FlSpot> flSpots = [];
    for (int i = 0; i < spots.length; i++) {
      flSpots.add(FlSpot(i.toDouble(), spots[i]));
    }

    return Container(
      height: 94,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        gradient: LinearGradient(
          colors: [AppColors.cardBg, accentColor.withValues(alpha: AppColors.isDarkMode ? 0.05 : 0.15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          // Background soft line chart
          Positioned(
            bottom: -2,
            left: 0,
            right: 0,
            height: 50,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (spots.length - 1).toDouble() > 0 ? (spots.length - 1).toDouble() : 1,
                minY: 0,
                maxY: maxVal * 1.5,
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: flSpots,
                    isCurved: true,
                    color: accentColor.withValues(alpha: 0.6),
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.3),
                          accentColor.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Foreground Text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Icon(Icons.analytics_rounded, size: 10, color: accentColor),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate700,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                isGradientValue
                    ? ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: AppColors.isDarkMode 
                              ? [AppColors.emerald400, AppColors.emerald200]
                              : [Color(0xFF0D9488), Color(0xFF10B981)],
                        ).createShader(bounds),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slate800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HourlyRevenueStackedChart extends StatelessWidget {
  final List<_HourSlot> hourlyData;
  const _HourlyRevenueStackedChart({required this.hourlyData});

  @override
  Widget build(BuildContext context) {
    double maxVal = 0;
    for (final d in hourlyData) {
      if (d.total > maxVal) maxVal = d.total;
    }

    if (maxVal == 0) maxVal = 1000;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Doanh thu theo khung giờ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                  letterSpacing: -0.2,
                ),
              ),
              Row(
                children: [
                  _buildLegendItem(Color(0xFFF59E0B), 'Tiền mặt'),
                  SizedBox(width: 12),
                  _buildLegendItem(Color(0xFF6366F1), 'Chuyển khoản'),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceEvenly,
                maxY: maxVal,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.slate800,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final h = hourlyData[group.x];
                      return BarTooltipItem(
                        '${h.label}\nTiền mặt: ${_HourlyRevenueStackedChart._formatShortRevenue(h.cash)}\nCK: ${_HourlyRevenueStackedChart._formatShortRevenue(h.transfer)}',
                        TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int idx = value.toInt();
                        if (idx >= 0 && idx < hourlyData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              hourlyData[idx].label,
                              style: TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.w600),
                            ),
                          );
                        }
                        return SizedBox.shrink();
                      },
                      reservedSize: 24,
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(color: AppColors.slate100, strokeWidth: 1, dashArray: [4, 4]),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(hourlyData.length, (i) {
                  final d = hourlyData[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: d.cash,
                        width: 7,
                        color: Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      BarChartRodData(
                        toY: d.transfer,
                        width: 7,
                        color: Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w500)),
      ],
    );
  }

  static String _formatShortRevenue(double amount) {
    if (amount == 0) return '0';
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return '${amount.toInt()}';
  }
}


// ─── Best Sellers ───────────────────────────────────
class _BestSellersCard extends StatelessWidget {
  final List<_BestSellerItem> items;
  const _BestSellersCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sản phẩm bán chạy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate700)),
              if (items.length > 5)
                InkWell(
                  onTap: () => _showAllBestSellersDialog(context, items),
                  child: Text('Xem tất cả', style: TextStyle(fontSize: 11, color: AppColors.primary600, fontWeight: FontWeight.w500)),
                ),
            ],
          ),
          SizedBox(height: 12),
          if (items.isEmpty)
            Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Chưa có dữ liệu', style: TextStyle(fontSize: 11, color: AppColors.slate400))))
          else
            ...List.generate(items.length > 5 ? 5 : items.length, (i) {
              final item = items[i];
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 16, child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: AppColors.slate400, fontWeight: FontWeight.w600))),
                    Expanded(
                      child: Text(item.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate800), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text('${item.sold}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate600)),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 45,
                      child: Text(_formatShortRevenue(item.revenue), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary600)),
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
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return '${amount.toInt()}';
  }

  static void _showAllBestSellersDialog(BuildContext context, List<_BestSellerItem> items) {
       // Placeholder for dialog to keep it compact
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

class _StaffRankItem {
  final String name;
  final double revenue;
  final int count;
  _StaffRankItem({required this.name, required this.revenue, required this.count});
}


class _HourSlot {
  final String label;
  final double total;
  final double cash;
  final double transfer;
  const _HourSlot({required this.label, required this.total, required this.cash, required this.transfer});
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
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate100.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.15),
                      accentColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.slate500,
            ),
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.slate800,
              letterSpacing: -0.5,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (subtitleColor ?? AppColors.slate400).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: subtitleColor ?? AppColors.slate400,
                ),
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

class _TopProductsPanel extends StatelessWidget {
  final List<_BestSellerItem> items;
  const _TopProductsPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    int maxSold = items.isEmpty ? 1 : items.map((e) => e.sold).reduce((a, b) => a > b ? a : b);
    if (maxSold == 0) maxSold = 1;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [BoxShadow(color: AppColors.primary500.withValues(alpha: 0.03), blurRadius: 15, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.star_rounded, color: AppColors.primary600, size: 18),
              ),
              SizedBox(width: 10),
              Text('Sản phẩm nổi bật', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate800, letterSpacing: -0.3)),
              Spacer(),
              if (items.length > 5)
                InkWell(
                  onTap: () => showDialog(context: context, builder: (_) => _AllProductsDialog(items: items, maxSold: maxSold)),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('Xem thêm', style: TextStyle(color: AppColors.primary600, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          SizedBox(height: 20),
          if (items.isEmpty)
             Center(child: Padding(
               padding: const EdgeInsets.symmetric(vertical: 20),
               child: Text('Chưa có dữ liệu', style: TextStyle(color: AppColors.slate400, fontSize: 13, fontWeight: FontWeight.w600)),
             )),
          for (int i = 0; i < items.length && i < 5; i++)
            _buildItem(items[i], i, maxSold),
        ],
      ),
    );
  }

  Widget _buildItem(_BestSellerItem item, int index, int maxSold) {
    double factor = item.sold / maxSold;
    if (factor > 1.0) factor = 1.0;
    if (factor < 0.02) factor = 0.02;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          return Stack(
            children: [
              // Background subtle bar
              Container(
                height: 56,
                width: barWidth,
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Container(
                height: 56,
                width: barWidth * factor,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary500.withValues(alpha: 0.15),
                      AppColors.primary500.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // Foreground content
              Container(
                height: 56,
                width: barWidth,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 30, height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index == 0 ? Color(0xFFF59E0B) : index == 1 ? Color(0xFF94A3B8) : index == 2 ? Color(0xFFD97706) : AppColors.cardBg, 
                        shape: BoxShape.circle, 
                        border: index > 2 ? Border.all(color: AppColors.slate200) : null,
                        boxShadow: index < 3 ? [BoxShadow(color: (index == 0 ? Color(0xFFF59E0B) : index == 1 ? Color(0xFF94A3B8) : Color(0xFFD97706)).withValues(alpha: 0.3), blurRadius: 4, offset: Offset(0, 2))] : null
                      ),
                      child: Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: index < 3 ? Colors.white : AppColors.slate500)),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800), maxLines: 1, overflow: TextOverflow.ellipsis),
                          SizedBox(height: 2),
                          Row(
                             children: [
                                Icon(Icons.shopping_bag_rounded, size: 12, color: Color(0xFF059669)),
                                SizedBox(width: 4),
                                Text('${item.sold} lượt bán', style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w700)),
                             ]
                          )
                        ],
                      )
                    ),
                    Text(formatCurrency(item.revenue), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.slate800, letterSpacing: -0.5)),
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }
}

class _TopStaffPanel extends StatelessWidget {
  final List<_StaffRankItem> staff;
  const _TopStaffPanel({required this.staff});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [BoxShadow(color: AppColors.violet500.withValues(alpha: 0.03), blurRadius: 15, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.violet50, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.people_alt_rounded, color: AppColors.violet600, size: 18),
              ),
              SizedBox(width: 10),
              Text('Xếp hạng nhân viên', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate800, letterSpacing: -0.3)),
              Spacer(),
              if (staff.length > 5)
                InkWell(
                  onTap: () => showDialog(context: context, builder: (_) => _AllStaffDialog(staff: staff)),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('Xem thêm', style: TextStyle(color: AppColors.violet600, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          SizedBox(height: 20),
          if (staff.isEmpty)
             Center(child: Padding(
               padding: const EdgeInsets.symmetric(vertical: 20),
               child: Text('Chưa có dữ liệu', style: TextStyle(color: AppColors.slate400, fontSize: 13, fontWeight: FontWeight.w600)),
             )),
          for (int i = 0; i < staff.length && i < 5; i++)
            _buildItem(staff[i], i),
        ],
      ),
    );
  }

  Widget _buildItem(_StaffRankItem item, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.slate50, shape: BoxShape.circle, border: Border.all(color: AppColors.slate200, width: 1.5)),
            child: Text(item.name.isNotEmpty ? item.name[0].toUpperCase() : 'N', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate500)),
          ),
          SizedBox(width: 14),
          Expanded(
             child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(item.name.isNotEmpty ? item.name : 'Vô danh', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate700), maxLines: 1, overflow: TextOverflow.ellipsis),
                   SizedBox(height: 2),
                   Text('${item.count} đơn hàng', style: TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w500)),
                ],
             )
          ),
          Text(formatCurrency(item.revenue), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.violet600)),
        ],
      ),
    );
  }
}


class _AllProductsDialog extends StatelessWidget {
  final List<_BestSellerItem> items;
  final int maxSold;
  const _AllProductsDialog({required this.items, required this.maxSold});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.cardBg,
      child: Container(
        width: 450,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.star_rounded, color: AppColors.primary600, size: 18),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Tất cả Sản phẩm', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate800, letterSpacing: -0.5)),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.slate400),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _buildItem(items[index], index, maxSold);
                }
              )
            )
          ]
        )
      )
    );
  }

  Widget _buildItem(_BestSellerItem item, int index, int maxSold) {
    double factor = item.sold / maxSold;
    if (factor > 1.0) factor = 1.0;
    if (factor < 0.02) factor = 0.02;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          return Stack(
            children: [
              Container(height: 56, width: barWidth, decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(12))),
              Container(height: 56, width: barWidth * factor, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary500.withValues(alpha: 0.15), AppColors.primary500.withValues(alpha: 0.05)]), borderRadius: BorderRadius.circular(12))),
              Container(
                height: 56, width: barWidth, padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 30, height: 30, alignment: Alignment.center,
                      decoration: BoxDecoration(color: index == 0 ? Color(0xFFF59E0B) : index == 1 ? Color(0xFF94A3B8) : index == 2 ? Color(0xFFD97706) : AppColors.cardBg, shape: BoxShape.circle, border: index > 2 ? Border.all(color: AppColors.slate200) : null),
                      child: Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: index < 3 ? Colors.white : AppColors.slate500)),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800), maxLines: 1, overflow: TextOverflow.ellipsis),
                          SizedBox(height: 2),
                          Row(
                             children: [
                                Icon(Icons.shopping_bag_rounded, size: 12, color: Color(0xFF059669)),
                                SizedBox(width: 4),
                                Text('${item.sold} lượt bán', style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w700)),
                             ]
                          )
                        ],
                      )
                    ),
                    Text(formatCurrency(item.revenue), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.slate800, letterSpacing: -0.5)),
                  ]
                )
              )
            ]
          );
        }
      )
    );
  }
}

class _AllStaffDialog extends StatelessWidget {
  final List<_StaffRankItem> staff;
  const _AllStaffDialog({required this.staff});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.cardBg,
      child: Container(
        width: 450,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.violet50, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.people_alt_rounded, color: AppColors.violet600, size: 18),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Tất cả Nhân viên', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate800, letterSpacing: -0.5)),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.slate400),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: staff.length,
                itemBuilder: (context, index) {
                  return _buildItem(staff[index], index);
                }
              )
            )
          ]
        )
      )
    );
  }

  Widget _buildItem(_StaffRankItem item, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.slate50, shape: BoxShape.circle, border: Border.all(color: AppColors.slate200, width: 1.5)),
            child: Text(item.name.isNotEmpty ? item.name[0].toUpperCase() : 'N', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate500)),
          ),
          SizedBox(width: 14),
          Expanded(
             child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(item.name.isNotEmpty ? item.name : 'Vô danh', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate700), maxLines: 1, overflow: TextOverflow.ellipsis),
                   SizedBox(height: 2),
                   Text('${item.count} đơn hàng', style: TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w500)),
                ],
             )
          ),
          Text(formatCurrency(item.revenue), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.violet600)),
        ],
      ),
    );
  }
}
