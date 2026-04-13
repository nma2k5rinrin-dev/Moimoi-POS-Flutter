import sys

with open('lib/features/thu_chi/presentation/nhap_thu_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import 'package:shared_preferences/shared_preferences.dart';", "")
content = content.replace("import 'dart:convert';", "")

old_cat_props = """  List<ThuChiCategory> _categories = [];

  final List<ThuChiCategory> _defaultCategories = [
    const ThuChiCategory(emoji: '🍽️', label: 'Nguyên liệu', color: AppColors.emerald500),
    const ThuChiCategory(emoji: '🔧', label: 'Biên mức', color: AppColors.blue500),
    const ThuChiCategory(emoji: '⏰', label: 'Tiền điện', color: AppColors.amber500),
    const ThuChiCategory(emoji: '🚚', label: 'Vận chuyển', color: AppColors.violet500),
    const ThuChiCategory(emoji: '🛠', label: 'Sửa chữa', color: AppColors.orange500),
    const ThuChiCategory(emoji: '👥', label: 'Lương NV', color: AppColors.red500),
    const ThuChiCategory(emoji: '📢', label: 'Marketing', color: Color(0xFF9333EA)),
    const ThuChiCategory(emoji: '📦', label: 'Khác', color: AppColors.slate500),
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
  }

  Future<void> _loadCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString('custom_thu_categories');
    
    List<ThuChiCategory> customCats = [];
    if (jsonStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        customCats = decoded.map((e) => ThuChiCategory.fromMap(e as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Error decoding custom thu categories: $e');
      }
    }

    setState(() {
      _categories = [
        ..._defaultCategories,
        ...customCats,
        const ThuChiCategory(emoji: '➕', label: 'Thêm mới', color: AppColors.slate400),
      ];
    });
  }

  Future<void> _saveCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final customCats = _categories.where((c) => c.isCustom).map((c) => c.toMap()).toList();
    await prefs.setString('custom_thu_categories', jsonEncode(customCats));
  }"""
  
new_cat_props = """  final List<ThuChiCategory> _defaultCategories = [
    const ThuChiCategory(type: 'thu', emoji: '🍽️', label: 'Nguyên liệu', color: AppColors.emerald500, isCustom: false),
    const ThuChiCategory(type: 'thu', emoji: '🔧', label: 'Biên mức', color: AppColors.blue500, isCustom: false),
    const ThuChiCategory(type: 'thu', emoji: '⏰', label: 'Tiền điện', color: AppColors.amber500, isCustom: false),
    const ThuChiCategory(type: 'thu', emoji: '🚚', label: 'Vận chuyển', color: AppColors.violet500, isCustom: false),
    const ThuChiCategory(type: 'thu', emoji: '🛠', label: 'Sửa chữa', color: AppColors.orange500, isCustom: false),
    const ThuChiCategory(type: 'thu', emoji: '👥', label: 'Lương NV', color: AppColors.red500, isCustom: false),
    const ThuChiCategory(type: 'thu', emoji: '📢', label: 'Marketing', color: Color(0xFF9333EA), isCustom: false),
    const ThuChiCategory(type: 'thu', emoji: '📦', label: 'Khác', color: AppColors.slate500, isCustom: false),
  ];

  List<ThuChiCategory> get _categories {
    final store = context.watch<AppStore>();
    final customCats = store.currentCustomThuChiCategories.where((c) => c.type == 'thu').toList();
    return [
      ..._defaultCategories,
      ...customCats,
      const ThuChiCategory(type: 'thu', emoji: '➕', label: 'Thêm mới', color: AppColors.slate400, isCustom: false),
    ];
  }"""

content = content.replace(old_cat_props, new_cat_props)


old_save = """                          final store = context.read<AppStore>();
                          store.addTransaction(
                            type: 'thu',
                            amount: amount,
                            category: _categories[_selectedCategory].label,
                            note: _noteCtrl.text,
                            time: _selectedDate.toIso8601String(),
                          );"""
new_save = """                          final store = context.read<AppStore>();
                          final currentCats = _categories;
                          if (_selectedCategory >= currentCats.length) {
                             _selectedCategory = currentCats.length > 1 ? currentCats.length - 2 : 0;
                          }
                          store.addTransaction(
                            type: 'thu',
                            amount: amount,
                            category: currentCats[_selectedCategory].label,
                            note: _noteCtrl.text,
                            time: _selectedDate.toIso8601String(),
                          );"""
content = content.replace(old_save, new_save)

old_add_dialog = """  void _showAddCategoryDialog() {
    showAddCategoryDialog(
      context: context,
      type: 'thu',
      onSave: (name, emoji, color) {
        setState(() {
          _categories.insert(_categories.length - 1,
              ThuChiCategory(emoji: emoji, label: name, color: color, isCustom: true));
          _selectedCategory = _categories.length - 2;
        });
        _saveCustomCategories();
      },
    );
  }"""
new_add_dialog = """  void _showAddCategoryDialog() {
    showAddCategoryDialog(
      context: context,
      type: 'thu',
      onSave: (name, emoji, color) {
        final store = context.read<AppStore>();
        store.addThuChiCategory(ThuChiCategory(type: 'thu', emoji: emoji, label: name, color: color, isCustom: true));
        setState(() {
          _selectedCategory = _categories.length - 1;
        });
      },
    );
  }"""
content = content.replace(old_add_dialog, new_add_dialog)


old_update_exact = """                    onSave: (name, emoji, color) {
                      setState(() {
                        _categories[index] = ThuChiCategory(
                            emoji: emoji, label: name, color: color, isCustom: true);
                        _selectedCategory = index;
                      });
                      _saveCustomCategories();
                    },"""
new_update_exact = """                    onSave: (name, emoji, color) {
                      final store = context.read<AppStore>();
                      store.updateThuChiCategory(
                        ThuChiCategory(
                          id: cat.id, storeId: cat.storeId, type: 'thu',
                          emoji: emoji, label: name, color: color, isCustom: true
                        )
                      );
                      setState(() {
                         _selectedCategory = index;
                      });
                    },"""
content = content.replace(old_update_exact, new_update_exact)


old_delete_exact = """                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _categories.removeAt(index);
                    if (_selectedCategory == index) {
                      _selectedCategory = 0;
                    } else if (_selectedCategory > index) {
                      _selectedCategory -= 1;
                    }
                  });
                  _saveCustomCategories();
                },"""
new_delete_exact = """                onTap: () {
                  Navigator.pop(ctx);
                  final store = context.read<AppStore>();
                  store.deleteThuChiCategory(cat.id!);
                  setState(() {
                    if (_selectedCategory == index) {
                      _selectedCategory = 0;
                    } else if (_selectedCategory > index) {
                      _selectedCategory -= 1;
                    }
                  });
                },"""
content = content.replace(old_delete_exact, new_delete_exact)

with open('lib/features/thu_chi/presentation/nhap_thu_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

