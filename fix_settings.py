import os

files = {
    'lib/features/settings/presentation/sections/backup_section.dart': 'import \'package:moimoi_pos/features/settings/logic/management_store_standalone.dart\';\n',
    'lib/features/settings/presentation/sections/roles_section.dart': 'import \'package:moimoi_pos/features/settings/logic/management_store_standalone.dart\';\n',
    'lib/features/settings/presentation/settings_page.dart': 'import \'package:moimoi_pos/features/settings/logic/management_store_standalone.dart\';\n',
}

for file, content in files.items():
    with open(file, 'r', encoding='utf-8') as f:
        text = f.read()
    if 'management_store_standalone.dart' not in text:
        text = text.replace('import \'package:provider/provider.dart\';', 'import \'package:provider/provider.dart\';\n' + content)
        with open(file, 'w', encoding='utf-8') as f:
            f.write(text)

with open('lib/features/settings/presentation/sections/users_section.dart', 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace('store.mgmt.appRoles', 'store.appRoles')
with open('lib/features/settings/presentation/sections/users_section.dart', 'w', encoding='utf-8') as f:
    f.write(text)

with open('lib/features/settings/presentation/sections/tables_section.dart', 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace('store.showConfirm(', 'context.read<UIStore>().showConfirm(')
with open('lib/features/settings/presentation/sections/tables_section.dart', 'w', encoding='utf-8') as f:
    f.write(text)

with open('lib/features/settings/presentation/sections/account_section.dart', 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace('store.storeInfos', 'context.read<ManagementStore>().storeInfos')
text = text.replace('store.updateStoreInfo(', 'context.read<ManagementStore>().updateStoreInfo(')
with open('lib/features/settings/presentation/sections/account_section.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Imports and fixes applied via python.")
