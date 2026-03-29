import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/core/state/app_store.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/utils/quota_helper.dart';
import 'package:moimoi_pos/features/premium/presentation/widgets/upgrade_dialog.dart';
import 'package:moimoi_pos/core/widgets/date_range_picker_dialog.dart';
import 'package:moimoi_pos/features/thu_chi/presentation/nhap_thu_page.dart';
import 'package:moimoi_pos/features/thu_chi/presentation/nhap_chi_page.dart';

class ThuChiPage extends StatefulWidget {
  final bool embedded;
  const ThuChiPage({super.key, this.embedded = false});

  @override
  State<ThuChiPage> createState() => _ThuChiPageState();
}

class _ThuChiPageState extends State<ThuChiPage> {
  int _tabIndex = 0; // 0 = Tất cả, 1 = Thu, 2 = Chi
  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo = DateTime.now();
  // Sub-view: null = main list, 'thu' = nhập thu, 'chi' = nhập chi
  String? _subView;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    // If embedded and showing a sub-view, render inline
    if (widget.embedded && _subView != null) {
      if (_subView == 'thu') {
        return NhapThuPage(
          embedded: true,
          onBack: () => setState(() => _subView = null),
        );
      } else {
        return NhapChiPage(
          embedded: true,
          onBack: () => setState(() => _subView = null),
        );
      }
    }

    // ── Build unified transaction list ───────────────────
    final List<_DisplayTxn> allTxns = [];

    // 1. Completed+paid orders → income (store revenue)
    final completedOrders = store.orders.where(
            (o) => o.status == 'completed' && o.paymentStatus == 'paid')
        .toList();

    for (final order in completedOrders) {
      final orderDate = DateTime.tryParse(order.time);
      if (orderDate == null) continue;
      if (orderDate.isBefore(_dateFrom) ||
          orderDate.isAfter(_dateTo.add(const Duration(days: 1)))) {
        continue;
      }
      allTxns.add(_DisplayTxn(
        title: 'Đơn hàng ${order.id}',
        date: orderDate,
        amount: order.totalAmount,
        isIncome: true,
        icon: Icons.point_of_sale_rounded,
        source: 'order',
      ));
    }

    // 2. Manual thu/chi transactions
    for (final txn in store.transactions) {
      final txnDate = DateTime.tryParse(txn.time);
      if (txnDate == null) continue;
      if (txnDate.isBefore(_dateFrom) ||
          txnDate.isAfter(_dateTo.add(const Duration(days: 1)))) {
        continue;
      }
      allTxns.add(_DisplayTxn(
        title: txn.note.isNotEmpty ? txn.note : txn.category,
        date: txnDate,
        amount: txn.amount,
        isIncome: txn.type == 'thu',
        icon: txn.type == 'thu'
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded,
        source: txn.type == 'thu' ? 'manual_thu' : 'manual_chi',
      ));
    }

    // Sort by date descending
    allTxns.sort((a, b) => b.date.compareTo(a.date));

    // Filter by tab
    final List<_DisplayTxn> filteredTxns;
    if (_tabIndex == 1) {
      filteredTxns = allTxns.where((t) => t.isIncome).toList();
    } else if (_tabIndex == 2) {
      filteredTxns = allTxns.where((t) => !t.isIncome).toList();
    } else {
      filteredTxns = allTxns;
    }

