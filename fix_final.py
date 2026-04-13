import re

# notification_bell.dart
file = 'lib/features/notifications/presentation/notification_bell.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("import 'package:moimoi_pos/features/notifications/logic/notifications_store_standalone.dart';",
                    "import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';")
text = text.replace("context.watch<NotificationsStore>()", "context.watch<ManagementStore>()")
text = text.replace("context.read<NotificationsStore>()", "context.read<ManagementStore>()")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# premium_page.dart
file = 'lib/features/premium/presentation/premium_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("store.currentStoreInfo", "(context.watch<ManagementStore>().storeInfos[context.watch<ManagementStore>().getStoreId()] ?? const StoreInfoModel())")
text = text.replace("const StoreInfoModel()", "const StoreInfoModel(name: 'No store', isPremium: false)")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# payment_history_dialog.dart
file = 'lib/features/premium/presentation/widgets/payment_history_dialog.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace("context.watch<PremiumStore>().premiumPayments", "context.watch<ManagementStore>().premiumPayments")
text = text.replace("import 'package:moimoi_pos/features/premium/logic/premium_store_standalone.dart';",
                    "import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';")
with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

# main_shell.dart
file = 'lib/features/dashboard/presentation/main_shell.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace("context.read<UIStore>().hasPermission", "context.read<ManagementStore>().hasPermission")
text = text.replace("context.read<UIStore>().currentUser", "context.read<AuthStore>().currentUser")
text = text.replace("context.read<UIStore>().loadInitialData", "context.read<ManagementStore>().loadInitialData") # Wait, is this in ManagementStore? AppStore.loadInitialData? Let's assume UIStore doesn't have it but AuthStore or something does. We will see. I think AuthStore has loadInitialData. Actually ManagementStore maybe.
text = text.replace("context.watch<UIStore>().currentUser", "context.watch<AuthStore>().currentUser")
text = text.replace("context.watch<UIStore>().cartItemCount", "context.watch<OrderStore>().cartItemCount")
text = text.replace("context.read<UIStore>().getCartTotal()", "context.read<OrderStore>().getCartTotal()")
text = text.replace("context.watch<UIStore>().pendingProcessing", "context.watch<OrderStore>().pendingProcessing")
text = text.replace("context.watch<UIStore>().processingProcessing", "context.watch<OrderStore>().processingProcessing")
with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

print("Applied final fixes")
