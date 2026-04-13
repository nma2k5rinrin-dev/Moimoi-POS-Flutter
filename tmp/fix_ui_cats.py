import sys
import os

def remove_default_categories(filepath, type_str):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the _defaultCategories list and remove it.
    import re
    content = re.sub(
        r'final List<TransactionCategory> _defaultCategories = \[.*?\];', 
        f"final List<TransactionCategory> _defaultCategories = []; // Removed, now seeded in AppStore", 
        content, flags=re.DOTALL
    )

    # In get _categories, we still append Thêm mới.
    # The list now just uses customCats (which contains seeded ones)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

remove_default_categories("lib/features/thu_chi/presentation/nhap_chi_page.dart", "chi")
remove_default_categories("lib/features/thu_chi/presentation/nhap_thu_page.dart", "thu")

print("Removed hardcored categories from UI")
