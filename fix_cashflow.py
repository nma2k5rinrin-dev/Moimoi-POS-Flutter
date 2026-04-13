import re

# File: cashflow_page.dart
file = 'lib/features/cashflow/presentation/cashflow_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("import 'package:moimoi_pos/features/cashflow/logic/cashflow_store_standalone.dart';",
                    "import 'package:moimoi_pos/features/cashflow/logic/cashflow_store_standalone.dart';\nimport 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';")
text = text.replace("store.scrollToTopStream", "context.read<UIStore>().scrollToTopStream")
text = text.replace("store.fetchCashflowOrdersByDateRange(", "context.read<OrderStore>().fetchCashflowOrdersByDateRange(")
# check if fetchCashflowOrdersByDateRange is in OrderStore? I didn't see an error when I analyzed before wait? In earlier flutter analyze, I did not change this file so it didn't fail? No, wait. 
text = text.replace("store.showConfirm(", "context.read<UIStore>().showConfirm(")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File: expense_page.dart
file = 'lib/features/cashflow/presentation/expense_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace("import 'package:moimoi_pos/core/state/ui_store.dart';", "import 'package:moimoi_pos/core/state/ui_store.dart';\nimport 'package:moimoi_pos/features/cashflow/logic/cashflow_store_standalone.dart';")
with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File: income_page.dart
file = 'lib/features/cashflow/presentation/income_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace("import 'package:moimoi_pos/core/state/ui_store.dart';", "import 'package:moimoi_pos/core/state/ui_store.dart';\nimport 'package:moimoi_pos/features/cashflow/logic/cashflow_store_standalone.dart';")
with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

print("Cashflow fixes applied")
