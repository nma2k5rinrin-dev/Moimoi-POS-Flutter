import os

files = [
    r"lib\features\pos_order\presentation\widgets\mobile_cart_sheet.dart",
    r"lib\features\pos_order\presentation\widgets\payment_confirmation_dialog.dart",
    r"lib\features\dashboard\presentation\processing_page.dart",
    r"lib\features\cashflow\presentation\income_page.dart",
    r"lib\features\cashflow\presentation\expense_page.dart"
]

import_statement = "import 'package:flutter/services.dart';\n"

for path in files:
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        
        if "HapticFeedback" not in content:
            # Add import 
            if import_statement not in content:
                content = content.replace("import 'package:flutter/material.dart';", f"import 'package:flutter/material.dart';\n{import_statement}")
            
            # Replace onTap
            content = content.replace("onTap: () {", "onTap: () {\n                                HapticFeedback.lightImpact();")
            content = content.replace("onPressed: () {", "onPressed: () {\n                                HapticFeedback.lightImpact();")
            
            # Write back
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"Added HapticFeedback to {path}")
