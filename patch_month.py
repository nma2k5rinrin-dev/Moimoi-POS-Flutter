import re

file_path = "e:/Moimoi-POS-Flutter/lib/features/cashflow/presentation/cashflow_page.dart"
with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

target1 = """                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Tổng quan thu nhập',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.slate800,
                                    ),
                                  ),
                                ),
                                GestureDetector(
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
                                          '${_dateFrom.day.toString().padLeft(2, '0')}/${_dateFrom.month.toString().padLeft(2, '0')} - ${_dateTo.day.toString().padLeft(2, '0')}/${_dateTo.month.toString().padLeft(2, '0')}',
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
                                ),
                              ],
                            ),
                            SizedBox(height: 12),"""

replacement1 = """                            Text(
                              'Tổng quan thu nhập',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.slate800,
                              ),
                            ),
                            SizedBox(height: 16),"""
text = text.replace(target1, replacement1)

target2 = """                      // ── Panel 1: Overview ──"""
replacement2 = """                      // ── Month Picker ──
                      Center(
                        child: GestureDetector(
                          onTap: () async {
                              int selectedYear = _dateFrom.year;
                              int selectedMonth = _dateFrom.month;
                              
                              final result = await showDialog<DateTime>(
                                context: context,
                                builder: (ctx) {
                                  return StatefulBuilder(
                                    builder: (ctx, setDialogState) {
                                      return AlertDialog(
                                        backgroundColor: Colors.white,
                                        surfaceTintColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        contentPadding: EdgeInsets.all(20),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                IconButton(
                                                  icon: Icon(Icons.chevron_left, color: AppColors.slate600),
                                                  onPressed: () => setDialogState(() => selectedYear--),
                                                ),
                                                Text(
                                                  selectedYear.toString(),
                                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate800),
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.chevron_right, color: AppColors.slate600),
                                                  onPressed: () => setDialogState(() => selectedYear++),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 16),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: List.generate(12, (index) {
                                                final month = index + 1;
                                                final isSelected = month == selectedMonth;
                                                return GestureDetector(
                                                  onTap: () {
                                                    setDialogState(() => selectedMonth = month);
                                                    Navigator.pop(ctx, DateTime(selectedYear, selectedMonth, 1));
                                                  },
                                                  child: Container(
                                                    width: 60,
                                                    height: 40,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? AppColors.emerald500 : AppColors.slate50,
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: isSelected ? AppColors.emerald500 : AppColors.slate200,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      'Th $month',
                                                      style: TextStyle(
                                                        color: isSelected ? Colors.white : AppColors.slate700,
                                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  );
                                },
                              );
                              
                              if (result != null) {
                                setState(() {
                                  _dateFrom = DateTime(result.year, result.month, 1);
                                  _dateTo = DateTime(result.year, result.month + 1, 0); // Last day of month
                                  _selectedDate = null;
                                });
                                _fetchData(store, _dateFrom, _dateTo);
                              }
                          },
                          child: Container(
                            margin: EdgeInsets.only(bottom: 20),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.slate200.withOpacity(0.5),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                )
                              ],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.emerald100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.date_range_rounded, size: 18, color: AppColors.emerald600),
                                SizedBox(width: 8),
                                Text(
                                  'Tháng ${_dateFrom.month}/${_dateFrom.year}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.slate800,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.slate500),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Panel 1: Overview ──"""
if target2 in text:
    text = text.replace(target2, replacement2)
    print("TARGET 2 SUCCESS")
else:
    print("TARGET 2 NOT FOUND")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(text)

print("DONE")
