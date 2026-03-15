import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../models/category_model.dart';
import '../../utils/constants.dart';

class AddCategoryScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final CategoryModel? existingCategory;

  const AddCategoryScreen({
    super.key,
    this.onBack,
    this.existingCategory,
  });

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _selectedColorIndex = 0;
  int _selectedIconIndex = 0;

  bool get _isEditMode => widget.existingCategory != null;

  static const _colorPalette = [
    Color(0xFF10B981), // emerald
    Color(0xFF3B82F6), // blue
    Color(0xFFF59E0B), // amber
    Color(0xFFEF4444), // red
    Color(0xFF8B5CF6), // violet
    Color(0xFFF97316), // orange
    Color(0xFFEC4899), // pink
  ];

  static const _iconOptions = [
    Icons.local_cafe,
    Icons.restaurant,
    Icons.cake,
    Icons.ramen_dining,
    Icons.local_pizza,
    Icons.icecream,
    Icons.coffee,
    Icons.local_bar,
    Icons.lunch_dining,
    Icons.fastfood,
    Icons.breakfast_dining,
    Icons.bakery_dining,
  ];

  @override
  void initState() {
    super.initState();
    final cat = widget.existingCategory;
    if (cat != null) {
      _nameCtrl.text = cat.name;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.slate50,
      child: Column(
        children: [
          // ── Header ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                if (widget.onBack != null)
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 20, color: AppColors.slate800),
                    ),
                  ),
                const SizedBox(width: 12),
                Text(
                  _isEditMode ? 'Sửa danh mục' : 'Thêm danh mục',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Content Panel ─────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Icon Picker ───────────────────
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _showIconPicker,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: _colorPalette[_selectedColorIndex]
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: _colorPalette[_selectedColorIndex]
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Icon(
                                _iconOptions[_selectedIconIndex],
                                size: 40,
                                color: _colorPalette[_selectedColorIndex],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Chọn icon danh mục',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.slate400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Tên danh mục ─────────────────
                    const Text(
                      'Tên danh mục',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'VD: Đồ uống, Món chính...',
                        hintStyle: const TextStyle(
                            color: AppColors.slate400, fontSize: 14),
                        prefixIcon: const Icon(Icons.category_outlined,
                            color: AppColors.slate400, size: 20),
                        filled: true,
                        fillColor: AppColors.slate50,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.slate200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.slate200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.emerald400),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Mô tả (tùy chọn) ────────────
                    const Text(
                      'Mô tả (tùy chọn)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descCtrl,
                      decoration: InputDecoration(
                        hintText: 'Mô tả ngắn về danh mục',
                        hintStyle: const TextStyle(
                            color: AppColors.slate400, fontSize: 14),
                        prefixIcon: const Icon(Icons.description_outlined,
                            color: AppColors.slate400, size: 20),
                        filled: true,
                        fillColor: AppColors.slate50,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.slate200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.slate200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.emerald400),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Màu danh mục ─────────────────
                    const Text(
                      'Màu danh mục',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(_colorPalette.length, (i) {
                        final isSelected = i == _selectedColorIndex;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedColorIndex = i),
                          child: Container(
                            width: 44,
                            height: 44,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: _colorPalette[i],
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: _colorPalette[i],
                                      width: 3,
                                      strokeAlign:
                                          BorderSide.strokeAlignOutside)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: _colorPalette[i]
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),

                    // ── Action Buttons ────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onBack,
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Hủy bỏ'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.red500,
                              side: const BorderSide(
                                  color: AppColors.red500, width: 1.5),
                              minimumSize: const Size(0, 52),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveCategory,
                            icon: Icon(
                                _isEditMode
                                    ? Icons.save_outlined
                                    : Icons.add_circle_outline,
                                size: 18),
                            label: Text(
                                _isEditMode ? 'Cập nhật' : 'Thêm danh mục'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald500,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 52),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn icon',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: _iconOptions.length,
              itemBuilder: (_, i) {
                final isSelected = i == _selectedIconIndex;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedIconIndex = i);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _colorPalette[_selectedColorIndex]
                              .withValues(alpha: 0.15)
                          : AppColors.slate50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? _colorPalette[_selectedColorIndex]
                            : AppColors.slate200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      _iconOptions[i],
                      color: isSelected
                          ? _colorPalette[_selectedColorIndex]
                          : AppColors.slate500,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _saveCategory() {
    final store = context.read<AppStore>();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      store.showToast('Tên danh mục không được trống', 'error');
      return;
    }

    if (_isEditMode) {
      store.updateCategory(CategoryModel(
        id: widget.existingCategory!.id,
        name: name,
        storeId: widget.existingCategory!.storeId,
      ));
      store.showToast('Đã cập nhật danh mục "$name"!');
    } else {
      store.addCategory(name);
      store.showToast('Đã thêm danh mục "$name"!');
    }
    widget.onBack?.call();
  }
}
