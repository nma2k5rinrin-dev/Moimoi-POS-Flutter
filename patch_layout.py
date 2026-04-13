import os

file_path = "e:/Moimoi-POS-Flutter/lib/features/cashflow/presentation/cashflow_page.dart"
with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

target = """                            SizedBox(height: 16),

                            // Income / Expense cards
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.emerald50,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppColors.emerald100,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.trending_up_rounded,
                                              size: 16,
                                              color: AppColors.emerald500,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Thu',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.emerald600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          _formatAmount(totalIncome),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.emerald700,
                                          ),
                                        ),
                                        Text(
                                          'VNĐ',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.slate400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.red50,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppColors.red100,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.trending_down_rounded,
                                              size: 16,
                                              color: AppColors.red500,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Chi',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.red600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          _formatAmount(totalExpense),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.red600,
                                          ),
                                        ),
                                        Text(
                                          'VNĐ',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.slate400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),

                            // Balance
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.slate50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Số dư:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.slate500,
                                    ),
                                  ),
                                  Spacer(),
                                  Text(
                                    '${balance >= 0 ? '+' : '-'}${_formatAmount(balance)} VNĐ',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: balance >= 0
                                          ? AppColors.emerald600
                                          : AppColors.red500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),"""

replacement = """                            SizedBox(height: 12),
                            
                            // Compact Income / Expense / Balance Row
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
                            ),
                            SizedBox(height: 16),"""

if target in text:
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(text.replace(target, replacement))
    print("SUCCESS")
else:
    print("TARGET NOT FOUND")
