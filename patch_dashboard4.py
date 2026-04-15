import re

FILE_PATH = r"d:\Moimoi-POS-Flutter\lib\features\dashboard\presentation\dashboard_page.dart"
with open(FILE_PATH, "r", encoding="utf-8") as f:
    orig_content = f.read()

content = orig_content

# We need to replace the data grouping _getHourlyData and _HourSlot
hourly_target = re.search(r"class _HourSlot \{.*?\}", content, re.DOTALL)
if hourly_target:
    new_hour_slot = """class _HourSlot {
  final String label;
  final double total;
  final double cash;
  final double transfer;
  const _HourSlot({required this.label, required this.total, required this.cash, required this.transfer});
}"""
    content = content[:hourly_target.start()] + new_hour_slot + content[hourly_target.end():]

# Update _getHourlyData
get_hourly_target = re.search(r"  List\s*<\s*_HourSlot\s*>\s*_getHourlyData.*?(?=\n  String _formatShortCurrency)", content, re.DOTALL)
if get_hourly_target:
    new_get_hourly = """  List<_HourSlot> _getHourlyData(List<OrderModel> orders) {
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
"""
    content = content[:get_hourly_target.start()] + new_get_hourly + content[get_hourly_target.end():]

# Let's replace the whole `final mainContent = Container( ... );` from _DashboardPageState build 
maincontent_target = re.search(r"final mainContent = Container\(.*?return Skeletonizer\(enabled: isLoading, child: mainContent\);", content, re.DOTALL)
if maincontent_target:
    new_maincontent_logic = """
        // Build daily sparkline array for background charts
        final Map<String, double> summaryDailyTotal = {};
        final Map<String, double> summaryDailyCash = {};
        final Map<String, double> summaryDailyTransfer = {};
        
        DateTime currentD = DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
        while (currentD.isBefore(_dateTo) || currentD.isAtSameMomentAs(DateTime(_dateTo.year, _dateTo.month, _dateTo.day))) {
          final k = '${currentD.day}/${currentD.month}';
          summaryDailyTotal[k] = 0.0;
          summaryDailyCash[k] = 0.0;
          summaryDailyTransfer[k] = 0.0;
          currentD = currentD.add(Duration(days: 1));
        }

        for (final o in filteredOrders) {
           final dtStr = o.time.endsWith('Z') ? o.time.substring(0, o.time.length - 1) : o.time;
           final dt = DateTime.tryParse(dtStr);
           if (dt != null) {
              final k = '${dt.day}/${dt.month}';
              if (summaryDailyTotal.containsKey(k)) {
                 summaryDailyTotal[k] = summaryDailyTotal[k]! + o.calculatedTotal;
                 if (o.paymentMethod == 'cash') {
                    summaryDailyCash[k] = summaryDailyCash[k]! + o.calculatedTotal;
                 } else if (o.paymentMethod == 'transfer') {
                    summaryDailyTransfer[k] = summaryDailyTransfer[k]! + o.calculatedTotal;
                 }
              }
           }
        }
        
        List<double> totalSpots = summaryDailyTotal.values.toList();
        List<double> cashSpots = summaryDailyCash.values.toList();
        List<double> transferSpots = summaryDailyTransfer.values.toList();

        final mainContent = Container(
          color: Color(0xFFF3F4F6), // light sleek background
          child: Column(
            children: [
              // Sleek App Bar Header
              Container(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                color: Colors.white,
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
                        SizedBox(height: 2),
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
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                  child: LayoutBuilder(
                    builder: (context, outerConstraints) {
                      final isLandscape = outerConstraints.maxWidth > 600;

                      // 1. The 3 Money Cards with Background Charts
                      final threeCards = Row(
                        children: [
                          Expanded(
                            child: _SparklineCard(
                              title: 'TỔNG DOANH THU',
                              value: formatCurrency(totalRevenue),
                              accentColor: Color(0xFF10B981),
                              spots: totalSpots,
                              isGradientValue: true,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _SparklineCard(
                              title: 'TIỀN MẶT',
                              value: formatCurrency(cashRevenue),
                              accentColor: Color(0xFFF59E0B),
                              spots: cashSpots,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _SparklineCard(
                              title: 'CHUYỂN KHOẢN',
                              value: formatCurrency(transferRevenue),
                              accentColor: Color(0xFF6366F1),
                              spots: transferSpots,
                            ),
                          ),
                        ],
                      );

                      // 2. Extra metrics (Orders, Avg) -> combined in a simple bar below
                      final extraMetrics = Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.slate200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                                  child: Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF3B82F6)),
                                ),
                                SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Tổng đơn hàng', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                                    Text('$totalOrders', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slate800)),
                                  ],
                                ),
                              ],
                            ),
                            Container(width: 1, height: 30, color: AppColors.slate100),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(8)),
                                  child: Icon(Icons.analytics_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                ),
                                SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Trung bình cữ/đơn', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                                    Text(totalOrders > 0 ? _formatShortCurrency(totalRevenue / totalOrders) : '0', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slate800)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          threeCards,
                          SizedBox(height: 12),
                          extraMetrics,
                          SizedBox(height: 16),
                          
                          // 3. Hourly Chart (stacked bar with legend)
                          _HourlyRevenueStackedChart(hourlyData: hourlyData),
                          SizedBox(height: 16),

                          // 4. Compact lists and flow chart
                          if (isLandscape) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _CashFlowChart(orders: filteredOrders, transactions: context.watch<CashflowStore>().transactions, dateFrom: _dateFrom, dateTo: _dateTo)),
                                SizedBox(width: 12),
                                Expanded(child: _BestSellersCard(items: bestSellers)),
                              ],
                            ),
                          ] else ...[
                            _CashFlowChart(orders: filteredOrders, transactions: context.watch<CashflowStore>().transactions, dateFrom: _dateFrom, dateTo: _dateTo),
                            SizedBox(height: 16),
                            _BestSellersCard(items: bestSellers),
                          ],
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
"""
    content = content[:maincontent_target.start()] + new_maincontent_logic.strip() + content[maincontent_target.end() - len(";"):]

