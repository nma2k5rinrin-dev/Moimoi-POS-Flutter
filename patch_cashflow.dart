import 'dart:io';

void main() {
  final file = File('lib/features/cashflow/presentation/cashflow_page.dart');
  var content = file.readAsStringSync();

  // 1: Variable declarations & initState
  content = content.replaceFirst(
    '''  late DateTime _dateFrom;
  late DateTime _dateTo;
  // Sub-view: null = main list, 'thu' = nhập thu, 'chi' = nhập chi
  String? _subView;
  Transaction? _editTxn;

  bool _isLoading = false;
  List<OrderModel>? _customOrders;
  List<Transaction>? _customTxns;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, now.day);
    _dateTo = DateTime.now();
  }''',
    '''  late DateTime _dateFrom;
  late DateTime _dateTo;
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  // Sub-view: null = main list, 'thu' = nhập thu, 'chi' = nhập chi
  String? _subView;
  Transaction? _editTxn;

  bool _isLoading = false;
  List<OrderModel>? _customOrders;
  List<Transaction>? _customTxns;

  @override
  void initState() {
    super.initState();
    _updateDateRange();
  }

  void _updateDateRange() {
    _dateFrom = _currentMonth;
    _dateTo = DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59);
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset, 1);
      _updateDateRange();
    });
    if (mounted) {
      final store = context.read<AppStore>();
      _fetchData(store, _dateFrom, _dateTo);
    }
  }''',
  );

  // 2: _DisplayTxn class changes
  content = content.replaceFirst(
    '''  final IconData icon;''',
    '''  final String emoji;''',
  );
  content = content.replaceFirst(
    '''    required this.icon,''',
    '''    required this.emoji,''',
  );

  // 3: Paid orders mapping
  content = content.replaceFirst(
    '''          isIncome: true,
          icon: Icons.point_of_sale_rounded,
          source: 'order',''',
    '''          isIncome: true,
          emoji: '📦',
          source: 'order',''',
  );

  // 4: Manual txns mapping
  content = content.replaceFirst(
    '''          isIncome: txn.type == 'thu',
          icon: txn.type == 'thu'
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          source: txn.type == 'thu' ? 'manual_thu' : 'manual_chi',''',
    '''          isIncome: txn.type == 'thu',
          emoji: store.currentCustomThuChiCategories.firstWhere(
            (c) => c.label == txn.category,
            orElse: () => TransactionCategory(
              type: txn.type,
              emoji: txn.type == 'thu' ? '📈' : '📉',
              label: txn.category,
              color: AppColors.slate400,
              isCustom: false,
            ),
          ).emoji,
          source: txn.type == 'thu' ? 'manual_thu' : 'manual_chi',''',
  );

  // 5: Month selector UI
  content = content.replaceFirst(
    '''                                GestureDetector(
                                  onTap: () async {
                                    final picked =
                                        await showCompactDateRangePicker(
                                          context: context,
                                          initialStart: _dateFrom,
                                          initialEnd: _dateTo,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime.now(),
                                        );
                                    if (picked != null) {
                                      setState(() {
                                        _dateFrom = picked.start;
                                        _dateTo = picked.end;
                                      });
                                      _fetchData(
                                        store,
                                        picked.start,
                                        picked.end,
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.slate50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.slate200,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          size: 13,
                                          color: AppColors.emerald600,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          '\${_dateFrom.day.toString().padLeft(2, '0')}/\${_dateFrom.month.toString().padLeft(2, '0')} - \${_dateTo.day.toString().padLeft(2, '0')}/\${_dateTo.month.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.slate600,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 16,
                                          color: AppColors.slate400,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),''',
    '''                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.slate50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.slate200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                          onTap: () => _changeMonth(-1),
                                          child: const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Icon(Icons.chevron_left_rounded, size: 20, color: AppColors.slate500)
                                          )
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Tháng \${_currentMonth.month}, \${_currentMonth.year}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.slate700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                          onTap: () => _changeMonth(1),
                                          child: const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.slate500)
                                          )
                                      ),
                                    ],
                                  ),
                                ),''',
  );

  // 6: UI List Item Emoji instead of Icon
  content = content.replaceFirst(
    '''            child: Icon(
              t.icon,
              size: 20,
              color: t.isIncome ? AppColors.emerald500 : AppColors.red500,
            ),''',
    '''            child: Center(
              child: Text(
                t.emoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),''',
  );

  // 7: Button Navigations -> Popups
  content = content.replaceFirst(
    '''                        } else {
                          context.push('/nhap-thu');
                        }''',
    '''                        } else {
                          _showTransactionPopup(context, true);
                        }''',
  );
  content = content.replaceFirst(
    '''                        } else {
                          context.push('/nhap-chi');
                        }''',
    '''                        } else {
                          _showTransactionPopup(context, false);
                        }''',
  );

  // 8: _handleEdit Navigations -> Popups
  content = content.replaceFirst(
    '''  void _handleEdit(_DisplayTxn t) {
    if (t.originalTxn == null) return;
    if (widget.embedded) {
      setState(() {
        _subView = t.isIncome ? 'thu' : 'chi';
        _editTxn = t.originalTxn;
      });
      widget.onSubViewToggle?.call(true);
    } else {
      if (t.isIncome) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IncomePage(initialTransaction: t.originalTxn),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExpensePage(initialTransaction: t.originalTxn),
          ),
        );
      }
    }
  }''',
    '''  void _handleEdit(_DisplayTxn t) {
    if (t.originalTxn == null) return;
    if (widget.embedded) {
      setState(() {
        _subView = t.isIncome ? 'thu' : 'chi';
        _editTxn = t.originalTxn;
      });
      widget.onSubViewToggle?.call(true);
    } else {
      _showTransactionPopup(context, t.isIncome, txn: t.originalTxn);
    }
  }

  void _showTransactionPopup(BuildContext context, bool isIncome, {Transaction? txn}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 500,
              height: MediaQuery.of(context).size.height * 0.85,
              child: isIncome
                  ? IncomePage(embedded: true, initialTransaction: txn)
                  : ExpensePage(embedded: true, initialTransaction: txn),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    ).then((_) {
      if (!mounted) return;
      final store = context.read<AppStore>();
      _fetchData(store, _dateFrom, _dateTo);
    });
  }''',
  );

  file.writeAsStringSync(content);
}
