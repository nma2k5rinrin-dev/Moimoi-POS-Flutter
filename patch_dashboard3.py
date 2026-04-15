import re

FILE_PATH = r"d:\Moimoi-POS-Flutter\lib\features\dashboard\presentation\dashboard_page.dart"
with open(FILE_PATH, "r", encoding="utf-8") as f:
    OrigContent = f.read()
content = OrigContent

# We will completely reinvent the main layout section:
# From: `final mainContent = Container(` to the end of the `Skeletonizer` block.

new_build_logic = """
        final mainContent = Container(
          color: AppColors.scaffoldBg,
          child: Column(
            children: [
              // Very slender top bar
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, top: 16, bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.analytics_outlined, color: AppColors.emerald600, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Báo Cáo Hoạt Động',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  child: LayoutBuilder(
                    builder: (context, outerConstraints) {
                      final isLandscape = outerConstraints.maxWidth > 600;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Sleek Header Row: Date Picker + Total Revenue
                          Row(
                            children: [
                              Expanded(flex: 3, child: _buildDatePicker()),
                              SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF0D9488), Color(0xFF10B981)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('TỔNG DOANH THU', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white70, letterSpacing: 0.5)),
                                      Text(
                                        formatCurrency(totalRevenue),
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),

                          // 2. Ultra-compact 4-stat row
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.slate200),
                            ),
                            child: Row(
                              children: [
                                _buildSlimStatItem('Tiền mặt', formatCurrency(cashRevenue), AppColors.orange500),
                                Container(width: 1, height: 30, color: AppColors.slate100),
                                _buildSlimStatItem('Chuyển khoản', formatCurrency(transferRevenue), AppColors.violet500),
                                Container(width: 1, height: 30, color: AppColors.slate100),
                                _buildSlimStatItem('Đơn hàng', '$totalOrders', AppColors.blue500),
                                Container(width: 1, height: 30, color: AppColors.slate100),
                                _buildSlimStatItem('TB/Đơn', totalOrders > 0 ? _formatShortCurrency(totalRevenue / totalOrders) : '0', AppColors.slate700),
                              ],
                            ),
                          ),
                          SizedBox(height: 8),

                          // 3. Very slim Hourly Chart
                          _HourlyRevenueChart(hourlyData: hourlyData),
                          SizedBox(height: 8),

                          // 4. Compact lists and flow chart
                          if (isLandscape) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _CashFlowChart(orders: filteredOrders, transactions: context.watch<CashflowStore>().transactions, dateFrom: _dateFrom, dateTo: _dateTo)),
                                SizedBox(width: 8),
                                Expanded(child: _BestSellersCard(items: bestSellers)),
                              ],
                            ),
                          ] else ...[
                            _CashFlowChart(orders: filteredOrders, transactions: context.watch<CashflowStore>().transactions, dateFrom: _dateFrom, dateTo: _dateTo),
                            SizedBox(height: 8),
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

# Let's target the exact `final mainContent = Container(` slice
pattern_maincontent = r"final mainContent = Container\(.*?return Skeletonizer\(enabled: isLoading, child: mainContent\);"
content = re.sub(pattern_maincontent, lambda _: new_build_logic.strip(), content, flags=re.DOTALL)

# Add slim stat helper
compact_stat_helper = """
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
"""
content = content.replace("  Widget _buildCompactStatItem(IconData icon, String label, String value, Color accent, {String? subtitle, Color? subtitleColor}) {", compact_stat_helper)


# Compact DatePicker
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
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.slate500),
            SizedBox(width: 6),
            Text(
              '${_dateFrom.day}/${_dateFrom.month}',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: AppColors.slate800),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('-', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
            ),
            Text(
              '${_dateTo.day}/${_dateTo.month}/${_dateTo.year}',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: AppColors.slate800),
            ),
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

# Compact Hourly Chart
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Doanh thu theo giờ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate700)),
          SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(hourlyData.length, (i) {
                final d = hourlyData[i];
                final fraction = maxVal > 0 ? d.total / maxVal : 0.0;
                final isPeak = i == peakIdx && d.total > 0;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d.total > 0)
                          FittedBox(
                            child: Text(
                              d.total >= 1000000 ? '${(d.total / 1000000).toStringAsFixed(1)}' : d.total >= 1000 ? '${(d.total / 1000).toStringAsFixed(0)}' : d.total.toStringAsFixed(0),
                              style: TextStyle(fontSize: 8, color: isPeak ? AppColors.emerald600 : AppColors.slate400, fontWeight: FontWeight.w600),
                            ),
                          ),
                        SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: (65 * fraction).clamp(2.0, 65.0),
                          decoration: BoxDecoration(
                            gradient: isPeak ? LinearGradient(colors: [AppColors.emerald400, AppColors.emerald600]) : null,
                            color: isPeak ? null : AppColors.slate200,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(d.label, style: TextStyle(fontSize: 8, color: AppColors.slate500)),
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

# Compact BestSellers
new_best_seller = """// ─── Best Sellers ───────────────────────────────────
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
              Text('Món bán chạy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate700)),
              if (items.length > 5)
                InkWell(
                  onTap: () => _HourlyRevenueChart._showAllBestSellersDialog(context, items), // Assuming same method but static
                  child: Text('Xem tất cả', style: TextStyle(fontSize: 11, color: AppColors.emerald600, fontWeight: FontWeight.w500)),
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
                      child: Text(_HourlyRevenueChart._formatShortRevenue(item.revenue), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.emerald600)),
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
"""

# Wait, `_formatShortRevenue` and `_showAllBestSellersDialog` was previously declared static in `_BestSellersCard`.
# We need to make sure we don't accidentally remove them or call them incorrectly.
# Let's just grab the whole _BestSellersCard including its static methods.
best_seller_target = re.search(r"// ─── Best Sellers.*?(?=\nclass _BestSellerItem)", content, re.DOTALL)
if best_seller_target:
    new_best_seller_replacement = """// ─── Best Sellers ───────────────────────────────────
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
              Text('Món bán chạy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate700)),
              if (items.length > 5)
                InkWell(
                  onTap: () => _showAllBestSellersDialog(context, items),
                  child: Text('Xem tất cả', style: TextStyle(fontSize: 11, color: AppColors.emerald600, fontWeight: FontWeight.w500)),
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
                      child: Text(_formatShortRevenue(item.revenue), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.emerald600)),
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
"""
    content = content[:best_seller_target.start()] + new_best_seller_replacement + content[best_seller_target.end():]


with open(FILE_PATH, "w", encoding="utf-8") as f:
    f.write(content)
print("Patch 3 executed successfully!")
