import sys
import os

def fix_app_store(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Import uuid
    import_str = "import 'package:uuid/uuid.dart';"
    if import_str not in content:
        content = content.replace("import 'package:drift/drift.dart' show Value;", "import 'package:drift/drift.dart' show Value;\n" + import_str)
        
    # 2. Fix the ID generation in addTransactionCategory
    old_id = "final newId = DateTime.now().millisecondsSinceEpoch.toString();"
    new_id = "final newId = const Uuid().v4();"
    content = content.replace(old_id, new_id)
    
    # 3. Fix the ID seeded generation check
    old_seed = "final cid = 'tcseed_' + DateTime.now().microsecondsSinceEpoch.toString() + '_' + defaultCats.indexOf(c).toString();"
    new_seed = "final cid = const Uuid().v4();"
    content = content.replace(old_seed, new_seed)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

def fix_nhap_page(filepath, type_str):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Change _categories getter to method _getCategories(AppStore store)
    old_getter = """  List<TransactionCategory> get _categories {
    final store = context.watch<AppStore>();
    final customCats = store.currentCustomThuChiCategories.where((c) => c.type == '""" + type_str + """').toList();
    return [
      ..._defaultCategories,
      ...customCats,
      const TransactionCategory(type: '""" + type_str + """', emoji: '➕', label: 'Thêm mới', color: AppColors.slate400, isCustom: false),
    ];
  }"""
    
    new_getter = """  List<TransactionCategory> _getCategories(AppStore store) {
    final customCats = store.currentCustomThuChiCategories.where((c) => c.type == '""" + type_str + """').toList();
    return [
      ..._defaultCategories,
      ...customCats,
      const TransactionCategory(type: '""" + type_str + """', emoji: '➕', label: 'Thêm mới', color: AppColors.slate400, isCustom: false),
    ];
  }"""

    content = content.replace(old_getter, new_getter)

    # In _buildCategoryGrid, it calls final currentCats = _categories;
    # Now it should be: final currentCats = _getCategories(context.watch<AppStore>());
    content = content.replace("final currentCats = _categories;", "final currentCats = _getCategories(context.watch<AppStore>());")

    # In onSave of AddCategoryDialog, it uses _categories.length
    # Because it is inside setState, we must use context.read
    old_dialog_save = """        onSave: (name, emoji, color) {
          final store = context.read<AppStore>();
          store.addTransactionCategory(TransactionCategory(type: '"""+type_str+"""', emoji: emoji, label: name, color: color, isCustom: true));
          setState(() {
            _selectedCategory = _categories.length - 1;
          });
        },"""
        
    new_dialog_save = """        onSave: (name, emoji, color) {
          final store = context.read<AppStore>();
          store.addTransactionCategory(TransactionCategory(type: '"""+type_str+"""', emoji: emoji, label: name, color: color, isCustom: true));
          setState(() {
            _selectedCategory = _getCategories(context.read<AppStore>()).length - 1;
          });
        },"""

    content = content.replace(old_dialog_save, new_dialog_save)

    # In onSave of Edit Dialog
    content = content.replace("_selectedCategory = _categories.length - 1;", "_selectedCategory = _getCategories(context.read<AppStore>()).length - 1;")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_app_store("lib/core/state/app_store.dart")
fix_nhap_page("lib/features/thu_chi/presentation/nhap_chi_page.dart", "chi")
fix_nhap_page("lib/features/thu_chi/presentation/nhap_thu_page.dart", "thu")

print("Fixed UUID insert bug and Provider watch bug")
