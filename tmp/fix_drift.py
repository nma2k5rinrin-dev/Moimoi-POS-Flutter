import sys
import os

def rewrite_database():
    path = "lib/core/database/app_database.dart"
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    old_table = """  /// Thu Chi Custom Categories (Read/Write Support)
  class LocalTransactionCategories extends Table {
    TextColumn get id => text()();
    TextColumn get storeId => text()();
    TextColumn get type => text()(); // 'thu' | 'chi'
  }"""

    new_table = """  /// Thu Chi Custom Categories (Read/Write Support)
  class LocalTransactionCategories extends Table {
    TextColumn get id => text()();
    TextColumn get storeId => text()();
    TextColumn get type => text()(); // 'thu' | 'chi'
    TextColumn get emoji => text().withDefault(const Constant(''))();
    TextColumn get label => text().withDefault(const Constant(''))();
    IntColumn get color => integer().withDefault(const Constant(0xFF94A3B8))();
    BoolColumn get isCustom => boolean().withDefault(const Constant(true))();
  }"""
    
    content = content.replace(old_table, new_table)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def rewrite_appstore():
    path = "lib/core/state/app_store.dart"
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Update drift inserts
    old_drift_add = """            await _db!.upsertTransactionCategory(LocalTransactionCategoriesCompanion(
              id: Value(newId),
              storeId: Value(storeId),
              type: Value(catToDraft.type),
            ));"""
    new_drift_add = """            await _db!.upsertTransactionCategory(LocalTransactionCategoriesCompanion(
              id: Value(newId),
              storeId: Value(storeId),
              type: Value(catToDraft.type),
              emoji: Value(catToDraft.emoji),
              label: Value(catToDraft.label),
              color: Value(catToDraft.color.value),
              isCustom: Value(catToDraft.isCustom),
            ));"""

    old_drift_update = """            await _db!.upsertTransactionCategory(LocalTransactionCategoriesCompanion(
              id: Value(updated.id!),
              storeId: Value(storeId),
              type: Value(updated.type),
            ));"""
    new_drift_update = """            await _db!.upsertTransactionCategory(LocalTransactionCategoriesCompanion(
              id: Value(updated.id!),
              storeId: Value(storeId),
              type: Value(updated.type),
              emoji: Value(updated.emoji),
              label: Value(updated.label),
              color: Value(updated.color.value),
              isCustom: Value(updated.isCustom),
            ));"""
            
    content = content.replace(old_drift_add, new_drift_add)
    content = content.replace(old_drift_update, new_drift_update)
    
    # 2. Add Seeding logic
    seed_logic_old = """        // Process results
        users = (results[0] as List).map((u) => UserModel.fromMap(u)).toList();"""
        
    seed_logic_new = """        // Process results
        
        // Seed Transaction Categories if empty
        final rawCats = results[9] as List;
        if (storeId != null && rawCats.isEmpty && storeId != 'sadmin') {
           final defaultCats = [
              // Chi
              TransactionCategory(type: 'chi', emoji: '🍽️', label: 'Nguyên liệu', color: const Color(0xFFEF4444), isCustom: true),
              TransactionCategory(type: 'chi', emoji: '🔧', label: 'Biên mức', color: const Color(0xFF3B82F6), isCustom: true),
              TransactionCategory(type: 'chi', emoji: '⏰', label: 'Tiền điện', color: const Color(0xFFF59E0B), isCustom: true),
              TransactionCategory(type: 'chi', emoji: '🚚', label: 'Vận chuyển', color: const Color(0xFF8B5CF6), isCustom: true),
              TransactionCategory(type: 'chi', emoji: '🛠️', label: 'Sửa chữa', color: const Color(0xFFF97316), isCustom: true),
              TransactionCategory(type: 'chi', emoji: '👥', label: 'Lương NV', color: const Color(0xFF9333EA), isCustom: true),
              // Thu
              TransactionCategory(type: 'thu', emoji: '💵', label: 'Bán hàng', color: const Color(0xFF10B981), isCustom: true),
              TransactionCategory(type: 'thu', emoji: '💰', label: 'Đầu tư', color: const Color(0xFF3B82F6), isCustom: true),
              TransactionCategory(type: 'thu', emoji: '📦', label: 'Thanh lý', color: const Color(0xFFF59E0B), isCustom: true),
           ];
           final newIds = [];
           final inserts = [];
           for (final c in defaultCats) {
             final cid = 'tcseed_' + DateTime.now().microsecondsSinceEpoch.toString() + '_' + defaultCats.indexOf(c).toString();
             final map = c.toMap();
             map.remove('id');
             map.remove('store_id');
             map['id'] = cid;
             map['store_id'] = storeId;
             inserts.add(map);
             newIds.add(map);
           }
           try {
             await _supabase.from('transaction_categories').insert(inserts);
             results[9] = newIds; 
           } catch (e) {
             debugPrint('Seed failed: $e');
           }
        }
        
        users = (results[0] as List).map((u) => UserModel.fromMap(u)).toList();"""
        
    content = content.replace(seed_logic_old, seed_logic_new)
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

rewrite_database()
rewrite_appstore()
print("Fixed Drift Schema and Seeding")
