import sys
import os

def fix_shadows(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Fixed addTransaction call
    old_call = "boxShadow: AppColors.shadowLg,"
    new_call = "boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 24, offset: Offset(0, 10))],"
    
    content = content.replace(old_call, new_call)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_shadows("lib/features/thu_chi/presentation/nhap_chi_page.dart")
fix_shadows("lib/features/thu_chi/presentation/nhap_thu_page.dart")

print("Fixed leftover shadowLg")
