import os

file_path = "e:/Moimoi-POS-Flutter/lib/features/cashflow/presentation/cashflow_page.dart"
with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

target_panel = """                            _buildCategoryStats(store, allTxns),
                          ],
                        ),
                      ),

                      SizedBox(height: 14),

                      // ── Panel 2: Tabs + Transactions ──"""

replacement_panel = """                            _buildCategoryStats(store, allTxns),
                          ],
                        ),
                      ),

                      SizedBox(height: 14),
                      
                      // ── Calendar Panel ──
                      _panel(
                        child: _buildCalendar(allTxns),
                      ),

                      SizedBox(height: 14),

                      // ── Panel 2: Tabs + Transactions ──"""

text = text.replace(target_panel, replacement_panel)


target_method = """class _DisplayTxn {"""

replacement_method = """  Widget _buildCalendarAmountBadge({required String label, required double amount, required bool isIncome}) {
    final background = isIncome ? AppColors.emerald50 : AppColors.red50;
    final border = isIncome ? AppColors.emerald100 : AppColors.red100;
    final accent = isIncome ? AppColors.emerald600 : AppColors.red600;
    final icon = isIncome ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    String _formatCompactAmount(double val) {
      if (val >= 1000000000) return '${(val / 1000000000).toStringAsFixed(1).replaceAll(RegExp(r'\\.0$'), '')}B';
      if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\\.0$'), '')}M';
      if (val >= 1000) return '${(val / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\\.0$'), '')}K';
      return val.toStringAsFixed(0);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 8, color: accent),
          const SizedBox(width: 2),
          Text(
            _formatCompactAmount(amount),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDialog(DateTime date) {
    if (widget.embedded) {
       setState(() {
         _subView = 'thu';
         _editTxn = null; // Ideally prepopulate with the date, but not supported out of box yet
       });
       widget.onSubViewToggle?.call(true);
    } else {
       context.push('/nhap-thu');
    }
  }

  Widget _buildCalendar(List<_DisplayTxn> txns) {
    if (_customOrders == null && _customTxns == null && _isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.emerald500));
    }
    
    final year = _dateFrom.year;
    final month = _dateFrom.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayOfMonth = DateTime(year, month, 1);
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Monday
    
    Map<int, double> incomeByDay = {};
    Map<int, double> expenseByDay = {};
    for (var t in txns) {
        if (t.date.year == year && t.date.month == month) {
            if (t.isIncome) {
                incomeByDay[t.date.day] = (incomeByDay[t.date.day] ?? 0) + t.amount;
            } else {
                expenseByDay[t.date.day] = (expenseByDay[t.date.day] ?? 0) + t.amount;
            }
        }
    }
    
    final List<Widget> cells = [];
    for (int i = 0; i < firstWeekday - 1; i++) {
        cells.add(Container(color: Colors.transparent));
    }
    
    for (int day = 1; day <= daysInMonth; day++) {
        final inc = incomeByDay[day] ?? 0.0;
        final exp = expenseByDay[day] ?? 0.0;
        final hasSummary = inc > 0 || exp > 0;
        final isSelected = _selectedDate != null && 
                           _selectedDate!.year == year && 
                           _selectedDate!.month == month && 
                           _selectedDate!.day == day;
        
        cells.add(GestureDetector(
            onTap: () {
               setState(() {
                 if (isSelected) {
                   _selectedDate = null;
                 } else {
                   _selectedDate = DateTime(year, month, day);
                 }
               });
               if (!isSelected) {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    final keyStr = "$year-$month-$day";
                    final key = _dateKeys[keyStr];
                    if (key != null && key.currentContext != null) {
                        Scrollable.ensureVisible(
                            key.currentContext!, 
                            duration: Duration(milliseconds: 300), 
                            curve: Curves.easeInOut,
                            alignment: 0.1,
                        );
                    }
                  });
               }
            },
            onDoubleTap: () => _showTransactionDialog(DateTime(year, month, day)),
            child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: isSelected ? AppColors.blue50 : AppColors.slate50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? AppColors.blue400 : AppColors.slate200, width: isSelected ? 1.5 : 1.0),
            ),
            padding: const EdgeInsets.fromLTRB(4, 4, 1, 1),
            child: Stack(
                children: [
                    Positioned(
                        top: 0,
                        left: 2,
                        child: Text(
                            '${day}',
                            style: TextStyle(
                              fontSize: 13, 
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700, 
                              color: isSelected ? AppColors.blue600 : AppColors.slate800
                            ),
                        ),
                    ),
                    if (hasSummary)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (inc > 0)
                              _buildCalendarAmountBadge(
                                label: 'Thu',
                                amount: inc,
                                isIncome: true,
                              ),
                            if (inc > 0 && exp > 0) const SizedBox(height: 1),
                            if (exp > 0)
                              _buildCalendarAmountBadge(
                                label: 'Chi',
                                amount: exp,
                                isIncome: false,
                              ),
                          ],
                        ),
                      ),
                ],
            )
        )));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Text(
                'Lịch giao dịch',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slate800),
             ),
             if (_selectedDate != null)
               Text(
                  'Đang chọn: ${_selectedDate!.day}/${_selectedDate!.month}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.blue600),
               ),
          ],
        ),
        SizedBox(height: 16),
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
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) => cells[index],
        ),
      ],
    );
  }

class _DisplayTxn {"""

