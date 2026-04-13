import re

with open('lib/core/state/app_store.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# For orders
src = "final rec = payload.newRecord;"
dest = """final rec = payload.newRecord;
          if (rec['deleted_at'] != null) {
            orders.removeWhere((o) => o.id == rec['id']?.toString());
            try {
              if (_db != null) await _db!.deleteOrderLocally(rec['id']?.toString() ?? '');
            } catch (_) {}
            notifyListeners();
            return;
          }"""
content = content.replace(src, dest, 1) # Only first for orders

# For products
src_prod = "final p = ProductModel.fromMap(payload.newRecord);"
dest_prod = """final p = ProductModel.fromMap(payload.newRecord);
          if (p.deletedAt != null) {
            products[p.storeId] = (products[p.storeId] ?? []).where((x) => x.id != p.id).toList();
            notifyListeners();
            return;
          }"""
content = content.replace(src_prod, dest_prod, 1)

# For categories
src_cat = "final c = CategoryModel.fromMap(payload.newRecord);"
dest_cat = """final c = CategoryModel.fromMap(payload.newRecord);
          if (c.deletedAt != null) {
            categories[c.storeId] = (categories[c.storeId] ?? []).where((x) => x.id != c.id).toList();
            notifyListeners();
            return;
          }"""
content = content.replace(src_cat, dest_cat, 1)

# For transactions
src_tx = "final t = Transaction.fromMap(payload.newRecord);"
dest_tx = """final t = Transaction.fromMap(payload.newRecord);
          if (t.deletedAt != null) {
            transactions.removeWhere((x) => x.id == t.id);
            try {
               await (_db!.delete(_db!.localTransactions)..where((tbl) => tbl.id.equals(t.id))).go();
            } catch (_) {}
            notifyListeners();
            return;
          }"""
content = content.replace(src_tx, dest_tx, 1)

with open('lib/core/state/app_store.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated realtime")
