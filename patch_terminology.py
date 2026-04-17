import os, re
replacements = [
    (r"\b(\d+)\s+món\b", r"\1 sản phẩm"),
    (r"Thêm món", "Thêm sản phẩm"),
    (r"Sửa món", "Sửa sản phẩm"),
    (r"Món bán chạy", "Sản phẩm bán chạy"),
    (r"Món chính", "Sản phẩm chính"),
    (r"các món", "các sản phẩm"),
    (r"đặt món", "đặt hàng"),
    (r"món vào đơn", "sản phẩm vào đơn"),
]

for root, _, files in os.walk("d:/Moimoi-POS-Flutter/lib"):
    for file in files:
        if file.endswith(".dart"):
            filepath = os.path.join(root, file)
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()
            original = content
            for pat, repl in replacements:
                content = re.sub(pat, repl, content, flags=re.IGNORECASE)
            if content != original:
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(content)
                print(f"Updated {filepath}")
