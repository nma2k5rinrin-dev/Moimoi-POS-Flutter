import sys

def replace_block(filename, color_name, bg_light, bg_border, text_normal, text_light, placeholder_color, shadow_color, title_text):
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    start_str = '''                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient('''

    end_str = '''                            ],
                          ),
                        ),
                      ),'''
    
    start_idx = content.find(start_str)
    
    end_idx = content.find(end_str, start_idx) + len(end_str)
    
    if start_idx == -1 or end_idx == -1 + len(end_str):
        print(f'Could not find block in {filename}')
        return
        
    replacement = f'''                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.{shadow_color}.withOpacity(0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.{text_light}.withOpacity(0.3)
                                : AppColors.{bg_border}.withOpacity(0.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            // --- Amount Area ---
                            Padding(
                              padding: const EdgeInsets.only(top: 24, bottom: 16, left: 16, right: 16),
                              child: Column(
                                children: [
                                  Text(
                                    '{title_text}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                      color: AppColors.{text_normal}.withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _amountCtrl,
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 42,
                                            height: 1.1,
                                            fontWeight: FontWeight.w800,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? AppColors.{text_light}
                                                : AppColors.{text_normal},
                                            letterSpacing: -1,
                                          ),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            _ThousandSeparatorFormatter(),
                                          ],
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            hintText: '0',
                                            hintStyle: TextStyle(
                                              fontSize: 42,
                                              height: 1.1,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.{text_light}.withOpacity(0.5),
                                            ),
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            Divider(height: 1, thickness: 1, color: AppColors.slate200.withOpacity(0.4)),
                            
                            // --- Metadata Area ---
                            IntrinsicHeight(
                              child: Row(
                                children: [
                                  // Note
                                  Expanded(
                                    flex: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_note_rounded, size: 20, color: AppColors.slate400),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: _noteCtrl,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.white
                                                    : AppColors.slate700,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: 'Thêm ghi chú...',
                                                hintStyle: TextStyle(
                                                  fontSize: 14,
                                                  fontStyle: FontStyle.italic,
                                                  fontWeight: FontWeight.w400,
                                                  color: AppColors.slate400,
                                                ),
                                                border: InputBorder.none,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  VerticalDivider(width: 1, thickness: 1, color: AppColors.slate200.withOpacity(0.4)),
                                  
                                  // Date
                                  GestureDetector(
                                    onTap: () async {{
                                      final picked = await showCompactDatePicker(
                                        context: context,
                                        initialDate: _selectedDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null) {{
                                        setState(() => _selectedDate = picked);
                                      }}
                                    }},
                                    behavior: HitTestBehavior.opaque,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.{text_normal}),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${{_selectedDate.day.toString().padLeft(2, "0")}}/${{_selectedDate.month.toString().padLeft(2, "0")}}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.{text_normal},
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),'''

    content = content[:start_idx] + replacement + content[end_idx:]
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'Successfully updated {filename}')

replace_block('lib/features/cashflow/presentation/income_page.dart', 'emerald', 'emerald50', 'emerald200', 'emerald700', 'emerald400', 'emerald500', 'emerald500', 'SỐ TIỀN THU')
replace_block('lib/features/cashflow/presentation/expense_page.dart', 'red', 'red50', 'red200', 'red600', 'red400', 'red500', 'red500', 'SỐ TIỀN CHI')
