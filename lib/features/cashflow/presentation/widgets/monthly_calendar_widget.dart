import 'package:flutter/material.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/features/cashflow/models/transaction_model.dart';

class MonthlyCalendarWidget extends StatefulWidget {
  final DateTime currentMonth;
  final List<Transaction> customTxns;
  final ValueChanged<DateTime> onDateSelected;

  const MonthlyCalendarWidget({
    super.key,
    required this.currentMonth,
    required this.customTxns,
    required this.onDateSelected,
  });

  @override
  State<MonthlyCalendarWidget> createState() => _MonthlyCalendarWidgetState();
}

class _MonthlyCalendarWidgetState extends State<MonthlyCalendarWidget> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final year = widget.currentMonth.year;
    final month = widget.currentMonth.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Mon, 7 = Sun

    // Monday is first day of week
    final int emptyOffset = firstWeekday - 1;

    final days = <Widget>[];

    // Weekdays header
    final weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    for (var w in weekdays) {
      days.add(
        Center(
          child: Text(
            w,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.slate400,
            ),
          ),
        ),
      );
    }

    // Empty slots before 1st day
    for (int i = 0; i < emptyOffset; i++) {
      days.add(const SizedBox());
    }

    // Days slots
    for (int i = 1; i <= daysInMonth; i++) {
      final date = DateTime(year, month, i);
      final isToday = DateUtils.isSameDay(date, DateTime.now());
      final isSelected = DateUtils.isSameDay(date, _selectedDate);

      // Check for transactions on this day
      bool hasIncome = false;
      bool hasExpense = false;
      for (final txn in widget.customTxns) {
        // Parse the local time
        var s = txn.time;
        if (s.endsWith('Z')) s = s.substring(0, s.length - 1);
        final plussIdx = s.indexOf('+');
        if (plussIdx != -1) s = s.substring(0, plussIdx);
        final txnDate = DateTime.tryParse(s);

        if (txnDate != null && DateUtils.isSameDay(txnDate, date)) {
          if (txn.type == 'thu') hasIncome = true;
          if (txn.type == 'chi') hasExpense = true;
        }
      }

      days.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
            });
            widget.onDateSelected(date);
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.blue500 : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isToday && !isSelected
                  ? Border.all(color: AppColors.blue200, width: 1.5)
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$i',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isToday ? AppColors.blue600 : AppColors.slate700),
                  ),
                ),
                if (hasIncome || hasExpense)
                  Positioned(
                    bottom: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasIncome)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(right: 2),
                            decoration: BoxDecoration(
                              color: AppColors.emerald500,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (hasExpense)
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.red500,
                              shape: BoxShape.circle,
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: days,
          ),
          const SizedBox(height: 12),
          Text(
            '* Bấm 2 lần vào ngày để thêm giao dịch',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}
