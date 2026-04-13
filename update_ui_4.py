import re

file_path = "e:/Moimoi-POS-Flutter/lib/features/cashflow/presentation/cashflow_page.dart"
with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

pattern = r"// ── Panel 1: Overview ──.*?_buildCategoryStats\(store,\s*allTxns\)"

replacement = """// ── Panel 1: Premium Overview Dashboard ──
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
                            SizedBox(height: 16),
                            
                            // Premium Revenue Dash
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.slate900, AppColors.slate800],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.slate900.withOpacity(0.15),
                                    blurRadius: 15,
                                    offset: Offset(0, 8),
                                  )
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Số dư ở giữa trang trọng
                                  Text(
                                    'SỐ DƯ HIỆN TẠI',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slate400, letterSpacing: 1.2),
                                  ),
                                  SizedBox(height: 8),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${balance >= 0 ? '+' : ''}${_formatAmount(balance)}',
                                      style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  // Hai thẻ nhỏ ở dưới
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.emerald500.withOpacity(0.2), shape: BoxShape.circle), child: Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.emerald400)),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Tổng Thu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate300)),
                                                    Text(_formatAmount(totalIncome), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.emerald400), overflow: TextOverflow.ellipsis),
                                                  ],
                                                ),
                                              )
                                            ],
                                          )
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.red500.withOpacity(0.2), shape: BoxShape.circle), child: Icon(Icons.arrow_upward_rounded, size: 16, color: AppColors.red400)),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Tổng Chi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate300)),
                                                    Text(_formatAmount(totalExpense), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.red400), overflow: TextOverflow.ellipsis),
                                                  ],
                                                ),
                                              )
                                            ],
                                          )
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            ),
                            SizedBox(height: 16),
                            _buildCategoryStats(store, allTxns)"""

new_text, count = re.subn(pattern, replacement, text, flags=re.DOTALL)
if count > 0:
    print("SUCCESS")
else:
    print("NOT FOUND")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(new_text)
