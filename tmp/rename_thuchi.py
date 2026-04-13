import sys
import os
import glob

def rename_in_file(filepath, replacements):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    for old, new in replacements:
        content = content.replace(old, new)
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

replacements = [
    # Supabase tables
    ("'thu_chi_categories'", "'transaction_categories'"),
    ('"thu_chi_categories"', '"transaction_categories"'),
    
    # Drift Class names
    ("LocalThuChiCategories", "LocalTransactionCategories"),
    ("localThuChiCategories", "localTransactionCategories"),
    ("LocalThuChiCategory", "LocalTransactionCategory"),
    
    ("LocalThuChiCompanion", "LocalTransactionsCompanion"),
    ("localThuChi", "localTransactions"),
    ("LocalThuChiData", "LocalTransactionData"),
    ("LocalThuChi", "LocalTransactions"),
    
    ("getThuChiCategories", "getTransactionCategories"),
    ("upsertThuChiCategory", "upsertTransactionCategory"),
    ("deleteThuChiCategory", "deleteTransactionCategory"),
    ("replaceAllThuChiCategories", "replaceAllTransactionCategories"),

    ("getThuChi", "getTransactions"),
    ("upsertThuChi", "upsertTransaction"),
    ("deleteThuChi", "deleteTransaction"),
    ("markThuChi", "markTransaction"),
    ("replaceAllThuChi", "replaceAllTransactions"),
    
    # AppStore methods
    ("customThuChiCategories", "customTransactionCategories"),
    ("fetchThuChiCategories", "fetchTransactionCategories"),
    ("addThuChiCategory", "addTransactionCategory"),
    ("updateThuChiCategory", "updateTransactionCategory"),
    ("ThuChiCategory", "TransactionCategory"),
]

files_to_modify = [
    "lib/core/database/app_database.dart",
    "lib/core/state/app_store.dart",
    "lib/features/thu_chi/models/thu_chi_transaction_model.dart",
    "lib/features/thu_chi/models/thu_chi_category_model.dart",
    "lib/features/thu_chi/presentation/nhap_thu_page.dart",
    "lib/features/thu_chi/presentation/nhap_chi_page.dart",
    "lib/features/thu_chi/presentation/thu_chi_page.dart",
    "lib/features/settings/presentation/settings_page.dart",
]

for f in files_to_modify:
    rename_in_file(f, replacements)

# Create the supabase migration
migration_path = "supabase/migrations/20260401010000_rename_transaction_categories.sql"
with open(migration_path, "w", encoding="utf-8") as f:
    f.write('''-- Rename the table from thu_chi_categories to transaction_categories

ALTER TABLE IF EXISTS thu_chi_categories RENAME TO transaction_categories;
''')

print("Renaming completed via python script!")
