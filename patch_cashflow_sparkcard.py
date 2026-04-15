import re

FILE_PATH = r"d:\Moimoi-POS-Flutter\lib\features\cashflow\presentation\cashflow_page.dart"
with open(FILE_PATH, "r", encoding="utf-8") as f: content = f.read()

# 1. Provide _SparklineCard at the bottom
new_card = """class _SparklineCard extends StatelessWidget {
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
        color: Colors.white,
        gradient: LinearGradient(
          colors: [Colors.white, accentColor.withValues(alpha: 0.15)],
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
                          colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
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
"""
content += "\\n" + new_card


# 2. Extract block replacing stats layout in cashflow_page
regex = r"(?<=// ── Stats \(Số dư \| Thu nhập \| Chi tiêu\) ──\n).*?(?=\n                      SizedBox\(height: 16\),\n                      // ── Tabs ──)"

replacement = """                      Row(
                        children: [
                          Expanded(
                            child: _SparklineCard(
                              title: 'SỐ DƯ HIỆN TẠI',
                              value: '${balance >= 0 ? '+' : ''}${_formatAmount(balance)}',
                              accentColor: Color(0xFF3B82F6),
                              spots: balanceSpots.map((e) => e.y).toList(),
                              isGradientValue: true,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _SparklineCard(
                              title: 'THU NHẬP',
                              value: _formatAmount(totalIncome),
                              accentColor: Color(0xFF10B981),
                              spots: incomeSpots.map((e) => e.y).toList(),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _SparklineCard(
                              title: 'CHI TIÊU',
                              value: _formatAmount(totalExpense),
                              accentColor: Color(0xFFEF4444), // red
                              spots: expenseSpots.map((e) => e.y).toList(),
                            ),
                          ),
                        ],
                      ),"""

content = re.sub(regex, replacement, content, flags=re.DOTALL)


# Write back
with open(FILE_PATH, "w", encoding="utf-8") as f: f.write(content)

print("Patch applied")
