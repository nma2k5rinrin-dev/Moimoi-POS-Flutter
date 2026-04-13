import sys
import os
import re

def rewrite_manage_dialog(filepath, type_str):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the _showManageCategoryOptions function using regex
    pattern = r'void _showManageCategoryOptions\(int index, TransactionCategory cat\) \{.+?\n  \}'
    
    new_func = """void _showManageCategoryOptions(int index, TransactionCategory cat) {
    showAnimatedDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppColors.shadowLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Tùy chỉnh danh mục', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                  const SizedBox(height: 8),
                  Text('${cat.emoji} ${cat.label}', style: const TextStyle(fontSize: 16, color: AppColors.slate600)),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            final store = context.read<AppStore>();
                            store.deleteTransactionCategory(cat.id!);
                            setState(() {
                              if (_selectedCategory == index) {
                                _selectedCategory = 0;
                              } else if (_selectedCategory > index) {
                                _selectedCategory -= 1;
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: AppColors.red50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.delete_outline, color: AppColors.red600),
                                SizedBox(height: 8),
                                Text('Xoá', style: TextStyle(color: AppColors.red600, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            showAddCategoryDialog(
                              context: context,
                              type: '""" + type_str + """',
                              initialName: cat.label,
                              initialEmoji: cat.emoji,
                              initialColor: cat.color,
                              onSave: (name, emoji, color) {
                                final store = context.read<AppStore>();
                                store.updateTransactionCategory(
                                  TransactionCategory(
                                    id: cat.id, storeId: cat.storeId, type: '""" + type_str + """',
                                    emoji: emoji, label: name, color: color, isCustom: true
                                  )
                                );
                                setState(() {
                                   _selectedCategory = index;
                                });
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: AppColors.emerald50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.edit_outlined, color: AppColors.emerald600),
                                SizedBox(height: 8),
                                Text('Sửa', style: TextStyle(color: AppColors.emerald600, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }"""
    
    # We replace the old block with new_func
    new_content = re.sub(pattern, new_func, content, flags=re.DOTALL)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)

rewrite_manage_dialog("lib/features/thu_chi/presentation/nhap_chi_page.dart", "chi")
rewrite_manage_dialog("lib/features/thu_chi/presentation/nhap_thu_page.dart", "thu")

print("Replaced BottomSheet with Dialog")
