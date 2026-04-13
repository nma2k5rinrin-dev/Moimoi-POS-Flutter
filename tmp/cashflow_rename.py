import os

replacements = [
    # Paths
    ('features/thu_chi/', 'features/cashflow/'),
    ('thu_chi_page.dart', 'cashflow_page.dart'),
    ('nhap_thu_page.dart', 'income_page.dart'),
    ('nhap_chi_page.dart', 'expense_page.dart'),
    ('thu_chi_category_model.dart', 'transaction_category_model.dart'),
    ('thu_chi_transaction_model.dart', 'transaction_model.dart'),
    
    # Class names
    ('ThuChiPage', 'CashflowPage'),
    ('_ThuChiPageState', '_CashflowPageState'),
    ('NhapThuPage', 'IncomePage'),
    ('_NhapThuPageState', '_IncomePageState'),
    ('NhapChiPage', 'ExpensePage'),
    ('_NhapChiPageState', '_ExpensePageState'),
    
    # Left over class renames (since some transaction categories were renamed, but we'll do paths anyway)
]

def rename_in_file(filepath):
    # Only process dart files
    if not filepath.endswith('.dart'):
        return
        
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    new_content = content
    for old, new in replacements:
        new_content = new_content.replace(old, new)
        
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for root, dirs, files in os.walk('d:/Moimoi-POS-Flutter/lib'):
    for file in files:
        filepath = os.path.join(root, file)
        rename_in_file(filepath)

print("Done")
