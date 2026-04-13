import re

file = 'lib/features/dashboard/presentation/admin/admin_dashboard_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("context.watch<OrderStore>().products.length", "context.watch<InventoryStore>().currentProducts.length")
text = text.replace("context.watch<OrderStore>().users.length", "context.watch<ManagementStore>().users.length")
text = text.replace("context.read<OrderStore>().updateStoreInfoById(", "context.read<ManagementStore>().updateStoreInfoById(")
text = text.replace("context.read<OrderStore>().deleteStore(", "context.read<ManagementStore>().deleteStore(")
text = text.replace("import 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';",
                    "import 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';\nimport 'package:moimoi_pos/features/inventory/logic/inventory_store_standalone.dart';\nimport 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

file = 'lib/features/dashboard/presentation/admin/sadmin_notifications_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace("import 'package:moimoi_pos/core/state/ui_store.dart';",
                    "import 'package:moimoi_pos/core/state/ui_store.dart';\nimport 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';")
with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

print("Fixed admin dashboard page")
