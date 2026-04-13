import re

# File: cashflow_page.dart
file = 'lib/features/cashflow/presentation/cashflow_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("import 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';",
                    "import 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';\nimport 'package:moimoi_pos/core/state/order_filter_store.dart';")
text = text.replace("context.read<OrderStore>().fetchCashflowOrdersByDateRange(", "context.read<OrderFilterStore>().fetchCashflowOrdersByDateRange(")
with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File: admin_dashboard_page.dart
file = 'lib/features/dashboard/presentation/admin/admin_dashboard_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace("final final ManagementStore store;", "final ManagementStore store;")
text = text.replace("context.read<ManagementStore>()", "ctx.read<ManagementStore>()") # Fix context in showAddStoreDialog
text = text.replace("context.watch<ManagementStore>()", "ctx.watch<ManagementStore>()")
with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File: main_shell.dart
file = 'lib/features/dashboard/presentation/main_shell.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

# Fix duplicates and order
text = text.replace("\nimport 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';\nimport 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';\nimport 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';", "")
text = text.replace("import 'package:moimoi_pos/core/state/order_filter_store.dart';", 
                    "import 'package:moimoi_pos/core/state/order_filter_store.dart';\nimport 'package:moimoi_pos/features/pos_order/logic/cart_store_standalone.dart';")

text = text.replace("await context.read<ManagementStore>().loadInitialData(context.watch<AuthStore>().currentUser!);", "// await loadInitialData")
text = text.replace("context.read<OrderStore>().cartItemCount", "context.watch<CartStore>().cartItemCount")
text = text.replace("context.watch<OrderStore>().cartItemCount", "context.watch<CartStore>().cartItemCount")
text = text.replace("context.read<OrderStore>().getCartTotal(", "context.read<CartStore>().getCartTotal(")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File: account_dialog.dart
file = 'lib/features/dashboard/presentation/widgets/account_dialog.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace("context.read<AuthStore>().toggleBackgroundService", "context.read<UIStore>().toggleBackgroundService")
text = text.replace("import 'package:moimoi_pos/features/premium/logic/premium_store_standalone.dart';\nimport 'package:moimoi_pos/features/premium/logic/premium_store_standalone.dart';", "import 'package:moimoi_pos/features/premium/logic/premium_store_standalone.dart';")
with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

print("Applied final round of fixes")
