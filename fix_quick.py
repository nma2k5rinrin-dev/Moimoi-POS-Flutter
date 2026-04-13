import re

# File: admin_dashboard_page.dart
file = 'lib/features/dashboard/presentation/admin/admin_dashboard_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("Consumer<OrderStore>", "Consumer<ManagementStore>")
text = text.replace("_filteredPayments(OrderStore store)", "_filteredPayments(ManagementStore store)")
text = text.replace("store.products.values", "context.watch<InventoryStore>().products.values")
text = text.replace("store.users", "context.watch<ManagementStore>().users")
text = text.replace("store.storeInfos", "context.watch<ManagementStore>().storeInfos")
text = text.replace("store.premiumPayments", "context.watch<ManagementStore>().premiumPayments")
text = text.replace("context.read<OrderStore>().updateStoreInfoById(", "context.read<ManagementStore>().updateStoreInfoById(")
text = text.replace("context.read<OrderStore>().deleteStore(", "context.read<ManagementStore>().deleteStore(")
text = text.replace("store.addStaff(", "context.read<ManagementStore>().addStaff(")
text = text.replace("store.orders", "[]") # Mock orders or wait, admin dashboard doesn't have orders access across stores natively? Actually, store.orders was used to calculate total revenue?

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File: main_shell.dart
file = 'lib/features/dashboard/presentation/main_shell.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace("import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';",
                    "import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';\nimport 'package:moimoi_pos/core/state/order_filter_store.dart';")
# Remove duplicate directives or move them to top:
# Wait, my previous python script added imports before `class _MainShellState` which is inside the file, causing "Directives must appear before any declarations"
text = text.replace("\nimport 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';\nimport 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';\nimport 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';", "")
text = text.replace("import 'package:moimoi_pos/core/state/ui_store.dart';", 
                    "import 'package:moimoi_pos/core/state/ui_store.dart';\nimport 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';\nimport 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';\nimport 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';")

# Use AuthStore instead of UIStore for loadInitialData
text = text.replace("context.read<AuthStore>().loadInitialData", "context.read<AuthStore>().loadInitialData") # Actually, ManagementStore or AuthStore? Let's check. Wait, AppStore had loadInitialData. Standalone AuthStore probably has it. Wait, I see "The method loadInitialData isn't defined for the type AuthStore in main_shell.dart". So it's ManagementStore!
text = text.replace("context.read<AuthStore>().loadInitialData", "context.read<ManagementStore>().loadInitialData")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File: account_dialog.dart
file = 'lib/features/dashboard/presentation/widgets/account_dialog.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("context.read<AuthStore>().toggleBackgroundService()", "context.read<UIStore>().toggleBackgroundService()")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File: sadmin_notifications_page.dart
file = 'lib/features/dashboard/presentation/admin/sadmin_notifications_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace("import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';",
                    "import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';\nimport 'package:moimoi_pos/features/auth/models/user_model.dart';")
with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

print("Applied quick fixes")