    // Calculate totals
    final totalIncome =
        allTxns.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amount);
    final totalExpense =
        allTxns.where((t) => !t.isIncome).fold(0.0, (s, t) => s + t.amount);
    final balance = totalIncome - totalExpense;

    return Container(
      color: widget.embedded ? Colors.transparent : AppColors.slate50,
      child: Column(
        children: [
          // ── Header (only when not embedded) ──
          if (!widget.embedded)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.amber50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      size: 22, color: AppColors.amber500),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Thu Chi',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                              color: AppColors.slate800)),
                      SizedBox(height: 2),
                      Text('Quản lý thu nhập & chi phí',
                          style: TextStyle(fontSize: 12, color: AppColors.slate500)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (!widget.embedded)
          const SizedBox(height: 4),

          // ── Content ──
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: widget.embedded ? 20 : 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.embedded ? 600 : 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),

                    // ── Panel 1: Overview ──
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text('Tổng quan thu nhập',
                                  style: TextStyle(fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.slate800)),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showCompactDateRangePicker(
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
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.slate50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.slate200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today_rounded,
                                          size: 13, color: AppColors.emerald600),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_dateFrom.day.toString().padLeft(2, '0')}/${_dateFrom.month.toString().padLeft(2, '0')} - ${_dateTo.day.toString().padLeft(2, '0')}/${_dateTo.month.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.slate600)),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.keyboard_arrow_down_rounded,
                                          size: 16, color: AppColors.slate400),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Income / Expense cards
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.emerald100),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Icon(Icons.trending_up_rounded,
                                            size: 16, color: AppColors.emerald500),
                                        const SizedBox(width: 6),
                                        const Text('Thu',
                                            style: TextStyle(fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.emerald600)),
                                      ]),
                                      const SizedBox(height: 6),
                                      Text(_formatAmount(totalIncome),
                                          style: const TextStyle(fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.emerald700)),
                                      const Text('VNĐ',
                                          style: TextStyle(fontSize: 11,
                                              color: AppColors.slate400)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.red50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.red100),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Icon(Icons.trending_down_rounded,
                                            size: 16, color: AppColors.red500),
                                        const SizedBox(width: 6),
                                        const Text('Chi',
                                            style: TextStyle(fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.red600)),
                                      ]),
                                      const SizedBox(height: 6),
                                      Text(_formatAmount(totalExpense),
                                          style: const TextStyle(fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.red600)),
                                      const Text('VNĐ',
                                          style: TextStyle(fontSize: 11,
                                              color: AppColors.slate400)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Balance
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.slate50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Text('Số dư:',
                                    style: TextStyle(fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.slate500)),
                                const Spacer(),
                                Text(
                                  '${balance >= 0 ? '+' : ''}${_formatAmount(balance)} VNĐ',
                                  style: TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: balance >= 0
                                        ? AppColors.emerald600
                                        : AppColors.red500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Panel 2: Tabs + Transactions ──
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
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
                          const SizedBox(height: 18),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${filteredTxns.length} giao dịch',
                                  style: const TextStyle(fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.slate800)),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (filteredTxns.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(30),
                              child: Center(
                                child: Text('Chưa có giao dịch',
                                    style: TextStyle(color: AppColors.slate400,
                                        fontWeight: FontWeight.w500)),
                              ),
                            )
                          else
                            ...filteredTxns.map((t) => _buildTransactionItem(t)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom buttons ──
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.embedded ? 20 : 16, 8,
              widget.embedded ? 20 : 16, 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.embedded ? 600 : 700),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final quota = QuotaHelper(store);
                        if (!quota.canUseTransactions) {
                          await showUpgradePrompt(context, quota.transactionLimitMsg);
                          return;
                        }
                        if (widget.embedded) {
                          setState(() => _subView = 'thu');
                        } else {
                          context.go('/nhap-thu');
                        }
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.emerald500,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.trending_up_rounded,
                                size: 20, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Nhập thu',
                                style: TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final quota = QuotaHelper(store);
                        if (!quota.canUseTransactions) {
                          await showUpgradePrompt(context, quota.transactionLimitMsg);
                          return;
                        }
                        if (widget.embedded) {
                          setState(() => _subView = 'chi');
                        } else {
                          context.go('/nhap-chi');
                        }
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.red500,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.trending_down_rounded,
                                size: 20, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Nhập chi',
                                style: TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.slate800 : AppColors.slate500)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: t.isIncome ? AppColors.emerald50 : AppColors.red50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(t.icon, size: 20,
                color: t.isIncome ? AppColors.emerald500 : AppColors.red500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title,
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w600, color: AppColors.slate800),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(dateStr,
                        style: const TextStyle(fontSize: 11,
                            color: AppColors.slate400)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: t.source == 'order'
                            ? AppColors.blue50
                            : t.isIncome
                                ? AppColors.emerald50
                                : AppColors.red50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(sourceLabel,
                          style: TextStyle(fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: t.source == 'order'
                                  ? AppColors.blue600
                                  : t.isIncome
                                      ? AppColors.emerald600
                                      : AppColors.red500)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${t.isIncome ? '+' : '-'}${_formatAmount(t.amount)}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: t.isIncome ? AppColors.emerald600 : AppColors.red500),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    final abs = amount.abs();
    return abs.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _DisplayTxn {
  final String title;
  final DateTime date;
  final double amount;
  final bool isIncome;
  final IconData icon;
  final String source;
  const _DisplayTxn({
    required this.title,
    required this.date,
    required this.amount,
    required this.isIncome,
    required this.icon,
    required this.source,
  });
}
