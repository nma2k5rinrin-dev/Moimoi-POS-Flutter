import sys
import os

def replace_with_compact_picker(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Import
    import_stmt = "import 'package:moimoi_pos/core/widgets/single_date_picker_dialog.dart';"
    if import_stmt not in content:
        content = content.replace("import 'package:moimoi_pos/core/widgets/animated_dialogs.dart';", "import 'package:moimoi_pos/core/widgets/animated_dialogs.dart';\n" + import_stmt)

    # We need to replace the showDatePicker block with showCompactDatePicker.
    # Since we don't have python's advanced multiline regex easily, we can find substring index
    start_idx = content.find("final picked = await showDatePicker(")
    if start_idx != -1:
        # find the end of the showDatePicker call
        # It ends with ); after builder: (context, child) { ... }
        # Let's use a simple heuristic, find ");" after "child: child!," ")," "},"
        # Since I generated it earlier, I know the exact string
        end_str = """                                    );
                                  },
                                );"""
        end_idx = content.find(end_str, start_idx) + len(end_str)
        
        old_block = content[start_idx:end_idx]
        new_block = """final picked = await showCompactDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );"""
                                
        content = content.replace(old_block, new_block)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

replace_with_compact_picker("lib/features/thu_chi/presentation/nhap_chi_page.dart")
replace_with_compact_picker("lib/features/thu_chi/presentation/nhap_thu_page.dart")

print("Used showCompactDatePicker")
