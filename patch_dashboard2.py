import re

FILE_PATH = r"d:\Moimoi-POS-Flutter\lib\features\dashboard\presentation\dashboard_page.dart"
with open(FILE_PATH, "r", encoding="utf-8") as f:
    OrigContent = f.read()
content = OrigContent

# 1. Update Date Picker to be more compact
new_build_date = """  Widget _buildDatePicker() {
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
          boxShadow: [
            BoxShadow(
              color: AppColors.slate900.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.emerald600),
            SizedBox(width: 8),
            Text(
              '${_dateFrom.day.toString().padLeft(2, '0')}/${_dateFrom.month.toString().padLeft(2, '0')}',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.slate800),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.slate400),
            ),
            Text(
              '${_dateTo.day.toString().padLeft(2, '0')}/${_dateTo.month.toString().padLeft(2, '0')}/${_dateTo.year}',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.slate800),
            ),
            SizedBox(width: 12),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }
"""
content = re.sub(
    r"  Widget _buildDatePicker\(\) \{.*?(?=\n  List<OrderModel> _filterByTime)",
    lambda _: new_build_date,
    content,
    flags=re.DOTALL
)

# 2. Update Portrait Layout to use a combined stats card instead of 4 separate cards
portrait_target = re.search(r"// Portrait: revenue banner \+ 2×2 grid\n(.*?)SizedBox\(height: 24\),\n\n\s+// ── Charts", content, re.DOTALL)
if portrait_target:
    new_portrait = """// Portrait: revenue banner + Combined Stats Card
                        return Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF0D9488), // teal 600
                                    Color(0xFF10B981), // emerald 500
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: -10,
                                    right: -10,
                                    child: Icon(Icons.show_chart_rounded, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tổng doanh thu',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.9),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        formatCurrency(totalRevenue),
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12),
                            // Combined Stats Card
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.slate200),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.slate900.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  IntrinsicHeight(
                                    child: Row(
                                      children: [
                                        Expanded(child: _buildCompactStatItem(Icons.payments_rounded, 'Tiền mặt', formatCurrency(cashRevenue), Color(0xFFF59E0B))),
                                        VerticalDivider(width: 1, color: AppColors.slate100),
                                        Expanded(child: _buildCompactStatItem(Icons.account_balance_rounded, 'Chuyển khoản', formatCurrency(transferRevenue), Color(0xFF8B5CF6))),
                                      ],
                                    ),
                                  ),
                                  Divider(height: 1, color: AppColors.slate100),
                                  IntrinsicHeight(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _buildCompactStatItem(
                                            Icons.receipt_long_rounded, 
                                            'Tổng đơn', 
                                            '$totalOrders', 
                                            Color(0xFF3B82F6),
                                            subtitle: totalCancelled > 0 ? 'Đơn hủy: $totalCancelled' : null,
                                            subtitleColor: Color(0xFFEF4444),
                                          ),
                                        ),
                                        VerticalDivider(width: 1, color: AppColors.slate100),
                                        Expanded(
                                          child: _buildCompactStatItem(
                                            Icons.analytics_rounded, 
                                            'TB/đơn', 
                                            totalOrders > 0 ? _formatShortCurrency(totalRevenue / totalOrders) : '0', 
                                            Color(0xFF6D28D9),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
"""
    content = content[:portrait_target.start()] + new_portrait + content[portrait_target.end() - len("SizedBox(height: 24),\n\n                    // ── Charts"):]

# 3. Add _buildCompactStatItem helper Method
# We need to inject this method inside _DashboardPageState class. Let's put it right before _filterByTime
compact_stat_helper = """
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
"""

content = content.replace("  List<OrderModel> _filterByTime(List<OrderModel> orders) {", compact_stat_helper, 1)

# 4. _HourlyRevenueChart
new_hourly_chart = """class _HourlyRevenueChart extends StatelessWidget {
  final List<_HourSlot> hourlyData;
  const _HourlyRevenueChart({required this.hourlyData});

  @override
  Widget build(BuildContext context) {
    final maxVal = hourlyData.fold(0.0, (max, d) => d.total > max ? d.total : max);
    int peakIdx = 0;
    for (int i = 1; i < hourlyData.length; i++) {
      if (hourlyData[i].total > hourlyData[peakIdx].total) peakIdx = i;
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(color: AppColors.slate900.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 18, color: AppColors.emerald600),
              SizedBox(width: 8),
              Text('Doanh thu theo khung giờ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.slate800)),
            ],
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 140,
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
                          Container(
                            padding: EdgeInsets.only(bottom: 4),
                            child: FittedBox(
                              child: Text(
                                d.total >= 1000000 ? '${(d.total / 1000000).toStringAsFixed(1)}M' : d.total >= 1000 ? '${(d.total / 1000).toStringAsFixed(0)}K' : d.total.toStringAsFixed(0),
                                style: TextStyle(fontSize: 9, color: isPeak ? AppColors.emerald600 : AppColors.slate500, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: (100 * fraction).clamp(4.0, 100.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isPeak ? [AppColors.emerald400, AppColors.emerald600] : fraction > 0 ? [AppColors.slate300, AppColors.slate400] : [AppColors.slate100, AppColors.slate200],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(d.label, style: TextStyle(fontSize: 9, color: isPeak ? AppColors.emerald600 : AppColors.slate400, fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600)),
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
"""
content = re.sub(
    r"class _HourlyRevenueChart extends StatelessWidget \{.*?(?=\n// ─── Best Sellers)",
    lambda _: new_hourly_chart,
    content,
    flags=re.DOTALL
)

with open(FILE_PATH, "w", encoding="utf-8") as f:
    f.write(content)
print("Patch 2 executed successfully!")
