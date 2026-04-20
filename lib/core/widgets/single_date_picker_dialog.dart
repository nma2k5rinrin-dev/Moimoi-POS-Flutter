import 'package:flutter/material.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/widgets/animated_dialogs.dart';

/// Compact single date picker shown as a dropdown dialog.
/// Matches the design of showCompactDateRangePicker.
Future<DateTime?> showCompactDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  return showAnimatedDialog<DateTime>(
    context: context,
    barrierColor: Colors.black26,
    builder: (ctx) => Center(
      child: _DatePickerContent(
        initialDate: initialDate,
        firstDate: firstDate ?? DateTime(2020),
        lastDate: lastDate ?? DateTime.now(),
      ),
    ),
  );
}

class _DatePickerContent extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _DatePickerContent({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_DatePickerContent> createState() => _DatePickerContentState();
}

class _DatePickerContentState extends State<_DatePickerContent> {
  late DateTime _displayMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _displayMonth = DateTime(_selectedDate!.year, _selectedDate!.month);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Selected date display ---
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_outlined,
                      color: AppColors.slate400,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _selectedDate == null
                          ? "Chưa chọn Date"
                          : _formatDate(_selectedDate),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // --- Calendar ---
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _buildCalendar(),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _selectedDate == null
                      ? null
                      : () => Navigator.pop(context, _selectedDate),
                  icon: Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    'Xác nhận',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.slate200,
                    disabledForegroundColor: AppColors.slate400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Column(
      children: [
        _buildMonthHeader(),
        SizedBox(height: 8),
        _buildWeekdaysHeader(),
        SizedBox(height: 8),
        _buildDaysGrid(),
      ],
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _displayMonth = DateTime(
                _displayMonth.year,
                _displayMonth.month - 1,
              );
            });
          },
          icon: Icon(Icons.chevron_left_rounded, size: 24),
          color: AppColors.slate600,
        ),
        Text(
          'Tháng ${_displayMonth.month}, ${_displayMonth.year}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.slate800,
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _displayMonth = DateTime(
                _displayMonth.year,
                _displayMonth.month + 1,
              );
            });
          },
          icon: Icon(Icons.chevron_right_rounded, size: 24),
          color: AppColors.slate600,
        ),
      ],
    );
  }

  Widget _buildWeekdaysHeader() {
    const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return Row(
      children: days
          .map(
            (d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate400,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDaysGrid() {
    final year = _displayMonth.year;
    final month = _displayMonth.month;

    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday; // 1 (Mon) - 7 (Sun)

    final days = <Widget>[];

    // Add empty padding for first day offset
    for (int i = 1; i < startingWeekday; i++) {
      days.add(_buildEmptyDay(year, month, i));
    }

    // Add days
    for (int dayIndex = 1; dayIndex <= daysInMonth; dayIndex++) {
      final day = DateTime(year, month, dayIndex);
      final isSelected =
          _selectedDate != null && _isSameDay(day, _selectedDate!);

      final isDisabled =
          day.isAfter(widget.lastDate) || day.isBefore(widget.firstDate);

      // Current Day logic
      final isToday = _isSameDay(day, DateTime.now());

      days.add(
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary500 : Colors.transparent,
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.primary200, width: 1.5)
                    : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isDisabled
                      ? null
                      : () {
                          setState(() {
                            _selectedDate = day;
                          });
                        },
                  borderRadius: BorderRadius.circular(10),
                  child: Center(
                    child: Text(
                      dayIndex.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected || isToday
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : isDisabled
                            ? AppColors.slate300
                            : isToday
                            ? AppColors.primary600
                            : AppColors.slate700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Fill the rest of the week
    final int remainingDays = (7 - (days.length % 7)) % 7;
    for (int i = 0; i < remainingDays; i++) {
      days.add(_buildEmptyDay(year, month, daysInMonth + i + 1, true));
    }

    final rows = <Widget>[];
    for (int i = 0; i < days.length; i += 7) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Row(children: days.sublist(i, i + 7)),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildEmptyDay(
    int year,
    int month,
    int index, [
    bool isNextMonth = false,
  ]) {
    late final int day;
    if (isNextMonth) {
      day = index - DateTime(year, month + 1, 0).day;
    } else {
      final prevMonthDays = DateTime(year, month, 0).day;
      day = prevMonthDays - (DateTime(year, month, 1).weekday - 1) + index;
    }
    return Expanded(
      child: Center(
        child: Text(
          day.toString(),
          style: TextStyle(fontSize: 14, color: AppColors.slate200),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')} thg ${dt.month}, ${dt.year}';
  }
}
