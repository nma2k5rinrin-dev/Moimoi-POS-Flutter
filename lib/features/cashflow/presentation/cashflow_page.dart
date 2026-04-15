import 'dart:async' as dart_async;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/core/state/ui_store.dart';
import 'package:moimoi_pos/features/cashflow/logic/cashflow_store_standalone.dart';
import 'package:moimoi_pos/core/state/order_filter_store.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/widgets/animated_dialogs.dart';
import 'package:moimoi_pos/features/pos_order/models/order_model.dart';
import 'package:moimoi_pos/features/cashflow/models/transaction_model.dart';
import 'package:moimoi_pos/features/cashflow/models/transaction_category_model.dart';
import 'package:moimoi_pos/features/cashflow/presentation/income_page.dart';
import 'package:moimoi_pos/features/cashflow/presentation/expense_page.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:fl_chart/fl_chart.dart';
class CashflowPage extends StatefulWidget {
  final bool embedded;
  final ValueChanged<bool>? onSubViewToggle;

  const CashflowPage({super.key, this.embedded = false, this.onSubViewToggle});

  @override
  State<CashflowPage> createState() => _CashflowPageState();
}

class _CashflowPageState extends State<CashflowPage> {
  int _tabIndex = 0; // 0 = Tất cả, 1 = Thu, 2 = Chi
  late DateTime _dateFrom;
  late DateTime _dateTo;
  // Sub-view: null = main list, 'thu' = nhập thu, 'chi' = nhập chi
  String? _subView;
  Transaction? _editTxn;

  bool _isLoading = false;
  List<OrderModel>? _customOrders;
  List<Transaction>? _customTxns;
  DateTime? _selectedDate;
  final Map<String, GlobalKey> _dateKeys = {};

  List<_DisplayTxn> _allTxns = [];
  double _totalIncome = 0;
  double _totalExpense = 0;

