import re

file_path = "e:/Moimoi-POS-Flutter/lib/features/cashflow/presentation/cashflow_page.dart"
with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

# TARGET 1: The Month Picker Button
target1 = """                          child: Container(
                            margin: EdgeInsets.only(bottom: 20),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.slate200.withOpacity(0.5),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                )
                              ],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.emerald100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.date_range_rounded, size: 18, color: AppColors.emerald600),
                                SizedBox(width: 8),
                                Text(
                                  'Tháng ${_dateFrom.month}/${_dateFrom.year}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.slate800,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.slate500),
                              ],
                            ),
                          ),"""

replacement1 = """                          child: Container(
                            margin: EdgeInsets.only(bottom: 24),
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.slate100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.slate700),
                                SizedBox(width: 10),
                                Text(
                                  'Tháng ${_dateFrom.month}/${_dateFrom.year}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.slate800,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: AppColors.slate500),
                              ],
                            ),
                          ),"""

# TARGET 2: The Income/Expense Horizontal Block
target2 = """                            // Compact Income / Expense / Balance Row
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.slate50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.slate200),
                              ),
                              child: Row(
                                children: [
                                  // Thu
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.trending_up_rounded, size: 14, color: AppColors.emerald500),
                                            SizedBox(width: 4),
                                            Text('Thu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.emerald600)),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Text(_formatAmount(totalIncome), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.emerald700)),
                                      ],
                                    ),
                                  ),
                                  Container(width: 1, height: 32, color: AppColors.slate200),
                                  SizedBox(width: 12),
                                  
                                  // Chi
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.trending_down_rounded, size: 14, color: AppColors.red500),
                                            SizedBox(width: 4),
                                            Text('Chi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.red600)),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Text(_formatAmount(totalExpense), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.red600)),
                                      ],
                                    ),
                                  ),
                                  Container(width: 1, height: 32, color: AppColors.slate200),
                                  SizedBox(width: 12),
                                  
                                  // Balance
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Số dư', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500)),
                                        SizedBox(height: 4),
                                        Text(
                                          '${balance >= 0 ? '+' : '-'}${_formatAmount(balance)}',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: balance >= 0 ? AppColors.emerald600 : AppColors.red500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),"""

replacement2 = """                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.emerald50,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: AppColors.emerald100, shape: BoxShape.circle),
                                          child: Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.emerald600),
                                        ),
                                        SizedBox(height: 8),
                                        Text('Thu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.emerald700)),
                                        SizedBox(height: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(_formatAmount(totalIncome), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.emerald800)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.red50,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: AppColors.red100, shape: BoxShape.circle),
                                          child: Icon(Icons.arrow_upward_rounded, size: 14, color: AppColors.red600),
                                        ),
                                        SizedBox(height: 8),
                                        Text('Chi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.red700)),
                                        SizedBox(height: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(_formatAmount(totalExpense), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.red800)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: balance >= 0 ? AppColors.blue50 : AppColors.amber50,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: balance >= 0 ? AppColors.blue100 : AppColors.amber100, shape: BoxShape.circle),
                                          child: Icon(Icons.account_balance_wallet_rounded, size: 14, color: balance >= 0 ? AppColors.blue600 : AppColors.amber600),
                                        ),
                                        SizedBox(height: 8),
                                        Text('Số dư', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: balance >= 0 ? AppColors.blue700 : AppColors.amber700)),
                                        SizedBox(height: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('${balance >= 0 ? '+' : ''}${_formatAmount(balance)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: balance >= 0 ? AppColors.blue800 : AppColors.amber800)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),"""

if target1 in text:
    text = text.replace(target1, replacement1)
    print("TARGET 1 SUCCESS")
else:
    print("TARGET 1 NOT FOUND")

if target2 in text:
    text = text.replace(target2, replacement2)
    print("TARGET 2 SUCCESS")
else:
    print("TARGET 2 NOT FOUND")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(text)

print("DONE")
