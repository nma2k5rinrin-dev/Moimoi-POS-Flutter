import re

# File 1: main_shell.dart
file = 'lib/features/dashboard/presentation/main_shell.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("context.read<UIStore>().currentUser", "context.read<AuthStore>().currentUser")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File 2: processing_page.dart
file = 'lib/features/dashboard/presentation/processing_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

# visibleOrders -> OrderFilterStore
text = text.replace("store.visibleOrders", "context.watch<OrderFilterStore>().visibleOrders")
# showConfirm -> UIStore
text = text.replace("store.showConfirm(", "context.read<UIStore>().showConfirm(")
# currentTables -> ManagementStore
text = text.replace("store.currentTables", "context.watch<ManagementStore>().storeTables[context.watch<ManagementStore>().getStoreId()] ?? []")
# currentStoreInfo -> ManagementStore
text = text.replace("store.currentStoreInfo", "(context.watch<ManagementStore>().storeInfos[context.watch<ManagementStore>().getStoreId()] ?? const StoreInfoModel())")
# currentProducts -> InventoryStore
text = text.replace("store.currentProducts", "context.watch<InventoryStore>().currentProducts")
# currentCategories -> InventoryStore
text = text.replace("store.currentCategories", "context.watch<InventoryStore>().currentCategories")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File 3: account_dialog.dart
file = 'lib/features/dashboard/presentation/widgets/account_dialog.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("store.isDarkMode", "context.watch<UIStore>().isDarkMode")
text = text.replace("store.toggleTheme(", "context.read<UIStore>().toggleTheme(")
text = text.replace("store.isBackgroundServiceEnabled", "context.watch<UIStore>().isBackgroundServiceEnabled")
text = text.replace("store.toggleBackgroundService()", "context.read<UIStore>().toggleBackgroundService()")
text = text.replace("store.currentStoreInfo", "(context.watch<ManagementStore>().storeInfos[context.watch<ManagementStore>().getStoreId()] ?? const StoreInfoModel())")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File 4: notification_bell.dart
file = 'lib/features/notifications/presentation/notification_bell.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("context.watch<UIStore>().notifications", "context.watch<NotificationsStore>().notifications")
text = text.replace("store.notifications", "context.watch<NotificationsStore>().notifications")
text = text.replace("store.markNotificationAsRead", "context.read<NotificationsStore>().markNotificationAsRead")
text = text.replace("store.broadcastNotification", "context.read<NotificationsStore>().broadcastNotification")
text = text.replace("store.currentUser", "context.watch<AuthStore>().currentUser")
text = text.replace("import 'package:moimoi_pos/core/state/ui_store.dart';", "import 'package:moimoi_pos/core/state/ui_store.dart';\nimport 'package:moimoi_pos/features/notifications/logic/notifications_store_standalone.dart';\nimport 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File 5: premium_page.dart
file = 'lib/features/premium/presentation/premium_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("store.currentStoreInfo", "(context.watch<ManagementStore>().storeInfos[context.watch<ManagementStore>().getStoreId()] ?? const StoreInfoModel())")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# File 6: payment_history_dialog.dart & upgrade_dialog.dart
for file in [
    'lib/features/premium/presentation/widgets/payment_history_dialog.dart',
    'lib/features/premium/presentation/widgets/upgrade_dialog.dart'
]:
    with open(file, 'r', encoding='utf-8') as f:
        text = f.read()
    text = text.replace("import 'package:provider/provider.dart';", "import 'package:provider/provider.dart';\nimport 'package:moimoi_pos/features/premium/logic/premium_store_standalone.dart';")
    with open(file, 'w', encoding='utf-8') as f:
        f.write(text)

print("Fixes applied.")
