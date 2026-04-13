import os

file_path = "lib/features/cashflow/presentation/cashflow_page.dart"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.read().splitlines()

# Extract the good dialog (lines 1338 to 1457, 0-indexed)
good_dialog_lines = lines[1338:1457]
good_dialog = "\n".join(good_dialog_lines)

# Extract the good _DisplayTxn (lines 1313 to 1337)
display_txn_lines = lines[1313:1337]
display_txn = "\n".join(display_txn_lines) + "\n}"

# Find the old _showTransactionDialog
old_dialog_start = -1
old_dialog_end = -1
for i, line in enumerate(lines):
    if "void _showTransactionDialog(DateTime date) {" in line:
        old_dialog_start = i
        # find the end of it
        for j in range(i, len(lines)):
            if lines[j].startswith("  }"):
                old_dialog_end = j
                break
        break

if old_dialog_start != -1:
    lines = lines[:old_dialog_start] + good_dialog_lines + lines[old_dialog_end+1:]

# Now slice off everything from `class _DisplayTxn {`
cut_start = -1
for i, line in enumerate(lines):
    if line.startswith("class _DisplayTxn {"):
        cut_start = i
        break

if cut_start != -1:
    lines = lines[:cut_start]

# Assemble final
final_text = "\n".join(lines) + "\n}\n\n" + display_txn + "\n"

with open(file_path, "w", encoding="utf-8") as f:
    f.write(final_text)

print("SUCCESS")
