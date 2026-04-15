import re

FILE_PATH = r"d:\Moimoi-POS-Flutter\lib\features\dashboard\presentation\dashboard_page.dart"
with open(FILE_PATH, "r", encoding="utf-8") as f: content = f.read()

# 1. Replace getting methods to include top staff
old_best_sellers_method = r"(List<_BestSellerItem> _getBestSellers\(List<OrderModel> orders\) \{.*?\n  \})"
new_get_methods = r"""\g<1>

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
  }"""
content = re.sub(old_best_sellers_method, new_get_methods, content, flags=re.DOTALL)

# Add _StaffRankItem somewhere
staff_rank_item_class = r"""
class _StaffRankItem {
  final String name;
  final double revenue;
  final int count;
  _StaffRankItem({required this.name, required this.revenue, required this.count});
}
"""
content = re.sub(r"(class _BestSellerItem \{.*?\n\})", r"\g<1>\n" + staff_rank_item_class, content, flags=re.DOTALL)

# 2. Add `final topStaff = _getTopStaff(filteredOrders);` inside `build`
content = content.replace(
    "final bestSellers = _getBestSellers(filteredOrders);",
    "final bestSellers = _getBestSellers(filteredOrders);\n        final topStaff = _getTopStaff(filteredOrders);"
)


# 3. Replace layout usage
old_layout = """                          // 4. Compact lists and flow chart
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
                          ],"""

new_layout = """// 4. Compact panels: Top Products and Top Staff
                          if (isLandscape) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _TopProductsPanel(items: bestSellers)),
                                SizedBox(width: 12),
                                Expanded(child: _TopStaffPanel(staff: topStaff)),
                              ],
                            ),
                          ] else ...[
                            _TopProductsPanel(items: bestSellers),
                            SizedBox(height: 16),
                            _TopStaffPanel(staff: topStaff),
                          ],"""

content = content.replace(old_layout, new_layout)


new_panels = """
class _TopProductsPanel extends StatelessWidget {
  final List<_BestSellerItem> items;
  const _TopProductsPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [BoxShadow(color: AppColors.emerald500.withValues(alpha: 0.03), blurRadius: 15, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.star_rounded, color: Color(0xFF059669), size: 18),
              ),
              SizedBox(width: 10),
              Text('Sản phẩm nổi bật', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate800, letterSpacing: -0.3)),
            ],
          ),
          SizedBox(height: 20),
          if (items.isEmpty)
             Center(child: Padding(
               padding: const EdgeInsets.symmetric(vertical: 20),
               child: Text('Chưa có dữ liệu', style: TextStyle(color: AppColors.slate400, fontSize: 13, fontWeight: FontWeight.w600)),
             )),
          for (int i = 0; i < items.length && i < 5; i++)
            _buildItem(items[i], i),
        ],
      ),
    );
  }

  Widget _buildItem(_BestSellerItem item, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: index == 0 ? Color(0xFFF59E0B) : index == 1 ? Color(0xFF94A3B8) : index == 2 ? Color(0xFFD97706) : Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: Text('${index + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: index < 3 ? Colors.white : AppColors.slate500)),
          ),
          SizedBox(width: 14),
          Expanded(
             child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(item.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate700), maxLines: 1, overflow: TextOverflow.ellipsis),
                   SizedBox(height: 2),
                   Text('Đã bán: ${item.sold}', style: TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w500)),
                ],
             )
          ),
          Text(formatCurrency(item.revenue), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
        ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [BoxShadow(color: Color(0xFF8B5CF6).withValues(alpha: 0.03), blurRadius: 15, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.people_alt_rounded, color: Color(0xFF7C3AED), size: 18),
              ),
              SizedBox(width: 10),
              Text('Xếp hạng nhân viên', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate800, letterSpacing: -0.3)),
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
            decoration: BoxDecoration(color: Color(0xFFF8FAFC), shape: BoxShape.circle, border: Border.all(color: Color(0xFFE2E8F0), width: 1.5)),
            child: Text(item.name.isNotEmpty ? item.name[0].toUpperCase() : 'N', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
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
          Text(formatCurrency(item.revenue), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED))),
        ],
      ),
    );
  }
}
"""

i1 = content.find("class _CashFlowChart extends ")
if i1 != -1:
    content = content[:i1] + new_panels
else:
    print("Warning: _CashFlowChart not found, appending to EOF")
    content += new_panels

with open(FILE_PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("Patch 6 executed successfully!")
