import re

FILE_PATH = r"d:\Moimoi-POS-Flutter\lib\features\dashboard\presentation\dashboard_page.dart"
with open(FILE_PATH, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add "Xem thêm" to Top Products
products_row_replace = """          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.star_rounded, color: Color(0xFF059669), size: 18),
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
                    child: Text('Xem thêm', style: TextStyle(color: AppColors.emerald600, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),"""

# Find the exact row and replace
old_products_row = """          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.star_rounded, color: Color(0xFF059669), size: 18),
              ),
              SizedBox(width: 10),
              Text('Sản phẩm nổi bật', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate800, letterSpacing: -0.3)),
            ],
          ),"""
content = content.replace(old_products_row, products_row_replace)

# 2. Add "Xem thêm" to Top Staff
staff_row_replace = """          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.people_alt_rounded, color: Color(0xFF7C3AED), size: 18),
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
                    child: Text('Xem thêm', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),"""

old_staff_row = """          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.people_alt_rounded, color: Color(0xFF7C3AED), size: 18),
              ),
              SizedBox(width: 10),
              Text('Xếp hạng nhân viên', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate800, letterSpacing: -0.3)),
            ],
          ),"""
content = content.replace(old_staff_row, staff_row_replace)

# 3. Add Dialog classes at the end
new_classes = """
class _AllProductsDialog extends StatelessWidget {
  final List<_BestSellerItem> items;
  final int maxSold;
  const _AllProductsDialog({required this.items, required this.maxSold});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
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
                  decoration: BoxDecoration(color: Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.star_rounded, color: Color(0xFF059669), size: 18),
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
              Container(height: 56, width: barWidth, decoration: BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12))),
              Container(height: 56, width: barWidth * factor, decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)]), borderRadius: BorderRadius.circular(12))),
              Container(
                height: 56, width: barWidth, padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 30, height: 30, alignment: Alignment.center,
                      decoration: BoxDecoration(color: index == 0 ? Color(0xFFF59E0B) : index == 1 ? Color(0xFF94A3B8) : index == 2 ? Color(0xFFD97706) : Colors.white, shape: BoxShape.circle, border: index > 2 ? Border.all(color: AppColors.slate200) : null),
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
      backgroundColor: Colors.white,
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
                  decoration: BoxDecoration(color: Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.people_alt_rounded, color: Color(0xFF7C3AED), size: 18),
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

content += "\n" + new_classes

with open(FILE_PATH, "w", encoding="utf-8") as f:
    f.write(content)
print("Patch applied to dashboard_page.dart!")
