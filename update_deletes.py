import re

with open('lib/core/state/app_store.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Custom fix: For delete operations mapped to offlineFirst
content = re.sub(
    r"operation:\s*'DELETE',\s*\n\s*recordId:\s*([A-Za-z0-9_]+),\s*\n\s*payload:\s*\{\},",
    r"operation: 'UPDATE',\n      recordId: \1,\n      payload: {'deleted_at': DateTime.now().toUtc().toIso8601String()},",
    content
)

# Custom fix: Product and Category deletions are not using offlineFirst sometimes, let's fix them manually.
content = content.replace(
    "remote: () => _supabase.from('products').delete().eq('id', productId),",
    "remote: () => _supabase.from('products').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', productId),"
)

with open('lib/core/state/app_store.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated deletes")
