import sys
import os
import re

def create_single_picker():
    with open("tmp/ref_dr.txt", 'r', encoding='utf-8') as f:
        src = f.read()

    # Step 1: Replace Range name
    res = src.replace("DateRangePicker", "DatePicker")
    res = res.replace("showCompactDateRangePicker", "showCompactDatePicker")
    res = res.replace("DateTimeRange", "DateTime")
    
    # Step 2: Remove End date parameters
    res = res.replace("required DateTime initialEnd,", "")
    res = res.replace("initialEnd: initialEnd,", "")
    res = res.replace("final DateTime initialEnd;", "")
    res = res.replace("required this.initialEnd,", "")

    # Step 3: Replace range variables with single
    res = res.replace("DateTime? _rangeEnd;", "")
    res = res.replace("DateTime? _rangeStart;", "DateTime? _selectedDate;")

    res = res.replace("_rangeStart = widget.initialStart;", "_selectedDate = widget.initialStart;")
    res = res.replace("_rangeEnd = widget.initialEnd;", "")
    res = res.replace("_displayMonth = DateTime(_rangeEnd!.year, _rangeEnd!.month);", "_displayMonth = DateTime(_selectedDate!.year, _selectedDate!.month);")

    # Quick tabs
    # For single picker, today, yesterday, maybe no tabs? Or just remove quick tabs completely.
    # The user just wants the DatePicker UI. I will remove the Quick tabs section building block.
    res = re.sub(r'// .*? Quick tabs .*?// .*? Selected range display .*?\n', '// --- Selected date display ---\n', res, flags=re.DOTALL)
    
    # Range Display (change to single date)
    # The original has a Container with row showing Start and End.
    single_display = """            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event, color: AppColors.slate400, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _selectedDate == null ? "Chưa chọn Date" : _formatDate(_selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate800,
                      ),
                    ),
                  ],
                ),
              ),
            ),"""
    
    # Need to regex out the old "Selected range display" Padding widget completely.
    # We will search for "// --- Selected date display ---" to the end of next Padding, up to "// --- Calendar ---"
    res = re.sub(r'// --- Selected date display ---.*?// .*? Calendar', '// --- Selected date display ---\n' + single_display + '\n            // --- Calendar ---', res, flags=re.DOTALL)

    # Output selection logic:
    # Instead of _rangeStart and _rangeEnd logic, we just set `_selectedDate = day`
    selection_logic_old = """                  onTap: isDisabled
                      ? null
                      : () {
                          setState(() {
                            // If both are selected, reset and start new
                            if (_rangeStart != null && _rangeEnd != null) {
                              _rangeStart = day;
                              _rangeEnd = null;
                            }
                            // If only start is selected
                            else if (_rangeStart != null && _rangeEnd == null) {
                              if (day.isBefore(_rangeStart!)) {
                                _rangeStart = day; // reset start
                              } else {
                                _rangeEnd = day; // complete range
                              }
                            }
                            // If neither is selected
                            else {
                              _rangeStart = day;
                            }
                            _quickTab = 'custom';
                          });
                        },"""
                        
    selection_logic_new = """                  onTap: isDisabled
                      ? null
                      : () {
                          setState(() {
                            _selectedDate = day;
                            _quickTab = 'custom';
                          });
                        },"""
    res = res.replace(selection_logic_old, selection_logic_new)

    # Highlight logic
    # _isSameDay(day, _rangeStart) || _isSameDay(day, _rangeEnd)
    res = res.replace("_isSameDay(day, _rangeStart) || _isSameDay(day, _rangeEnd)", "_isSameDay(day, _selectedDate!)")
    res = res.replace("_isSameDay(day, _rangeStart!) || _isSameDay(day, _rangeEnd!)", "_isSameDay(day, _selectedDate!)")
    
    # In range: day.isAfter(_rangeStart!) && day.isBefore(_rangeEnd!)
    res = res.replace("day.isAfter(_rangeStart!) && day.isBefore(_rangeEnd!)", "false")
    res = res.replace("final isInRange = _rangeStart != null && _rangeEnd != null && false;", "final isInRange = false;")
    
    # Return button
    # Navigator.pop(context, DateTimeRange(...))
    res = re.sub(r'Navigator\.pop\(context, DateTimeRange\([^)]+\)\);', 'Navigator.pop(context, _selectedDate);', res)

    # write to single_date_picker_dialog.dart
    with open("lib/core/widgets/single_date_picker_dialog.dart", "w", encoding='utf-8') as f:
        f.write(res)


create_single_picker()
print("Generated single_date_picker_dialog.dart")
