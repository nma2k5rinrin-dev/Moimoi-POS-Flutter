import sys
import os

def insert_import(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    import_stmt = "import 'package:moimoi_pos/core/widgets/animated_dialogs.dart';"
    if import_stmt not in content:
        content = content.replace("import 'package:moimoi_pos/core/utils/constants.dart';", "import 'package:moimoi_pos/core/utils/constants.dart';\n" + import_stmt)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

insert_import("lib/features/thu_chi/presentation/nhap_chi_page.dart")
print("Added import animated_dialogs.dart")
