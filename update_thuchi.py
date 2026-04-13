import re

with open('lib/core/state/app_store.dart', 'r', encoding='utf-8') as f:
    content = f.read()

func_to_add = """
  void updateThuChiCategoryOrder(List<TransactionCategory> sortedList) {
    final storeId = getStoreId();
    final oldList = List<TransactionCategory>.from(customTransactionCategories[storeId] ?? []);
    
    // Optimistic Update InMemory
    customTransactionCategories[storeId] = sortedList;
    notifyListeners();

    // Async apply to Drift and SyncQueue without blocking UI
    for (int i = 0; i < sortedList.length; i++) {
        final category = sortedList[i];
        final updatedData = {'sort_order': i};
        
        _offlineFirst(
            table: 'transaction_categories',
            operation: 'UPDATE',
            recordId: category.id!,
            payload: updatedData,
            applyInMemory: () {}, // Already done
            applyDrift: () async {
                if (_db != null) {
                    await _db!.upsertTransactionCategory(
                        LocalTransactionCategoriesCompanion(
                            id: Value(category.id!),
                            sortOrder: Value(i),
                        ),
                    );
                }
            },
            rollback: () {
                customTransactionCategories[storeId] = oldList;
            },
            errorMsg: 'Cập nhật thứ tự lỗi',
        );
    }
  }

  void deleteTransactionCategory(String categoryId) {"""

content = content.replace("  void deleteTransactionCategory(String categoryId) {", func_to_add)

with open('lib/core/state/app_store.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated Thu Chi Category Order")
