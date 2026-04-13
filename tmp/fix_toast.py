import sys
import os

def insert_toast(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Nhap Chi Page
    old_code = """          onLongPress: () {
            if (cat.isCustom) {
              _showManageCategoryOptions(i, cat);
            }
          },"""
          
    new_code = """          onLongPress: () {
            if (cat.isCustom) {
              _showManageCategoryOptions(i, cat);
            } else if (cat.label != 'Thêm mới') {
              context.read<AppStore>().showToast('Đây là danh mục hệ thống, chỉ có thể sửa/xóa danh mục Tự Thêm.');
            }
          },"""
          
    content = content.replace(old_code, new_code)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

insert_toast("lib/features/thu_chi/presentation/nhap_chi_page.dart")
insert_toast("lib/features/thu_chi/presentation/nhap_thu_page.dart")

print("Added toast message for long press")
