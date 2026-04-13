import codecs

path = 'lib/features/cashflow/presentation/cashflow_page.dart'
with codecs.open(path, 'r', 'utf-8') as f:
    c = f.read()

# 1. Update Title
c = c.replace("'Thu Chi'", "'Thu nhập/Chi tiêu'")

# 2. Update initState
c = c.replace(
    '''  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, now.day);
    _dateTo = DateTime.now();
  }''',
    '''  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchData(context.read<AppStore>(), _dateFrom, _dateTo);
      }
    });
  }'''
)

# 3. Add calendar panel
pattern1 = '''                            _buildCategoryStats(store, allTxns),
                          ],
                        ),
                      ),'''
replacement1 = '''                            _buildCategoryStats(store, allTxns),
                          ],
                        ),
                      ),
                      SizedBox(height: 14),
                      // ── Calendar Panel ──
                      _panel(
                        child: _buildCalendar(allTxns),
                      ),'''
c = c.replace(pattern1, replacement1)

# 4. Remove bottom buttons
pattern2 = '''// ── Bottom buttons ──'''
idx = c.find(pattern2)
if idx != -1:
    idx2 = c.find('''        ],
      ),
    );
  }''', idx)
    if idx2 != -1:
        c = c[:idx] + c[idx2:]

# 5. Add new methods at the end of _CashflowPageState before the final closing brace
idx_end = c.rfind('}')

methods = r'''
  void _showTransactionDialog(DateTime selectedDate) {
    FocusScope.of(context).unfocus();
    final thuKey = GlobalKey<IncomePageState>();
    final chiKey = GlobalKey<ExpensePageState>();

    showAnimatedDialog(
      context: context,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 420,
            height: 500,
            margin: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
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
                                '$day',
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
        Text('Lịch thu chi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate800)),
        SizedBox(height: 12),
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
'''

c = c[:idx_end] + methods + '\n' + c[idx_end:]

with codecs.open(path, 'w', 'utf-8') as f:
    f.write(c)
