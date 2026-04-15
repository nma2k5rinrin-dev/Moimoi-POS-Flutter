import re

FILE_PATH = r"d:\Moimoi-POS-Flutter\lib\features\dashboard\presentation\dashboard_page.dart"
with open(FILE_PATH, "r", encoding="utf-8") as f: content = f.read()

# 1. Update the Sparkline spots logic replacing the Daily Summary arrays with Hourly arrays
old_sparkline_logic_pattern = r"(?<=        // Build daily sparkline array for background charts\n).*?(?=\n        final mainContent = Container\()"

def replace_sparkline_logic(match):
    return """        
        List<double> totalSpots = hourlyData.map((e) => e.total).toList();
        List<double> cashSpots = hourlyData.map((e) => e.cash).toList();
        List<double> transferSpots = hourlyData.map((e) => e.transfer).toList();
    """

content = re.sub(old_sparkline_logic_pattern, replace_sparkline_logic, content, flags=re.DOTALL)


# 2. Update _SparklineCard style to match Income/Expense
old_sparkline_card_target = re.search(r"class _SparklineCard extends StatelessWidget \{.*?(?=\nclass _HourlyRevenueStackedChart extends StatelessWidget)", content, re.DOTALL)
if old_sparkline_card_target:
    new_sparkline_card = """class _SparklineCard extends StatelessWidget {
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
                          colors: [Color(0xFF0D9488), Color(0xFF10B981)],
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
    content = content[:old_sparkline_card_target.start()] + new_sparkline_card + content[old_sparkline_card_target.end():]


# 3. Update BarChart to render columns side by side instead of stacked
content = content.replace("class _HourlyRevenueStackedChart extends StatelessWidget {", "class _HourlyRevenueStackedChart extends StatelessWidget {")

old_bargroups_pattern = r"barGroups: List.generate\(hourlyData.length, \(i\) \{.*?\}\),"
new_bargroups = """barGroups: List.generate(hourlyData.length, (i) {
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
                }),"""
content = re.sub(old_bargroups_pattern, new_bargroups, content, flags=re.DOTALL)

with open(FILE_PATH, "w", encoding="utf-8") as f:
    f.write(content)
print("Patch 5 executed successfully!")
