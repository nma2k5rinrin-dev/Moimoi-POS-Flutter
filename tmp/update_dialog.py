import codecs
import re

path = r'lib\features\cashflow\presentation\cashflow_page.dart'
with codecs.open(path, 'r', 'utf-8') as f:
    text = f.read()

new_dialog = """  void _showTransactionDialog(DateTime selectedDate) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Thêm giao dịch',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate800),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        showBarModalBottomSheet(
                          context: context,
                          builder: (_) => IncomePage(initialDate: selectedDate),
                        ).then((_) => _fetchData(context.read<AppStore>(), _dateFrom, _dateTo));
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: AppColors.emerald50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.emerald200),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.emerald100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.arrow_downward, color: AppColors.emerald600),
                            ),
                            SizedBox(height: 12),
                            Text('Khoản thu', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.emerald700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        showBarModalBottomSheet(
                          context: context,
                          builder: (_) => ExpensePage(initialDate: selectedDate),
                        ).then((_) => _fetchData(context.read<AppStore>(), _dateFrom, _dateTo));
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: AppColors.red50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.red200),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.red100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.arrow_upward, color: AppColors.red600),
                            ),
                            SizedBox(height: 12),
                            Text('Khoản chi', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.red700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }"""

pattern = r"  void _showTransactionDialog\(DateTime selectedDate\)\s*\{.*?\n  \}\n\n  Widget _buildCalendar"

# We must replace the old _showTransactionDialog
match = re.search(pattern, text, flags=re.DOTALL)
if match:
    text = text[:match.start()] + new_dialog + "\n\n  Widget _buildCalendar" + text[match.end():]
    with codecs.open(path, 'w', 'utf-8') as f:
        f.write(text)
    print("Action dialog updated")
else:
    print("Pattern not found")
