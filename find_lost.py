import os

paths = [
    r"C:\Users\Efun\AppData\Roaming\Code\User\History",
    r"C:\Users\Efun\AppData\Roaming\Antigravity\User\History"
]

found_files = []

for history_path in paths:
    if not os.path.exists(history_path):
        continue
    for root, dirs, files in os.walk(history_path):
        for file in files:
            full_path = os.path.join(root, file)
            try:
                # read stats without reading file first to avoid reading mega files
                mtime = os.path.getmtime(full_path)
                with open(full_path, "r", encoding="utf-8", errors="ignore") as f:
                    content = f.read(5000)
                    if "class CashflowPage extends StatefulWidget" in content:
                        found_files.append((full_path, mtime))
            except Exception:
                pass

found_files.sort(key=lambda x: x[1], reverse=True)
for f in found_files[:15]:
    print(f"{f[0]} - {f[1]}")
