import re

# File: admin_dashboard_page.dart
file = 'lib/features/dashboard/presentation/admin/admin_dashboard_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("OrderStore store", "ManagementStore store")
text = text.replace("store.showToast", "context.read<UIStore>().showToast")
text = text.replace("ManagementStore store;", "final ManagementStore store;") # fix any accidental changes

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

print("Admin dashboard page fixed")
