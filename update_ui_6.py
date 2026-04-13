import re

file_path = "e:/Moimoi-POS-Flutter/lib/features/cashflow/presentation/cashflow_page.dart"
with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

target1 = """// ── Panel 1: Premium Overview Dashboard ──"""

# Replace Panel 1 completely up to `// ── Calendar Panel ──`
pattern1 = r"// ── Panel 1: Premium Overview Dashboard ──.*?// ── Calendar Panel ──"
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
                            SizedBox(height: 14),
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
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: AppColors.emerald100, shape: BoxShape.circle),
                                          child: Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.emerald600),
                                        ),
                                        SizedBox(height: 6),
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
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: AppColors.red100, shape: BoxShape.circle),
                                          child: Icon(Icons.arrow_upward_rounded, size: 14, color: AppColors.red600),
                                        ),
                                        SizedBox(height: 6),
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
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: balance >= 0 ? AppColors.blue100 : AppColors.amber100, shape: BoxShape.circle),
                                          child: Icon(Icons.account_balance_wallet_rounded, size: 14, color: balance >= 0 ? AppColors.blue600 : AppColors.amber600),
                                        ),
                                        SizedBox(height: 6),
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
                      
                      _buildCategoryStats(store, allTxns),
                      
                      // ── Calendar Panel ──"""

# Add _panel() wrap in _buildCategoryStats
pattern2 = r"    return Column\(.*?crossAxisAlignment: CrossAxisAlignment\.start,.*?children: \[.*?Text\(.*?Thống kê theo danh mục.*?\),.*?SizedBox\(height: 16\),.*?\.\.\.sortedEntries\.map\(\(e\).*?\{.*?;.*?\}\);"
replacement2 = """    return Column(
      children: [
        SizedBox(height: 14),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thống kê theo danh mục',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate800,
                ),
              ),
              SizedBox(height: 16),
              ...sortedEntries.map((e) {
                final catLabel = e.key;
                final total = e.value;
                final isIncome =
                    allKnownCats.any((c) => c.label == catLabel && c.type == 'thu');
                final accentColor = isIncome ? AppColors.emerald500 : AppColors.red500;
                final bg = isIncome ? AppColors.emerald50 : AppColors.red50;
    
                final customCat = allKnownCats.firstWhere(
                    (c) => c.label == catLabel,
                    orElse: () => TransactionCategory(
                          type: isIncome ? 'thu' : 'chi',
                          emoji: '💰',
                          label: catLabel,
                          color: accentColor,
                          isCustom: true));
    
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(customCat.emoji, style: TextStyle(fontSize: 16)),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    catLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.slate700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  _formatAmount(total),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate800,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            Stack(
                              children: [
                                Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: AppColors.slate100,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: (total / maxTotal).clamp(0.0, 1.0),
                                  child: Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );"""

new_text, count1 = re.subn(pattern1, replacement1, text, flags=re.DOTALL)
new_text, count2 = re.subn(pattern2, replacement2, new_text, flags=re.DOTALL)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(new_text)

print(f"TARGET 1 COUNT: {count1}")
print(f"TARGET 2 COUNT: {count2}")
