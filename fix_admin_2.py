import re

file = 'lib/features/dashboard/presentation/admin/admin_dashboard_page.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("OrderStore store;", "ManagementStore store;")
text = text.replace("final OrderStore store;", "final ManagementStore store;")
text = text.replace("context.watch<OrderStore>()", "context.watch<ManagementStore>()")
text = text.replace("store.products[", "context.watch<InventoryStore>().products[")

# For main_shell.dart there were some leftover fixes: `pendingProcessing` in OrderFilterStore
# Wait, OrderStore has pendingProcessing? Wait, no. Dashboard uses OrderFilterStore for filtered lists, or OrderStore for getting stats? 
# In old AppStore it was `pendingProcessing` probably. Let's fix main_shell here too.

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)

file = 'lib/features/dashboard/presentation/main_shell.dart'
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()
# Replace OrderStore with OrderFilterStore where missing
text = text.replace("context.watch<OrderStore>().pendingProcessing", "context.watch<OrderFilterStore>().pendingProcessing")
text = text.replace("context.watch<OrderStore>().processingProcessing", "context.watch<OrderFilterStore>().processingProcessing")

with open(file, 'w', encoding='utf-8') as f:
    f.write(text)
    
print("Fixed admin dashboard page")
