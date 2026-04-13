import re

file_path = "e:/Moimoi-POS-Flutter/lib/features/cashflow/presentation/cashflow_page.dart"
with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Update Premium Dashboard to Compact and split panels
pattern1 = r"// ── Panel 1: Premium Overview Dashboard ──.*?// ── Calendar Panel ──\s*_panel\(\s*child: _buildCalendar\(allTxns\),\s*\),"
replacement1 = """// ── Panel 1: Compact Overview Dashboard ──
                      _panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tổng doanh thu',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.slate800,
                              ),
                            ),
                            SizedBox(height: 12),
                            // Compact UI
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.emerald50.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppColors.emerald100),
                                    ),
                                    child: Column(
                                      children: [
                                        Text('Tổng Thu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.emerald700)),
                                        SizedBox(height: 4),
                                        FittedBox(fit: BoxFit.scaleDown, child: Text(_formatAmount(totalIncome), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.emerald800))),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.red50.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppColors.red100),
                                    ),
                                    child: Column(
                                      children: [
                                        Text('Tổng Chi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.red700)),
                                        SizedBox(height: 4),
                                        FittedBox(fit: BoxFit.scaleDown, child: Text(_formatAmount(totalExpense), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.red800))),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: balance >= 0 ? AppColors.blue50.withOpacity(0.5) : AppColors.amber50.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: balance >= 0 ? AppColors.blue100 : AppColors.amber100),
                                    ),
                                    child: Column(
                                      children: [
                                        Text('Số dư', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: balance >= 0 ? AppColors.blue700 : AppColors.amber700)),
                                        SizedBox(height: 4),
                                        FittedBox(fit: BoxFit.scaleDown, child: Text('${balance >= 0 ? '+' : ''}${_formatAmount(balance)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: balance >= 0 ? AppColors.blue800 : AppColors.amber800))),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 14),
                      _buildCategoryStats(store, allTxns),
                      SizedBox(height: 14),

                      // ── Calendar Panel ──
                      _panel(
                        child: _buildCalendar(allTxns),
                      ),"""

# 2. Modify _buildCategoryStats to wrap its Column in _panel.
pattern2 = r"(    return )(Column\(\s*crossAxisAlignment: CrossAxisAlignment\.start,\s*children: \[\s*Text\(\s*'Thống kê theo danh mục'.*?\}\),\s*\]\,\s*\)\;)"
# We wrap the second group inside _panel()
def panel_replacer(match):
    inner = match.group(2)
    # The last two characters are ');' we want to remove the semicolon, close panel, then semicolon
    inner = inner[:-1] # remove semicolon
    return f"    return _panel(child: {inner});"

new_text, count1 = re.subn(pattern1, replacement1, text, flags=re.DOTALL)
new_text, count2 = re.subn(pattern2, panel_replacer, new_text, flags=re.DOTALL)

# 3. Remove Icon from Calendar Badge!
pattern3 = r"          Icon\(icon, size: 7, color: accent\),\s*const SizedBox\(width: 2\),\s*Flexible\("
replacement3 = r"          Flexible("
new_text, count3 = re.subn(pattern3, replacement3, new_text)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(new_text)

print(f"COUNT1: {count1}, COUNT2: {count2}, COUNT3: {count3}")