  final ScrollController _scrollController = ScrollController();
  dart_async.StreamSubscription<String>? _scrollToTopSub;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = DateTime(now.year, now.month + 1, 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = context.read<CashflowStore>();
      _fetchData(store, _dateFrom, _dateTo);

      _scrollToTopSub = context.read<UIStore>().scrollToTopStream.listen((path) {
        if (path == '/settings?tab=cashflow' && mounted) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollToTopSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  DateTime? _parseLocal(String timeStr) {
    var s = timeStr;
    if (s.endsWith('Z')) s = s.substring(0, s.length - 1);
    final plussIdx = s.indexOf('+');
    if (plussIdx != -1) s = s.substring(0, plussIdx);
    return DateTime.tryParse(s);
  }

  void _optimisticSync() {
    final store = context.read<CashflowStore>();
    if (_customTxns == null) return;
    for (final t in store.transactions) {
      final tDate = _parseLocal(t.time);
      if (tDate == null) continue;
      if (tDate.isBefore(_dateFrom) ||
          tDate.isAfter(_dateTo.add(Duration(days: 1))))
        continue;

      final idx = _customTxns!.indexWhere((x) => x.id == t.id);
      if (idx >= 0) {
        _customTxns![idx] = t;
      } else {
        _customTxns!.add(t);
      }
    }
    setState(() {
      _processDataAnalytics(_customOrders ?? [], _customTxns!);
    });
    // Finally trigger a silent fetch to ensure correctness with backend
    _fetchData(store, _dateFrom, _dateTo, silent: true);
  }

  Future<void> _fetchData(
    CashflowStore store,
    DateTime start,
    DateTime end, {
    bool silent = false,
  }) async {
    if (!silent) {
      if (mounted) setState(() => _isLoading = true);
    }
    try {
      final endOfDay = end.add(Duration(hours: 23, minutes: 59, seconds: 59));
      
      // Dùng fetchCashflowOrdersByDateRange để lấy toàn bộ đơn hàng (minimal fields)
      // Không dùng RPC và Limit nữa để đảm bảo Calendar hiển thị đủ ngày và tổng chuẩn xác
      final results = await Future.wait([
        context.read<OrderFilterStore>().fetchCashflowOrdersByDateRange(start, endOfDay),
        store.fetchTransactionsByDateRange(start, endOfDay),
      ]);
      
      final orders = results[0] as List<OrderModel>;
      final txns = results[1] as List<Transaction>;

      _processDataAnalytics(orders, txns);

      if (mounted) {
        setState(() {
          _customOrders = orders;
          _customTxns = txns;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        store.showToast('Lỗi tải dữ liệu: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _processDataAnalytics(
    List<OrderModel> sourceOrders,
    List<Transaction> sourceTxns,
  ) {
    final List<_DisplayTxn> newTxns = [];
    double calcTotalIncome = 0.0;
    double calcTotalExpense = 0.0;

    final paidOrders = sourceOrders
        .where((o) => o.paymentStatus == 'paid' && o.status != 'cancelled')
        .toList();

    for (final order in paidOrders) {
      final orderDate = _parseLocal(order.time);
      if (orderDate == null) continue;
      if (orderDate.isBefore(_dateFrom) ||
          orderDate.isAfter(_dateTo.add(Duration(days: 1)))) {
        continue;
      }

      final String subtitle = order.table.isNotEmpty ? order.table : 'Mang về';

      newTxns.add(
        _DisplayTxn(
          title: 'Đơn hàng ${order.id}',
          subtitle: subtitle,
          category: 'Doanh thu',
          date: orderDate,
          amount: order.totalAmount,
          isIncome: true,
          icon: Icons.point_of_sale_rounded,
          source: 'order',
        ),
      );
      calcTotalIncome += order.totalAmount;
    }

    for (final txn in sourceTxns) {
      final txnDate = _parseLocal(txn.time);
      if (txnDate == null) continue;
      if (txnDate.isBefore(_dateFrom) ||
          txnDate.isAfter(_dateTo.add(Duration(days: 1)))) {
        continue;
      }
      newTxns.add(
        _DisplayTxn(
          id: txn.id,
          title: txn.category,
          subtitle: txn.note.isNotEmpty ? txn.note : null,
          category: txn.category,
          date: txnDate,
          amount: txn.amount,
          isIncome: txn.type == 'thu',
          icon: txn.type == 'thu'
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          source: txn.type == 'thu' ? 'manual_thu' : 'manual_chi',
          originalTxn: txn,
        ),
      );
      if (txn.type == 'thu') {
        calcTotalIncome += txn.amount;
      } else {
        calcTotalExpense += txn.amount;
      }
    }

    newTxns.sort((a, b) => b.date.compareTo(a.date));

    _allTxns = newTxns;
    // Đồng bộ chuẩn giá trị trực tiếp từ danh sách full, vì RPC đếm sai transactions
    _totalIncome = calcTotalIncome;
    _totalExpense = calcTotalExpense;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CashflowStore>();

    // If embedded and showing a sub-view, render inline
    if (widget.embedded && _subView != null) {
      if (_subView == 'thu') {
        return IncomePage(
          embedded: true,
          initialTransaction: _editTxn,
          onBack: () {
            setState(() {
              _subView = null;
              _editTxn = null;
            });
            widget.onSubViewToggle?.call(false);
          },
        );
      } else {
        return ExpensePage(
          embedded: true,
          initialTransaction: _editTxn,
          onBack: () {
            setState(() {
              _subView = null;
              _editTxn = null;
            });
            widget.onSubViewToggle?.call(false);
          },
        );
      }
    }

    // ── Build unified transaction list ───────────────────
    List<_DisplayTxn> allTxns = _allTxns;

    if (_isLoading && allTxns.isEmpty) {
      allTxns = List.generate(
        3,
        (index) => _DisplayTxn(
          title: 'Đang tải dữ liệu...',
          subtitle: 'Vui lòng chờ giây lát',
          category: 'Đang tải',
          date: DateTime.now().subtract(Duration(days: index)),
          amount: (index + 1) * 100000.0,
          isIncome: index % 2 == 0,
          icon: Icons.sync,
          source: 'loading',
        ),
      );
    }

    // Filter by tab
    List<_DisplayTxn> filteredTxns;
    if (_tabIndex == 1) {
      filteredTxns = allTxns.where((t) => t.isIncome).toList();
    } else if (_tabIndex == 2) {
      filteredTxns = allTxns.where((t) => !t.isIncome).toList();
    } else {
      filteredTxns = List.from(allTxns);
    }

    bool isListCapped = false;

    // Filter by selected date
    if (_selectedDate != null) {
      filteredTxns = filteredTxns
          .where(
            (t) =>
                t.date.year == _selectedDate!.year &&
                t.date.month == _selectedDate!.month &&
                t.date.day == _selectedDate!.day,
          )
          .toList();
    } else {
      if (filteredTxns.length > 5) {
        filteredTxns = filteredTxns.take(5).toList();
        isListCapped = true;
      }
    }

    // Calculate totals from cached state
    final totalIncome = _isLoading ? 0.0 : _totalIncome;
    final totalExpense = _isLoading ? 0.0 : _totalExpense;
    final balance = totalIncome - totalExpense;

    List<FlSpot> buildSpots(bool forIncome, bool forExpense) {
      if (_isLoading || allTxns.isEmpty) {
        return const [FlSpot(0, 0.5), FlSpot(1, 1), FlSpot(2, 0.8)];
      }

      final daysInMonth = DateTime(_dateFrom.year, _dateFrom.month + 1, 0).day;
      final dailyValues = List<double>.filled(daysInMonth, 0.0);

      for (final t in allTxns) {
        if (t.date.year == _dateFrom.year && t.date.month == _dateFrom.month) {
          final dayIdx = t.date.day - 1;
          if (forIncome && forExpense) {
               if (t.isIncome) dailyValues[dayIdx] += t.amount;
               else dailyValues[dayIdx] -= t.amount;
          } else if (forIncome && t.isIncome) {
             dailyValues[dayIdx] += t.amount;
          } else if (forExpense && !t.isIncome) {
             dailyValues[dayIdx] += t.amount;
          }
        }
      }

      if (forIncome && forExpense) {
         double cum = 0;
         for (int i=0; i<daysInMonth; i++) {
            cum += dailyValues[i];
            dailyValues[i] = cum;
         }
      }

      final spots = <FlSpot>[];
      for (int i=0; i<daysInMonth; i++) {
        spots.add(FlSpot(i.toDouble(), dailyValues[i]));
      }

      return spots;
    }
    
    final balanceSpots = buildSpots(true, true);
    final incomeSpots = buildSpots(true, false);
    final expenseSpots = buildSpots(false, true);

    return Container(
      color: AppColors.slate50,
      child: Column(
        children: [
          // ── Header (only when not embedded) ──
          if (!widget.embedded)
            Container(
              padding: EdgeInsets.fromLTRB(9, 12, 9, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.amber50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 22,
                      color: AppColors.amber500,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thu nhập/Chi tiêu',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Quản lý thu nhập & chi phí',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (!widget.embedded) SizedBox(height: 4),

          // ── Content ──
          Expanded(
            child: Skeletonizer(
              enabled: _isLoading,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.embedded ? 9 : 9,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: widget.embedded ? 600 : 700,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),

                      // ── Month Navigation ──
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  _dateFrom = DateTime(
                                    _dateFrom.year,
                                    _dateFrom.month - 1,
                                    1,
                                  );
                                  _dateTo = DateTime(
                                    _dateFrom.year,
                                    _dateFrom.month + 1,
                                    0,
                                  );
                                  _selectedDate = null;
                                });
                                _fetchData(
                                  context.read<CashflowStore>(),
                                  _dateFrom,
                                  _dateTo,
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.slate200),
                                ),
                                child: Icon(
                                  Icons.chevron_left_rounded,
                                  size: 24,
                                  color: AppColors.slate600,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            GestureDetector(
                              onTap: () async {
                                int selectedYear = _dateFrom.year;
                                int selectedMonth = _dateFrom.month;
                                final result = await showAnimatedDialog<DateTime>(
                                  context: context,
                                  builder: (ctx) => StatefulBuilder(
                                    builder: (ctx, setDialogState) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      insetPadding: EdgeInsets.all(24),
                                      child: Container(
                                        width: double.infinity,
                                        constraints: BoxConstraints(
                                          maxWidth: 480,
                                        ),
                                        padding: EdgeInsets.fromLTRB(
                                          20,
                                          20,
                                          20,
                                          24,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardBg,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.15,
                                              ),
                                              blurRadius: 24,
                                              offset: Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                IconButton(
                                                  iconSize: 28,
                                                  padding: EdgeInsets.all(8),
                                                  icon: Icon(
                                                    Icons.chevron_left,
                                                    color: AppColors.slate600,
                                                  ),
                                                  onPressed: () =>
                                                      setDialogState(
                                                        () => selectedYear--,
                                                      ),
                                                ),
                                                Text(
                                                  selectedYear.toString(),
                                                  style: TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.slate800,
                                                  ),
                                                ),
                                                IconButton(
                                                  iconSize: 28,
                                                  padding: EdgeInsets.all(8),
                                                  icon: Icon(
                                                    Icons.chevron_right,
                                                    color: AppColors.slate600,
                                                  ),
                                                  onPressed: () =>
                                                      setDialogState(
                                                        () => selectedYear++,
                                                      ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 24),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 12,
                                              alignment: WrapAlignment.center,
                                              children: List.generate(12, (i) {
                                                final m = i + 1;
                                                final sel = m == selectedMonth;
                                                return GestureDetector(
                                                  onTap: () {
                                                    setDialogState(
                                                      () => selectedMonth = m,
                                                    );
                                                    Navigator.pop(
                                                      ctx,
                                                      DateTime(
                                                        selectedYear,
                                                        m,
                                                        1,
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    width: 90,
                                                    height: 66,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      color: sel
                                                          ? AppColors.emerald500
                                                          : AppColors.slate50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                      border: Border.all(
                                                        color: sel
                                                            ? AppColors
                                                                  .emerald500
                                                            : AppColors
                                                                  .slate200,
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      'Tháng $m',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        color: sel
                                                            ? Colors.white
                                                            : AppColors
                                                                  .slate700,
                                                        fontWeight: sel
                                                            ? FontWeight.w800
                                                            : FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                                if (result != null) {
                                  setState(() {
                                    _dateFrom = DateTime(
                                      result.year,
                                      result.month,
                                      1,
                                    );
                                    _dateTo = DateTime(
                                      result.year,
                                      result.month + 1,
                                      0,
                                    );
                                    _selectedDate = null;
                                  });
                                  _fetchData(
                                    context.read<CashflowStore>(),
                                    _dateFrom,
                                    _dateTo,
                                  );
                                }
                              },
                              child: Text(
                                'Tháng ${_dateFrom.month}, ${_dateFrom.year}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.slate800,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  _dateFrom = DateTime(
                                    _dateFrom.year,
                                    _dateFrom.month + 1,
                                    1,
                                  );
                                  _dateTo = DateTime(
                                    _dateFrom.year,
                                    _dateFrom.month + 1,
                                    0,
                                  );
                                  _selectedDate = null;
                                });
                                _fetchData(
                                  context.read<CashflowStore>(),
                                  _dateFrom,
                                  _dateTo,
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.slate200),
                                ),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 24,
                                  color: AppColors.slate600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      // ── Stats (Số dư | Thu nhập | Chi tiêu) ──
                      Row(
                        children: [
                          Expanded(
                            child: _SparklineCard(
                              title: 'SỐ DƯ HIỆN TẠI',
                              value: '${balance >= 0 ? '+' : ''}${_formatAmount(balance)}',
                              accentColor: Color(0xFF3B82F6),
                              spots: balanceSpots.map((e) => e.y).toList(),
                              isGradientValue: true,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _SparklineCard(
                              title: 'THU NHẬP',
                              value: _formatAmount(totalIncome),
                              accentColor: Color(0xFF10B981),
                              spots: incomeSpots.map((e) => e.y).toList(),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _SparklineCard(
                              title: 'CHI TIÊU',
                              value: _formatAmount(totalExpense),
                              accentColor: Color(0xFFEF4444),
                              spots: expenseSpots.map((e) => e.y).toList(),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14),

                      // ── Calendar Panel ──
                      _panel(
                        padding: EdgeInsets.all(0), // Reduced from 8 to 0 to fill all space
                        child: Column(
                          children: [
                            _buildCalendar(allTxns),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.touch_app_rounded, size: 14, color: AppColors.slate400),
                                  SizedBox(width: 6),
                                  Text(
                                    'Bấm đúp (2 lần) vào ngày để thêm giao dịch',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.slate500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 14),
                      _buildCategoryStats(store, allTxns),
                      SizedBox(height: 14),

                      // ── Panel 2: Tabs + Transactions ──
                      _panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.slate100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  _buildTab('Tất cả', 0),
                                  _buildTab('Thu', 1),
                                  _buildTab('Chi', 2),
                                ],
                              ),
                            ),
                            SizedBox(height: 18),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${filteredTxns.length} giao dịch',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate800,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            if (filteredTxns.isNotEmpty)
                              Center(
                                child: Text(
                                  '* Chọn giao dịch bất kỳ, vuốt sang trái để sửa',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.slate500,
                                  ),
                                ),
                              ),
                            SizedBox(height: 12),

                            if (filteredTxns.isEmpty)
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
                                final Set<String> _renderedKeys = {};
                                for (final t in filteredTxns) {
                                  final currentKeyStr =
                                      "${t.date.year}-${t.date.month}-${t.date.day}";
                                  
                                  if (!_renderedKeys.contains(currentKeyStr)) {
                                    _dateKeys.putIfAbsent(
                                      currentKeyStr,
                                      () => GlobalKey(),
                                    );
                                    _renderedKeys.add(currentKeyStr);
                                    
                                    // Insert an invisible anchor element for the GlobalKey.
                                    // This prevents the element._lifecycleState assertion crash caused
                                    // by attaching the GlobalKey to the dynamic Container below.
                                    txnWidgets.add(
                                      SizedBox(
                                        key: _dateKeys[currentKeyStr],
                                        height: 0,
                                      )
                                    );
                                  }

                                  final isSelected =
                                      _selectedDate != null &&
                                      _selectedDate!.year == t.date.year &&
                                      _selectedDate!.month == t.date.month &&
                                      _selectedDate!.day == t.date.day;

                                  txnWidgets.add(
                                    Container(
                                      decoration: isSelected
                                          ? BoxDecoration(
                                              color: AppColors.blue50
                                                  .withOpacity(0.5),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            )
                                          : null,
                                      child: _buildTransactionItem(t),
                                    ),
                                  );
                                }
                                if (isListCapped)
                                  txnWidgets.add(
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '* Đã giới hạn hiển thị 5 giao dịch mới nhất.\nChọn một ngày trên lịch để tra cứu thêm.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppColors.slate500,
                                            fontSize: 13,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                return txnWidgets;
                              })(),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCategoryStats(CashflowStore store, List<_DisplayTxn> txns) {
    if (txns.isEmpty) return SizedBox.shrink();

    // Filter txns based on current active tab: 0=All, 1=Thu, 2=Chi. But actually we want to show stats of whatever is passing.
    // Let's rely on txns, which is `allTxns` passed in. Wait, allTxns includes everything. Let's filter by _tabIndex locally if needed,
    // or just show total Thu, total Chi. Actually, separate lists!
    final List<_DisplayTxn> statTxns;
    if (_tabIndex == 1) {
      statTxns = txns.where((t) => t.isIncome).toList();
    } else if (_tabIndex == 2) {
      statTxns = txns.where((t) => !t.isIncome).toList();
    } else {
      statTxns = txns;
    }

    if (statTxns.isEmpty) return SizedBox.shrink();

    final customCats = store.currentCustomThuChiCategories;
    final List<TransactionCategory> allKnownCats = [
      TransactionCategory(
        type: 'thu',
        emoji: '🎉',
        label: 'Doanh thu',
        color: AppColors.emerald500,
        isCustom: false,
      ),
      TransactionCategory(
        type: 'thu',
        emoji: '+',
        label: 'Thêm mới',
        color: AppColors.slate400,
        isCustom: false,
      ),
      TransactionCategory(
        type: 'chi',
        emoji: '+',
        label: 'Thêm mới',
        color: AppColors.slate400,
        isCustom: false,
      ),
      ...customCats,
    ];

    final Map<String, double> categoryTotals = {};
    for (final t in statTxns) {
      final key = t.category;
      if (key.isEmpty) continue;
      categoryTotals[key] = (categoryTotals[key] ?? 0) + t.amount;
    }

    if (categoryTotals.isEmpty) return SizedBox.shrink();

    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxTotal = sortedEntries.first.value > 0
        ? sortedEntries.first.value
        : 1.0;

    final displayEntries = sortedEntries.take(5).toList();
    final hasMore = sortedEntries.length > 5;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thống kê theo danh mục',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.slate800,
            ),
          ),
          SizedBox(height: 16),
          ...displayEntries.map(
            (e) => _buildCategoryStatRow(e, allKnownCats, maxTotal),
          ),
          if (hasMore)
            Center(
              child: TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => Dialog(
                      backgroundColor: AppColors.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 400,
                          maxHeight: MediaQuery.of(context).size.height * 0.8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Tất cả danh mục',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.slate800,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: AppColors.slate500,
                                    ),
                                    onPressed: () => Navigator.pop(ctx),
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, color: AppColors.slate200),
                            Flexible(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: sortedEntries
                                      .map(
                                        (e) => _buildCategoryStatRow(
                                          e,
                                          allKnownCats,
                                          maxTotal,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.emerald600,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  'Xem thêm',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryStatRow(
    MapEntry<String, double> e,
    List<TransactionCategory> allKnownCats,
    double maxTotal,
  ) {
    final catLabel = e.key;
    final total = e.value;
    final fraction = total / maxTotal;

    final matchedCat = allKnownCats.firstWhere(
      (c) => c.label == catLabel,
      orElse: () => TransactionCategory(
        type: 'thu',
        emoji: '🏷️',
        label: catLabel,
        color: AppColors.slate400,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: matchedCat.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(matchedCat.emoji, style: TextStyle(fontSize: 18)),
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
                          color: AppColors.slate800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction.clamp(0.0, 1.0),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: matchedCat.color,
                          borderRadius: BorderRadius.circular(3),
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
  }

  Widget _buildTab(String label, int index) {
    final isActive = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? AppColors.cardBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              color: isActive ? AppColors.slate800 : AppColors.slate500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(_DisplayTxn t) {
    final dateStr =
        '${t.date.day.toString().padLeft(2, '0')}/${t.date.month.toString().padLeft(2, '0')}/${t.date.year}  •  ${t.date.hour.toString().padLeft(2, '0')}:${t.date.minute.toString().padLeft(2, '0')}';
    final sourceLabel = t.source == 'order'
        ? 'Doanh thu'
        : t.source == 'manual_thu'
        ? 'Nhập thu'
        : 'Nhập chi';
    final isMatchingDate =
        _selectedDate != null &&
        _selectedDate!.year == t.date.year &&
        _selectedDate!.month == t.date.month &&
        _selectedDate!.day == t.date.day;

    final card = AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMatchingDate ? AppColors.blue50 : AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMatchingDate ? AppColors.blue400 : AppColors.slate100,
          width: isMatchingDate ? 1.5 : 1.0,
        ),
        boxShadow: isMatchingDate
            ? [
                BoxShadow(
                  color: AppColors.blue200.withOpacity(0.5),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.isIncome ? AppColors.emerald50 : AppColors.red50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              t.icon,
              size: 20,
              color: t.isIncome ? AppColors.emerald500 : AppColors.red500,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (t.subtitle != null && t.subtitle!.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    t.subtitle!,
                    style: TextStyle(fontSize: 12, color: AppColors.slate500),
                  ),
                ],
                SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 11, color: AppColors.slate400),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: t.source == 'order'
                            ? AppColors.blue50
                            : t.isIncome
                            ? AppColors.emerald50
                            : AppColors.red50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        sourceLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: t.source == 'order'
                              ? AppColors.blue600
                              : t.isIncome
                              ? AppColors.emerald600
                              : AppColors.red500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Text(
            '${t.isIncome ? '+' : '-'}${_formatAmount(t.amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: t.isIncome ? AppColors.emerald600 : AppColors.red500,
            ),
          ),
          if (t.source != 'order' && t.originalTxn != null) ...[
             SizedBox(width: 8),
             Icon(Icons.chevron_left_rounded, color: AppColors.slate400),
          ],
        ],
      ),
    );

    if (t.source == 'order' || t.originalTxn == null) {
      return Padding(padding: EdgeInsets.only(bottom: 10), child: card);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: ValueKey(t.id ?? UniqueKey().toString()),
        endActionPane: ActionPane(
          motion: DrawerMotion(),
          extentRatio: 0.45,
          children: [
            SlidableAction(
              onPressed: (context) => _handleEdit(t),
              backgroundColor: AppColors.blue500,
              foregroundColor: Colors.white,
              icon: Icons.edit_rounded,
              label: 'Sửa',
            ),
            SlidableAction(
              onPressed: (context) => _handleDelete(t),
              backgroundColor: AppColors.red500,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline_rounded,
              label: 'Xóa',
              borderRadius: BorderRadius.horizontal(right: Radius.circular(14)),
            ),
          ],
        ),
        child: card,
      ),
    );
  }

  void _handleEdit(_DisplayTxn t) {
    if (t.originalTxn == null) return;
    _showEditTransactionDialog(t);
  }

  void _showEditTransactionDialog(_DisplayTxn t) {
    FocusScope.of(context).unfocus();
    final isThu = t.isIncome;
    final thuKey = GlobalKey<IncomePageState>();
    final chiKey = GlobalKey<ExpensePageState>();

    showAnimatedDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isThu ? AppColors.emerald50 : AppColors.red50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.edit_document,
                        color: isThu ? AppColors.emerald500 : AppColors.red500,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isThu ? 'Sửa khoản thu' : 'Sửa khoản chi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate800,
                            ),
                          ),
                          Text(
                            'Chỉnh sửa thông tin giao dịch',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: isThu
                    ? IncomePage(
                        key: thuKey,
                        asDialog: true,
                        initialTransaction: t.originalTxn,
                        onSaved: () {
                          Navigator.pop(ctx);
                          _optimisticSync();
                        },
                      )
                    : ExpensePage(
                        key: chiKey,
                        asDialog: true,
                        initialTransaction: t.originalTxn,
                        onSaved: () {
                          Navigator.pop(ctx);
                          _optimisticSync();
                        },
                      ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.slate200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.slate100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'Hủy bỏ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.slate600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (isThu) {
                            thuKey.currentState?.submit();
                          } else {
                            chiKey.currentState?.submit();
                          }
                        },
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isThu
                                ? AppColors.emerald500
                                : AppColors.red500,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'Lưu',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDelete(_DisplayTxn t) {
    final store = context.read<CashflowStore>();
    context.read<UIStore>().showConfirm(
      'Bạn có chắc chắn muốn xóa giao dịch này? Số dư sẽ được cập nhật lại.',
      () {
        if (t.id != null) {
          store.deleteTransaction(t.id!);
          store.showToast('Đã xóa giao dịch');
          if (mounted) {
            setState(() {
              if (_customTxns != null) {
                _customTxns!.removeWhere((x) => x.id == t.id);
                _processDataAnalytics(_customOrders ?? [], _customTxns!);
              }
            });
            _fetchData(store, _dateFrom, _dateTo, silent: true);
          }
        }
      },
      title: 'Xóa giao dịch',
      confirmLabel: 'Xóa',
    );
  }

  String _formatAmount(double amount) {
    final abs = amount.abs();
    return abs
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  Widget _buildCalendarAmountBadge({
    required String label,
    required double amount,
    required bool isIncome,
    bool center = false,
  }) {
    final accent = isIncome ? AppColors.emerald600 : AppColors.red600;

    return Container(
      constraints: const BoxConstraints(maxWidth: 52),
      alignment: center ? Alignment.center : Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: center ? Alignment.center : Alignment.centerRight,
        child: Text(
          _formatAmount(amount),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
      ),
    );
  }

  Widget _buildSparkline({required Color color, required List<FlSpot> spots}) {
    double minX = 0;
    double maxX = spots.length > 1 ? spots.last.x : 6;
    double minY = 0;
    double maxY = 10;
    
    if (spots.isNotEmpty) {
      minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      if (minY == maxY) {
        minY -= 1;
        maxY += 1;
      } else {
        final padding = (maxY - minY) * 0.2;
        minY -= padding;
        maxY += padding;
      }
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActionChoiceDialog(DateTime date) {
    FocusScope.of(context).unfocus();
    final thuKey = GlobalKey<IncomePageState>();
    final chiKey = GlobalKey<ExpensePageState>();

    showAnimatedDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: DefaultTabController(
            length: 2,
            child: Builder(
              builder: (ctx) {
                final tabCtrl = DefaultTabController.of(ctx);
                return AnimatedBuilder(
                  animation: tabCtrl,
                  builder: (context, child) {
                    final isThu = tabCtrl.index == 1;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isThu
                                      ? AppColors.emerald50
                                      : AppColors.red50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isThu
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  color: isThu
                                      ? AppColors.emerald500
                                      : AppColors.red500,
                                  size: 22,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isThu
                                          ? 'Nhập khoản thu'
                                          : 'Nhập khoản chi',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.slate800,
                                      ),
                                    ),
                                    Text(
                                      isThu
                                          ? 'Thêm giao dịch thu mới'
                                          : 'Thêm giao dịch chi mới',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.slate100, // Background capsule
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerHeight: 0,
                            indicator: BoxDecoration(
                              color: AppColors.cardBg != Colors.white
                                  ? AppColors
                                        .slate300 // Lighter grey for active dark pill
                                  : Colors.white, // White for active light pill
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: AppColors.cardBg != Colors.white
                                  ? [] // Flat for dark mode
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ), // Soft shadow for light mode
                                    ],
                            ),
                            labelColor: AppColors.cardBg != Colors.white
                                ? Colors.white
                                : AppColors.slate900,
                            unselectedLabelColor: AppColors.slate500,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            tabs: [
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.trending_down,
                                      size: 16,
                                      color: AppColors.red500,
                                    ),
                                    SizedBox(width: 6),
                                    Text('Nhập chi'),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.trending_up,
                                      size: 16,
                                      color: AppColors.emerald500,
                                    ),
                                    SizedBox(width: 6),
                                    Text('Nhập thu'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        Expanded(
                          child: TabBarView(
                            children: [
                              ExpensePage(
                                key: chiKey,
                                asDialog: true,
                                initialDate: date,
                                onSaved: () {
                                  Navigator.pop(ctx);
                                  _optimisticSync();
                                },
                              ),
                              IncomePage(
                                key: thuKey,
                                asDialog: true,
                                initialDate: date,
                                onSaved: () {
                                  Navigator.pop(ctx);
                                  _optimisticSync();
                                },
                              ),
                            ],
                          ),
                        ),
                        Builder(
                          builder: (innerCtx) => Container(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: AppColors.slate200),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(ctx),
                                    child: Container(
                                      height: 52,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.slate100,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        'Hủy bỏ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.slate600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      final currentIdx =
                                          DefaultTabController.of(
                                            innerCtx,
                                          ).index;
                                      if (currentIdx == 0) {
                                        thuKey.currentState?.submit();
                                      } else {
                                        chiKey.currentState?.submit();
                                      }
                                    },
                                    child: Container(
                                      height: 52,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isThu
                                            ? AppColors.emerald500
                                            : AppColors.red500,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        'Lưu',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ), // closes Builder
          ), // closes DefaultTabController
        ), // closes Container
      ), // closes Dialog
    ); // closes showAnimatedDialog
  }

  Widget _buildCalendar(List<_DisplayTxn> txns) {
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
      cells.add(Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: AppColors.slate200, width: 0.5),
            bottom: BorderSide(color: AppColors.slate200, width: 0.5),
          ),
        ),
      ));
    }

    final now = DateTime.now();

    for (int day = 1; day <= daysInMonth; day++) {
      final double inc = _isLoading ? 100000.0 : (incomeByDay[day] ?? 0.0);
      final double exp = _isLoading ? 100000.0 : (expenseByDay[day] ?? 0.0);
      final bool hasSummary = _isLoading || (inc > 0 || exp > 0);
      final isSelected =
          _selectedDate != null &&
          _selectedDate!.year == year &&
          _selectedDate!.month == month &&
          _selectedDate!.day == day;
      final isToday = now.year == year && now.month == month && now.day == day;

      cells.add(
        GestureDetector(
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
          onDoubleTap: () =>
              _showActionChoiceDialog(DateTime(year, month, day)),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.blue50 : (isToday ? AppColors.slate50 : AppColors.cardBg),
              border: isSelected
                  ? Border.all(color: AppColors.blue500, width: 1.5)
                  : Border(
                      right: BorderSide(color: AppColors.slate200, width: 0.5),
                      bottom: BorderSide(color: AppColors.slate200, width: 0.5),
                    ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${day}',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.1,
                    fontWeight: isSelected || isToday ? FontWeight.w900 : FontWeight.w600,
                    color: isToday || isSelected ? AppColors.blue600 : AppColors.slate800,
                  ),
                ),
                if (inc > 0)
                  _buildCalendarAmountBadge(
                    label: 'Thu',
                    amount: inc,
                    isIncome: true,
                    center: true,
                  ),
                if (exp > 0)
                  _buildCalendarAmountBadge(
                    label: 'Chi',
                    amount: exp,
                    isIncome: false,
                    center: true,
                  ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Fill trailing empty cells to complete the grid row
    int totalCells = cells.length;
    while (totalCells % 7 != 0) {
      cells.add(Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: AppColors.slate200, width: 0.5),
            bottom: BorderSide(color: AppColors.slate200, width: 0.5),
          ),
        ),
      ));
      totalCells++;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_selectedDate != null) {
          setState(() => _selectedDate = null);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // removed header Row per user request
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                .map(
                  (e) => Expanded(
                    child: Center(
                      child: Text(
                        e,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate500,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.slate200, width: 0.5),
                left: BorderSide(color: AppColors.slate200, width: 0.5),
              ),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: cells.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 0,
                crossAxisSpacing: 0,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, index) => cells[index],
            ),
          ),
        ],
      ),
    );
  }
}

class _DisplayTxn {
  final String? id;
  final String title;
  final String? subtitle;
  final String category;
  final DateTime date;
  final double amount;
  final bool isIncome;
  final IconData icon;
  final String source;
  final Transaction? originalTxn;

  _DisplayTxn({
    this.id,
    required this.title,
    this.subtitle,
    this.category = '',
    required this.date,
    required this.amount,
    required this.isIncome,
    required this.icon,
    required this.source,
    this.originalTxn,
  });
}

class _SparklineCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accentColor;
  final List<double> spots;
  final bool isGradientValue;

  const _SparklineCard({
    required this.title,
    required this.value,
    required this.accentColor,
    required this.spots,
    this.isGradientValue = false,
  });

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) spots.add(0);
    double maxVal = spots.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 1;

    List<FlSpot> flSpots = [];
    for (int i = 0; i < spots.length; i++) {
      flSpots.add(FlSpot(i.toDouble(), spots[i]));
    }

    return Container(
      height: 94,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          colors: [Colors.white, accentColor.withValues(alpha: 0.15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          // Background soft line chart
          Positioned(
            bottom: -2,
            left: 0,
            right: 0,
            height: 50,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (spots.length - 1).toDouble() > 0 ? (spots.length - 1).toDouble() : 1,
                minY: 0,
                maxY: maxVal * 1.5,
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: flSpots,
                    isCurved: true,
                    color: accentColor.withValues(alpha: 0.6),
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.3),
                          accentColor.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Foreground Text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Icon(Icons.analytics_rounded, size: 10, color: accentColor),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate700,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                isGradientValue
                    ? ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                        ).createShader(bounds),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slate800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
