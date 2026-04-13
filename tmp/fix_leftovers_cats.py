import sys
import os

def fix_categories(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Fixed addTransaction call
    old_call = "category: _categories[_selectedCategory].label,"
    new_call = "category: _getCategories(store)[_selectedCategory].label,"
    
    content = content.replace(old_call, new_call)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_categories("lib/features/thu_chi/presentation/nhap_chi_page.dart")
fix_categories("lib/features/thu_chi/presentation/nhap_thu_page.dart")

print("Fixed leftover _categories")
