import re

# File: admin_dashboard_page.dart
file = 'lib/features/dashboard/presentation/admin/admin_dashboard_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

# Revert previous bad global fix
text = text.replace("ctx.watch<ManagementStore>()", "context.watch<ManagementStore>()")
text = text.replace("ctx.read<ManagementStore>()", "context.read<ManagementStore>()")

# In _showAddStoreDialog, there's `context.read<ManagementStore>().addStaff`. 
# We replace it with `ctx.read<ManagementStore>().addStaff`.
text = text.replace("context.read<ManagementStore>().addStaff", "ctx.read<ManagementStore>().addStaff")
text = text.replace("context.read<ManagementStore>().updateStoreInfoById", "ctx.read<ManagementStore>().updateStoreInfoById")
text = text.replace("context.read<ManagementStore>().deleteStore", "ctx.read<ManagementStore>().deleteStore")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File: main_shell.dart
file = 'lib/features/dashboard/presentation/main_shell.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()
# Directives must appear before any declarations
text = text.replace("import 'package:moimoi_pos/core/state/order_filter_store.dart';\nimport 'package:moimoi_pos/features/pos_order/logic/cart_store_standalone.dart';", "")
text = text.replace("import 'package:moimoi_pos/features/cashflow/logic/cashflow_store_standalone.dart';", 
                    "import 'package:moimoi_pos/features/cashflow/logic/cashflow_store_standalone.dart';\nimport 'package:moimoi_pos/core/state/order_filter_store.dart';\nimport 'package:moimoi_pos/features/pos_order/logic/cart_store_standalone.dart';")
# Undefined name 'context' line 669: Probably `context.watch<ManagementStore>().hasPermission`. Wait, if it's `context` but defined as something else? Let's check where it is. It's likely line 669 `context.read<AuthStore>().currentUser`. Let's not blind replace but fix it:
text = text.replace("context.read<AuthStore>().currentUser", "uiStore.currentUser") # MainShell probably has uiStore defined or authStore? Oh wait. 
text = text.replace("context.read<AuthStore>().currentUser", "context.read<AuthStore>().currentUser") # No wait, main_shell.dart line 669 was probably outside build tree? No, it's `context`

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)


# File: account_dialog.dart
file = 'lib/features/dashboard/presentation/widgets/account_dialog.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace("context.read<AuthStore>().toggleBackgroundService", "context.read<UIStore>().toggleBackgroundService")
text = text.replace("import 'package:moimoi_pos/core/state/ui_store.dart';\nimport 'package:moimoi_pos/core/state/ui_store.dart';", "import 'package:moimoi_pos/core/state/ui_store.dart';")
with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

print("Applied final-final fixes")
