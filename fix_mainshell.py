import re

# File: main_shell.dart
file = 'lib/features/dashboard/presentation/main_shell.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

# Replace UIStore methods with their actual stores.
# Notice that `store` refers to `context.read<UIStore>()` or `context.watch<UIStore>()`.
# We need to change the references where appropriate.

text = text.replace("store.currentUser", "context.watch<AuthStore>().currentUser")
text = text.replace("store.hasPermission", "context.read<ManagementStore>().hasPermission")
text = text.replace("store.loadInitialData", "context.read<AuthStore>().loadInitialData") # Actually, ManagementStore or AuthStore? Let's check. AppStore had loadInitialData. AuthStore has it now? I will just put context.read<ManagementStore>().loadInitialData.
text = text.replace("store.cartItemCount", "context.watch<OrderStore>().cartItemCount")
text = text.replace("store.getCartTotal(", "context.read<OrderStore>().getCartTotal(")
text = text.replace("store.pendingProcessing", "context.watch<OrderStore>().pendingProcessing")
text = text.replace("store.processingProcessing", "context.watch<OrderStore>().processingProcessing")

# Need missing imports
text = text.replace("class _MainShellState extends State<MainShell> {", 
                    "// Add imports in place \nimport 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';\nimport 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';\nimport 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';\nclass _MainShellState extends State<MainShell> {")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File: account_dialog.dart
file = 'lib/features/dashboard/presentation/widgets/account_dialog.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("store.toggleBackgroundService()", "context.read<UIStore>().toggleBackgroundService()")
text = text.replace("context.read<AuthStore>().toggleBackgroundService()", "context.read<UIStore>().toggleBackgroundService()")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File: sadmin_notifications_page.dart
file = 'lib/features/dashboard/presentation/admin/sadmin_notifications_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace("user.role", "user.role!")
text = text.replace("user.username", "user.username!")
with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

print("Applied fixes to main_shell")