text = text.replace(target_method, replacement_method)

target_item = """                                    _dateKeys.putIfAbsent(currentKeyStr, () => GlobalKey());
                                    itemKey = _dateKeys[currentKeyStr];
                                    lastDateStr = currentKeyStr;
                                  }

                                  final isSelected = _selectedDate != null && 
                                                     _selectedDate!.year == t.date.year && 
                                                     _selectedDate!.month == t.date.month && 
                                                     _selectedDate!.day == t.date.day;

                                  txnWidgets.add(Container(
                                     key: itemKey,
                                     child: _buildTransactionItem(t, isSelected: isSelected),
                                  ));"""

# Look carefully for where _dateKeys logic should be replaced or added
# In the original restored code, there is no _dateKey logic
target_tx_map = """                            if (filteredTxns.isEmpty)
                              Padding(
                                padding: EdgeInsets.all(30),
                                child: Center(
                                  child: Text(
                                    'Chưa có giao dịch',
                                    style: TextStyle(
                                      color: AppColors.slate400,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...filteredTxns.map(
                                (t) => _buildTransactionItem(t),
                              ),"""

replacement_tx_map = """                            if (filteredTxns.isEmpty)
                              Padding(
                                padding: EdgeInsets.all(30),
                                child: Center(
                                  child: Text(
                                    'Chưa có giao dịch',
                                    style: TextStyle(
                                      color: AppColors.slate400,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...(() {
                                final List<Widget> txnWidgets = [];
                                String? lastDateStr;
                                for (final t in filteredTxns) {
                                  final currentKeyStr = "${t.date.year}-${t.date.month}-${t.date.day}";
                                  Key? itemKey;
                                  if (currentKeyStr != lastDateStr) {
                                    _dateKeys.putIfAbsent(currentKeyStr, () => GlobalKey());
                                    itemKey = _dateKeys[currentKeyStr];
                                    lastDateStr = currentKeyStr;
                                  }

                                  final isSelected = _selectedDate != null && 
                                                     _selectedDate!.year == t.date.year && 
                                                     _selectedDate!.month == t.date.month && 
                                                     _selectedDate!.day == t.date.day;

                                  txnWidgets.add(Container(
                                     key: itemKey,
                                     decoration: isSelected ? BoxDecoration(
                                        color: AppColors.blue50.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(12),
                                     ) : null,
                                     child: _buildTransactionItem(t),
                                  ));
                                }
                                return txnWidgets;
                              })(),"""

text = text.replace(target_tx_map, replacement_tx_map)


with open(file_path, "w", encoding="utf-8") as f:
    f.write(text)

print("CALS SUCCESS")
