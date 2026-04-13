import sys
import os

def rename_in_file(filepath, replacements):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    for old, new in replacements:
        content = content.replace(old, new)
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

replacements_sync = [
    ("markThuChi", "markTransaction"),
    ("pullTransactions", "pullTransactions"),  # Keep intact 
    ("last_pull_thuchi_at", "last_pull_transactions_at"),
    ("upsertThuChi", "upsertTransaction"),
    ("LocalThuChiCompanion", "LocalTransactionsCompanion"),
]

rename_in_file("lib/core/sync/sync_engine.dart", replacements_sync)

replacements_db = [
    ("LocalTransactionData", "LocalTransaction"),
]

rename_in_file("lib/core/database/app_database.dart", replacements_db)

print("Fixed sync_engine.dart and app_database.dart")
