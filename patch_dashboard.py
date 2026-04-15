import re

FILE_PATH = r"d:\Moimoi-POS-Flutter\lib\features\dashboard\presentation\dashboard_page.dart"
with open(FILE_PATH, "r", encoding="utf-8") as f:
    orig_content = f.read()

content = orig_content

# 1. Replace _MobileMiniCard
new_mini_card = """class _MobileMiniCard extends StatelessWidget {
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
        color: Colors.white,
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
"""
content = re.sub(
    r"class _MobileMiniCard extends StatelessWidget \{.*?(?=\n// ─── Daily Revenue Chart|\n// ─── Cash Flow Chart)",
    lambda _: new_mini_card,
    content,
    flags=re.DOTALL
)

# 2. Replace _buildDatePicker
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
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.slate200),
          boxShadow: [
            BoxShadow(
              color: AppColors.slate900.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: AppColors.emerald600,
                  ),
                  SizedBox(width: 12),
                  Text(
                    '${_dateFrom.day.toString().padLeft(2, '0')}/${_dateFrom.month.toString().padLeft(2, '0')}/${_dateFrom.year}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.slate800,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.slate400,
                    ),
                  ),
                  Text(
                    '${_dateTo.day.toString().padLeft(2, '0')}/${_dateTo.month.toString().padLeft(2, '0')}/${_dateTo.year}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.slate800,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.slate500,
              ),
            ),
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

# 3. Replace the Header and Portrait Revenue Card in `build`
# First, let's redefine the Header and Revenue Card completely by replacing the `mainContent = Container( ... );`
# Since it's nested deep and large, we can replace the layout builder portrait part:
# It starts at: // Portrait: revenue banner + 2×2 grid
# ends at: SizedBox(height: 24), \n // ── Charts

portrait_target = re.search(r"// Portrait: revenue banner \+ 2×2 grid\n(.*?)SizedBox\(height: 24\),\n\n\s+// ── Charts", content, re.DOTALL)
if portrait_target:
    new_portrait = """// Portrait: revenue banner + 2×2 grid
                        return Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF0D9488), // teal 600
                                    Color(0xFF10B981), // emerald 500
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // Decorative circles
                                  Positioned(
                                    top: -20,
                                    right: -20,
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(alpha: 0.1),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Icon(
                                          Icons.show_chart_rounded,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                      ),
                                      SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Tổng doanh thu',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white.withValues(alpha: 0.9),
                                              ),
                                            ),
                                            SizedBox(height: 6),
                                            Text(
                                              formatCurrency(totalRevenue),
                                              style: TextStyle(
                                                fontSize: 28,
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
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      cashCard,
                                      SizedBox(height: 16),
                                      ordersCard,
                                    ],
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    children: [
                                      transferCard,
                                      SizedBox(height: 16),
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

                    """
    content = content[:portrait_target.start()] + new_portrait + content[portrait_target.end() - len("SizedBox(height: 24),\n\n                    // ── Charts"):]
    
# 4. _HourlyRevenueChart
new_hourly_chart = """class _HourlyRevenueChart extends StatelessWidget {
  final List<_HourSlot> hourlyData;
  const _HourlyRevenueChart({required this.hourlyData});

  @override
  Widget build(BuildContext context) {
    final maxVal = hourlyData.fold(
      0.0,
      (max, d) => d.total > max ? d.total : max,
    );
    int peakIdx = 0;
    for (int i = 1; i < hourlyData.length; i++) {
      if (hourlyData[i].total > hourlyData[peakIdx].total) peakIdx = i;
    }

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate100),
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
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.schedule_rounded, size: 20, color: AppColors.emerald600),
              ),
              SizedBox(width: 16),
              Text(
                'Doanh thu theo khung giờ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate800,
                ),
              ),
            ],
          ),
          SizedBox(height: 32),
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(hourlyData.length, (i) {
                final d = hourlyData[i];
                final fraction = maxVal > 0 ? d.total / maxVal : 0.0;
                final isPeak = i == peakIdx && d.total > 0;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
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
                              fontSize: 10,
                              color: isPeak ? AppColors.emerald600 : AppColors.slate500,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        SizedBox(height: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: (140 * fraction).clamp(6.0, 140.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isPeak
                                  ? [AppColors.emerald400, AppColors.emerald600]
                                  : fraction > 0
                                  ? [AppColors.slate300, AppColors.slate400]
                                  : [AppColors.slate100, AppColors.slate200],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isPeak
                                ? [
                                    BoxShadow(
                                      color: AppColors.emerald500.withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : null,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          d.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: isPeak ? AppColors.emerald600 : AppColors.slate400,
                            fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
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
"""
content = re.sub(
    r"class _HourlyRevenueChart extends StatelessWidget \{.*?(?=\n// ─── Best Sellers)",
    lambda _: new_hourly_chart,
    content,
    flags=re.DOTALL
)

with open(FILE_PATH, "w", encoding="utf-8") as f:
    f.write(content)
print("Patch executed successfully!")
