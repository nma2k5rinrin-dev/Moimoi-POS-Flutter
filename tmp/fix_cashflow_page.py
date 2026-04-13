import codecs
import re

path = r'lib\features\cashflow\presentation\cashflow_page.dart'
with codecs.open(path, 'r', 'utf-8') as f:
    c = f.read()

# 1. Title
c = c.replace("Text('Thu Chi',", "Text('Thu nhập/Chi tiêu',")

# 2. Add methods
methods_code = """
  void _showTransactionDialog(DateTime selectedDate) {
    final store = context.read<AppStore>();
    final thuKey = GlobalKey<IncomePageState>();
    final chiKey = GlobalKey<ExpensePageState>();
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: DefaultTabController(
          length: 2,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 480, maxHeight: 650),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      border: Border(bottom: BorderSide(color: AppColors.slate200)),
                    ),
                    child: TabBar(
                      indicatorColor: AppColors.emerald500,
                      indicator: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelColor: AppColors.slate800,
                      unselectedLabelColor: AppColors.slate500,
                      labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: [
                        Tab(text: 'Thu nhập'),
                        Tab(text: 'Chi tiêu'),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      children: [
                        IncomePage(
                          key: thuKey,
                          asDialog: true,
                          initialDate: selectedDate,
                          onSaved: () {
                            Navigator.pop(ctx);
                            _fetchData(context.read<AppStore>(), _dateFrom, _dateTo);
                          },
                        ),
                        ExpensePage(
                          key: chiKey,
                          asDialog: true,
                          initialDate: selectedDate,
                          onSaved: () {
                            Navigator.pop(ctx);
                            _fetchData(context.read<AppStore>(), _dateFrom, _dateTo);
                          },
                        ),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (innerCtx) => Container(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.slate200)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.slate600,
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Hủy bỏ', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              final currentIdx = DefaultTabController.of(innerCtx).index;
                              if (currentIdx == 0) {
                                thuKey.currentState?.submit();
                              } else {
                                chiKey.currentState?.submit();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald500,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(List<_DisplayTxn> txns) {
    if (_customOrders == null && _customTxns == null && _isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.emerald500));
    }
    
    final year = _dateFrom.year;
    final month = _dateFrom.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday; // 1 (Mon) - 7 (Sun)
    
    final Map<int, double> incomeByDay = {};
    final Map<int, double> expenseByDay = {};
    
    for (final t in txns) {
      if (t.date.year == year && t.date.month == month) {
        final d = t.date.day;
        if (t.isIncome) {
          incomeByDay[d] = (incomeByDay[d] ?? 0) + t.amount;
        } else {
          expenseByDay[d] = (expenseByDay[d] ?? 0) + t.amount;
        }
      }
    }

    final List<Widget> cells = [];
    for (int i = 0; i < firstWeekday - 1; i++) {
        cells.add(Container(color: Colors.transparent));
    }
    
    for (int day = 1; day <= daysInMonth; day++) {
        final inc = incomeByDay[day] ?? 0;
        final exp = expenseByDay[day] ?? 0;
        
        cells.add(GestureDetector(
            onDoubleTap: () => _showTransactionDialog(DateTime(year, month, day)),
            child: Container(
                decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.slate200),
                ),
                padding: EdgeInsets.all(4),
                child: Stack(
                    children: [
                        Positioned(
                            top: 0,
                            left: 0,
                            child: Text(
                                '${day}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate800),
                            ),
                        ),
                        Positioned(
                            bottom: 0,
                            right: 0,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    if (inc > 0)
                                        Text(
                                            _formatAmount(inc),
                                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.emerald600),
                                        ),
                                    if (exp > 0)
                                        Text(
                                            _formatAmount(exp),
                                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.red500),
                                        ),
                                ],
                            )
                        )
                    ]
                )
            )
        ));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'].map((e) => 
            Expanded(child: Center(child: Text(e, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500))))
          ).toList(),
        ),
        SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: cells.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.8,
          ),
          itemBuilder: (context, index) => cells[index],
        ),
      ],
    );
  }
"""

anchor = "}\r\n\r\nclass _DisplayTxn"
if anchor not in c:
    anchor = "}\n\nclass _DisplayTxn"

idx = c.rfind(anchor)
if idx != -1:
    c = c[:idx] + methods_code + "\n" + anchor + c[idx + len(anchor):]

# 3. Add Panels (Separate Category Stats, Calendar, and Transactions)
pattern3 = r"                            _buildCategoryStats\(store, allTxns\),\s*],\s*\),\s*\),\s*SizedBox\(height: 14\),\s*// ── Panel 2: Tabs \+ Transactions ──"

replacement3 = """                          ],
                        ),
                      ),
                      SizedBox(height: 14),
                      // ── Panel 1.5: Category Stats ──
                      _panel(
                        child: _buildCategoryStats(store, allTxns),
                      ),
                      SizedBox(height: 14),
                      // ── Calendar Panel ──
                      _panel(
                        child: _buildCalendar(allTxns),
                      ),
                      SizedBox(height: 14),
                      // ── Panel 2: Tabs + Transactions ──"""
c = re.sub(pattern3, replacement3, c)

# 4. Remove Bottom Buttons
pattern4 = r"          // ── Bottom buttons ──.*?          \),\s*\]\s*\) // Center\s*}"
c = re.sub(pattern4, "          ),\n        ]\n      ) // Center\n  }", c, flags=re.DOTALL)

with codecs.open(path, 'w', 'utf-8') as f:
    f.write(c)

print('Rewrite complete')
