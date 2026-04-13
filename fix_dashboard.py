import re

# File: main_shell.dart
file = 'lib/features/dashboard/presentation/main_shell.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("context.read<UIStore>().currentUser", "context.read<AuthStore>().currentUser")
text = text.replace("context.watch<UIStore>().currentUser", "context.watch<AuthStore>().currentUser")
text = text.replace("context.read<UIStore>().hasPermission", "context.read<ManagementStore>().hasPermission")

text = text.replace("context.read<UIStore>().cartItemCount", "context.read<OrderStore>().cartItemCount")
text = text.replace("context.watch<UIStore>().cartItemCount", "context.watch<OrderStore>().cartItemCount")
text = text.replace("context.read<UIStore>().getCartTotal()", "context.read<OrderStore>().getCartTotal()")

text = text.replace("context.watch<UIStore>().pendingProcessing", "context.watch<OrderStore>().pendingProcessing")
text = text.replace("context.watch<UIStore>().processingProcessing", "context.watch<OrderStore>().processingProcessing")

text = text.replace("context.read<UIStore>().loadInitialData", "context.read<AuthStore>().loadInitialData")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File: dashboard_page.dart
file = 'lib/features/dashboard/presentation/dashboard_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("store.visibleOrders", "context.watch<OrderFilterStore>().visibleOrders")
# transactions are in ManagementStore or CashflowStore? 
# Wait, old AppStore had transactions. It could be CashflowStore now. Let's try CashflowStore. Or we just write context.watch<CashflowStore>().transactions.
text = text.replace("store.transactions", "context.watch<CashflowStore>().transactions")
text = text.replace("import 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';", 
                    "import 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';\nimport 'package:moimoi_pos/core/state/order_filter_store.dart';\nimport 'package:moimoi_pos/features/cashflow/logic/cashflow_store_standalone.dart';")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File: processing_page.dart
file = 'lib/features/dashboard/presentation/processing_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace("import 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';", 
                    "import 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';\nimport 'package:moimoi_pos/features/settings/models/store_info_model.dart';")
with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File: account_dialog.dart
file = 'lib/features/dashboard/presentation/widgets/account_dialog.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';",
                    "import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';\nimport 'package:moimoi_pos/core/state/ui_store.dart';\nimport 'package:moimoi_pos/features/settings/models/store_info_model.dart';\nimport 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';")

text = text.replace("context.read<AuthStore>().toggleBackgroundService", "context.read<UIStore>().toggleBackgroundService")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# premium_page.dart
file = 'lib/features/premium/presentation/premium_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("import 'package:moimoi_pos/features/premium/logic/premium_store_standalone.dart';",
                    "import 'package:moimoi_pos/features/premium/logic/premium_store_standalone.dart';\nimport 'package:moimoi_pos/features/settings/models/store_info_model.dart';\nimport 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';")
with open(file, 'w', encoding='utf-8') as f:
    f.write(text)


print("Dashboard fixes applied.")
