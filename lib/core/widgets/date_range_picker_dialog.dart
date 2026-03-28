import 'package:flutter/material.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/widgets/animated_dialogs.dart';

/// Compact date-range picker shown as a dropdown dialog.
/// Matches the design in Node 45OID.
Future<DateTimeRange?> showCompactDateRangePicker({
  required BuildContext context,
  required DateTime initialStart,
  required DateTime initialEnd,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  return showAnimatedDialog<DateTimeRange>(
    context: context,
    barrierColor: Colors.black26,
    builder: (ctx) => Center(
      child: _DateRangePickerContent(
        initialStart: initialStart,
        initialEnd: initialEnd,
        firstDate: firstDate ?? DateTime(2020),
        lastDate: lastDate ?? DateTime.now(),
      ),
    ),
  );
}

class _DateRangePickerContent extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;

  const _DateRangePickerContent({
    required this.initialStart,
    required this.initialEnd,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_DateRangePickerContent> createState() =>
      _DateRangePickerContentState();
}

class _DateRangePickerContentState extends State<_DateRangePickerContent> {
  late DateTime _displayMonth;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  String _quickTab = 'custom'; // 'today', 'month', 'custom'

  @override
  void initState() {
    super.initState();
    _rangeStart = widget.initialStart;
    _rangeEnd = widget.initialEnd;
    _displayMonth = DateTime(_rangeEnd!.year, _rangeEnd!.month);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: Colors.white,
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
            // ── Quick tabs ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildQuickTab('Hôm nay', 'today'),
                    _buildQuickTab('Tháng này', 'month'),
                  ],
                ),
              ),
            ),

            // ── Selected range display ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.emerald400, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 14, color: AppColors.emerald600),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(_rangeStart),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.slate700,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 14, color: AppColors.slate400),
                    ),
                    Text(
                      _formatDate(_rangeEnd),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.slate700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: AppColors.slate400),
                  ],
                ),
              ),
            ),

            // ── Calendar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: _buildCalendar(),
            ),

            // ── Confirm button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: (_rangeStart != null && _rangeEnd != null)
                      ? () {
                          Navigator.pop(
                            context,
                            DateTimeRange(
                              start: _rangeStart!,
                              end: _rangeEnd!,
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Xác nhận',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald500,
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

  // ── Quick tab builder ──
  Widget _buildQuickTab(String label, String key) {
    final isActive = _quickTab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _quickTab = key;
            final now = DateTime.now();
            if (key == 'today') {
              _rangeStart = DateTime(now.year, now.month, now.day);
              _rangeEnd = DateTime(now.year, now.month, now.day);
              _displayMonth = DateTime(now.year, now.month);
            } else if (key == 'month') {
              _rangeStart = DateTime(now.year, now.month, 1);
              _rangeEnd = DateTime(now.year, now.month, now.day);
              _displayMonth = DateTime(now.year, now.month);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
              color: isActive ? AppColors.slate800 : AppColors.slate500,
            ),
          ),
        ),
      ),
    );
  }

  // ── Calendar widget ──
  Widget _buildCalendar() {
    final year = _displayMonth.year;
    final month = _displayMonth.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Monday = 1, so offset: (weekday - 1) for Monday-start
    final startWeekday = (firstDayOfMonth.weekday - 1) % 7;

    final dayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Column(
      children: [
        // Month navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  _displayMonth =
                      DateTime(year, month - 1);
                });
              },
              icon: const Icon(Icons.chevron_left_rounded,
                  color: AppColors.slate400),
              splashRadius: 18,
            ),
            Text(
              'Tháng $month, $year',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.slate800,
              ),
            ),
            IconButton(
              onPressed: () {
                final next = DateTime(year, month + 1);
                if (!next.isAfter(
                    DateTime(widget.lastDate.year, widget.lastDate.month))) {
                  setState(() => _displayMonth = next);
                }
              },
              icon: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.slate400),
              splashRadius: 18,
            ),
          ],
        ),

        // Day name headers
        Row(
          children: dayNames.map((d) {
            return Expanded(
              child: Center(
                child: Text(
                  d,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.slate400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),

        // Day grid
        ...List.generate(6, (week) {
          return Row(
            children: List.generate(7, (col) {
              final dayIndex = week * 7 + col - startWeekday + 1;
              if (dayIndex < 1 || dayIndex > daysInMonth) {
                // Show previous/next month days faded
                return Expanded(
                  child: SizedBox(
                    height: 38,
                    child: Center(
                      child: Text(
                        _getOverflowDay(year, month, dayIndex, daysInMonth),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.slate300,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }

              final day = DateTime(year, month, dayIndex);
              final isStart = _rangeStart != null && _isSameDay(day, _rangeStart!);
              final isEnd = _rangeEnd != null && _isSameDay(day, _rangeEnd!);
              final isInRange = _rangeStart != null &&
                  _rangeEnd != null &&
                  day.isAfter(_rangeStart!.subtract(const Duration(days: 1))) &&
                  day.isBefore(_rangeEnd!.add(const Duration(days: 1)));
              final isDisabled = day.isAfter(widget.lastDate) ||
                  day.isBefore(widget.firstDate);

              return Expanded(
                child: GestureDetector(
                  onTap: isDisabled
                      ? null
                      : () {
                          setState(() {
                            _quickTab = 'custom';
                            if (_rangeStart == null || _rangeEnd != null) {
                              _rangeStart = day;
                              _rangeEnd = null;
                            } else {
                              if (day.isBefore(_rangeStart!)) {
                                _rangeEnd = _rangeStart;
                                _rangeStart = day;
                              } else {
                                _rangeEnd = day;
                              }
                            }
                          });
                        },
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: (isStart || isEnd)
                          ? AppColors.emerald500
                          : isInRange
                              ? AppColors.emerald500.withValues(alpha: 0.12)
                              : Colors.transparent,
                      borderRadius: BorderRadius.only(
                        topLeft:
                            isStart ? const Radius.circular(20) : Radius.zero,
                        bottomLeft:
                            isStart ? const Radius.circular(20) : Radius.zero,
                        topRight:
                            isEnd ? const Radius.circular(20) : Radius.zero,
                        bottomRight:
                            isEnd ? const Radius.circular(20) : Radius.zero,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$dayIndex',
                        style: TextStyle(
                          fontWeight: (isStart || isEnd)
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13,
                          color: isDisabled
                              ? AppColors.slate300
                              : (isStart || isEnd)
                                  ? Colors.white
                                  : isInRange
                                      ? AppColors.emerald700
                                      : AppColors.slate700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }

  String _getOverflowDay(int year, int month, int dayIndex, int daysInMonth) {
    if (dayIndex < 1) {
      final prevMonthDays = DateTime(year, month, 0).day;
      return '${prevMonthDays + dayIndex}';
    } else {
      return '${dayIndex - daysInMonth}';
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '--/--/----';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
