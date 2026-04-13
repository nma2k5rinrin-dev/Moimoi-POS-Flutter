import sys
import os

def rewrite_datepicker(filepath, color_type):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Determine colors
    if color_type == "red":
        primary = "AppColors.red500"
        on_primary = "Colors.white"
        on_surface = "AppColors.slate800"
        btn_color = "AppColors.red600"
    else:
        primary = "AppColors.emerald500"
        on_primary = "Colors.white"
        on_surface = "AppColors.slate800"
        btn_color = "AppColors.emerald600"

    old_picker = """                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );"""
                                
    new_picker = f"""                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                  builder: (context, child) {{
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: {primary},
                                          onPrimary: {on_primary},
                                          onSurface: {on_surface},
                                        ),
                                        textButtonTheme: TextButtonThemeData(
                                          style: TextButton.styleFrom(
                                            foregroundColor: {btn_color},
                                          ),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  }},
                                );"""
    
    content = content.replace(old_picker, new_picker)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

rewrite_datepicker("lib/features/thu_chi/presentation/nhap_chi_page.dart", "red")
rewrite_datepicker("lib/features/thu_chi/presentation/nhap_thu_page.dart", "emerald")

print("Replaced DatePicker styling")