new_date_picker = """  Widget _buildDatePicker() {
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
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.emerald600),
            SizedBox(width: 6),
            Text(
              '${_dateFrom.day}/${_dateFrom.month} - ${_dateTo.day}/${_dateTo.month}/${_dateTo.year}',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.slate700),
            ),
            SizedBox(width: 6),
            Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }
"""
content = re.sub(
    r"  Widget _buildDatePicker\(\) \{.*?(?=\n  Widget _buildSlimStatItem)",
    lambda _: new_date_picker,
    content,
    flags=re.DOTALL
)

# And replace `class _HourlyRevenueChart ` and `_MobileMiniCard` with new components
new_components = """class _SparklineCard extends StatelessWidget {
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          // Background soft line chart
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 50,
            child: ClipRRect(
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
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
                      color: accentColor.withValues(alpha: 0.5),
                      barWidth: 1.5,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            accentColor.withValues(alpha: 0.15),
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
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                    ),
                    SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                isGradientValue
                    ? ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [Color(0xFF0D9488), Color(0xFF10B981)],
                        ).createShader(bounds),
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      )
                    : Text(
                        value,
                        style: TextStyle(
                          fontSize: 18,
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
        color: Colors.white,
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
                        '${h.label}\\nTiền mặt: ${_HourlyRevenueStackedChart._formatShortRevenue(h.cash)}\\nCK: ${_HourlyRevenueStackedChart._formatShortRevenue(h.transfer)}',
                        TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(showTitles: false),
                  rightTitles: AxisTitles(showTitles: false),
                  topTitles: AxisTitles(showTitles: false),
                  bottomTitles: AxisTitles(
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
                        toY: d.total,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                        rodStackItems: [
                          BarChartRodStackItem(0, d.cash, Color(0xFFF59E0B)),
                          BarChartRodStackItem(d.cash, d.cash + d.transfer, Color(0xFF6366F1)),
                        ],
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

"""
content = re.sub(
    r"class _HourlyRevenueChart extends StatelessWidget \{.*?(?=\n// ─── Best Sellers)",
    lambda _: new_components,
    content,
    flags=re.DOTALL
)

with open(FILE_PATH, "w", encoding="utf-8") as f:
    f.write(content)
print("Patch 4 executed successfully!")
