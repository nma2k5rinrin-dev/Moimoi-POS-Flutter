import re

with open('lib/features/dashboard/presentation/admin/admin_dashboard_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

print(f'Original lines: {content.count(chr(10))}')

# 1. Replace imports block - remove unused imports and add store_detail_page import
old_imports = (
    "import 'dart:convert';\r\n"
    "import 'dart:ui';\r\n"
    "import 'dart:math';\r\n"
    "import 'package:flutter/material.dart';\r\n"
    "import 'package:provider/provider.dart';\r\n"
    "import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';\r\n"
    "import 'package:moimoi_pos/core/state/ui_store.dart';\r\n"
    "import 'package:moimoi_pos/features/settings/models/store_info_model.dart';\r\n"
    "\r\n"
    "import 'package:moimoi_pos/features/premium/models/premium_payment_model.dart';\r\n"
    "import 'package:moimoi_pos/core/utils/constants.dart';\r\n"
    "import 'package:moimoi_pos/features/notifications/presentation/notification_bell.dart';\r\n"
    "import 'package:moimoi_pos/core/widgets/date_range_picker_dialog.dart';\r\n"
    "import 'package:moimoi_pos/services/api/cloudflare_service.dart';\r\n"
    "import 'package:cached_network_image/cached_network_image.dart';\r\n"
)

new_imports = (
    "import 'dart:convert';\r\n"
    "import 'dart:ui';\r\n"
    "import 'package:flutter/material.dart';\r\n"
    "import 'package:provider/provider.dart';\r\n"
    "import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';\r\n"
    "import 'package:moimoi_pos/core/state/ui_store.dart';\r\n"
    "import 'package:moimoi_pos/features/settings/models/store_info_model.dart';\r\n"
    "import 'package:moimoi_pos/features/premium/models/premium_payment_model.dart';\r\n"
    "import 'package:moimoi_pos/core/utils/constants.dart';\r\n"
    "import 'package:moimoi_pos/core/widgets/date_range_picker_dialog.dart';\r\n"
    "import 'package:moimoi_pos/features/dashboard/presentation/admin/store_detail_page.dart';\r\n"
)

if old_imports in content:
    content = content.replace(old_imports, new_imports, 1)
    print('Imports replaced OK')
else:
    print('WARNING: Could not find imports block - trying line-by-line approach')
    # Fallback: just add the import after the existing imports
    content = content.replace(
        "import 'package:cached_network_image/cached_network_image.dart';",
        "import 'package:moimoi_pos/features/dashboard/presentation/admin/store_detail_page.dart';",
        1
    )

# 2. Replace both _StoreDetailPage nav calls with StoreDetailPage
old_nav = "builder: (_) => _StoreDetailPage("
new_nav = "builder: (_) => StoreDetailPage("
count = content.count(old_nav)
content = content.replace(old_nav, new_nav)
print(f'Replaced {count} _StoreDetailPage nav calls')

# 3. Replace _SparklinePainter with SparklinePainter  
old_sp = "painter: _SparklinePainter("
new_sp = "painter: SparklinePainter("
count2 = content.count(old_sp)
content = content.replace(old_sp, new_sp)
print(f'Replaced {count2} _SparklinePainter refs')

# 4. Find where _StoreDetailPage class starts and cut from there
# Try different marker patterns
markers = [
    '// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\r\n// STORE DETAIL PAGE',
    'class _StoreDetailPage extends StatefulWidget',
]
cut_idx = -1
for marker in markers:
    idx = content.find(marker)
    if idx != -1:
        cut_idx = idx
        print(f'Found cut marker at index {idx}')
        break

if cut_idx != -1:
    content = content[:cut_idx].rstrip() + '\r\n'
else:
    print('WARNING: No cut marker found, keeping file as-is')

with open('lib/features/dashboard/presentation/admin/admin_dashboard_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

final_lines = content.count('\r\n')
print(f'Done. Final lines: {final_lines}')
