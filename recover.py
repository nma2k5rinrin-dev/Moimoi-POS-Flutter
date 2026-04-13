import os
import subprocess

scripts = [
    "patch.py",
    "replace.py",
    "patch_layout.py",
    "restore_calendar.py",
    "patch_month.py",
    "patch_styles.py",
    "update_ui.py",
    "update_ui_2.py",
    "update_ui_3.py",
    "update_ui_4.py",
    "update_ui_5.py"
]

for s in scripts:
    print(f"Running {s}...")
    subprocess.run(["python", s])
