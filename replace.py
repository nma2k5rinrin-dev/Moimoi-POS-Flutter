import re

with open('lib/features/cashflow/presentation/cashflow_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update initState dates
old_init = '''    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, now.day);
    _dateTo = DateTime.now();'''

new_init = '''    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = DateTime(now.year, now.month + 1, 0, 23, 59, 59);'''

content = content.replace(old_init, new_init)

# 2. Insert _selectMonth function
select_month_func = '''  Future<void> _selectMonth() async {
    DateTime selected = _dateFrom;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left_rounded, color: AppColors.slate600),
                          onTap: () => setDialogState(() => selected = DateTime(selected.year - 1, selected.month)),
                        ),
                        Text('\', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                        IconButton(
                          icon: Icon(Icons.chevron_right_rounded, color: AppColors.slate600),
                          onTap: () => setDialogState(() => selected = DateTime(selected.year + 1, selected.month)),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final month = index + 1;
                        final isCurrentMonth = month == selected.month;
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.pop(context, DateTime(selected.year, month, 1));
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isCurrentMonth ? AppColors.emerald500 : AppColors.slate50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Tháng \', style: TextStyle(fontSize: 13, color: isCurrentMonth ? Colors.white : AppColors.slate700, fontWeight: FontWeight.w600)),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      final endOfMonth = DateTime(picked.year, picked.month + 1, 0, 23, 59, 59);
      setState(() {
        _dateFrom = picked;
        _dateTo = endOfMonth;
        _selectedDate = null;
      });
      _fetchData(context.read<AppStore>(), _dateFrom, _dateTo);
    }
  }

  @override
  Widget build(BuildContext context) {'''

content = content.replace("  @override\n  Widget build(BuildContext context) {", select_month_func)

# 3. Modify Top Nav (Overview) to insert picker above
old_overview = '''                      SizedBox(key: _topKey, height: 4),

                      // -- Panel 1: Overview --'''

new_overview = '''                      SizedBox(key: _topKey, height: 4),

                      // -- Header: Month Picker --
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'L?ch dòng ti?n',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate800,
                            ),
                          ),
                          GestureDetector(
                            onTap: _selectMonth,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.blue50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.blue200,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_month_rounded,
                                    size: 16,
                                    color: AppColors.blue700,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tháng \/\',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.blue700,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 18,
                                    color: AppColors.blue500,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // -- Panel 1: Overview --'''

content = content.replace(old_overview, new_overview)

# 4. Remove old picker completely via Regex
import re
content = re.sub(r'Row\(\s*mainAxisAlignment: MainAxisAlignment\.spaceBetween,\s*children: \[\s*Flexible\(\s*child: Text\(\s*\'T?ng quan thu nh?p\',\s*style: TextStyle\(\s*fontSize: 15,\s*fontWeight: FontWeight\.w700,\s*color: AppColors\.slate800,\s*\),\s*\),\s*\),\s*GestureDetector\(.*?\),\s*\],\s*\),', 
r'''Text(
                              'T?ng quan thu nh?p',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate800,
                              ),
                            ),''', content, flags=re.DOTALL)

with open('lib/features/cashflow/presentation/cashflow_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
