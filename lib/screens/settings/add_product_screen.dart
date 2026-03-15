import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../utils/constants.dart';

/// Formats number with thousand separators (e.g. 15000 → 15.000)
class _ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) return newValue;
    final number = int.tryParse(digits);
    if (number == null) return oldValue;
    final formatted = _formatNumber(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class AddProductScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final ProductModel? existingProduct;

  const AddProductScreen({
    super.key,
    this.onBack,
    this.existingProduct,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedCategory = '';
  bool _isOutOfStock = false;
  bool _isHot = false;
  bool _showImagePicker = false;

  // Image
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  String _imageUrl = '';

  bool get _isEditMode => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;
    if (p != null) {
      _nameCtrl.text = p.name;
      _priceCtrl.text = _ThousandSeparatorFormatter._formatNumber(p.price.toInt());
      _descCtrl.text = p.description;
      _selectedCategory = p.category;
      _isOutOfStock = p.isOutOfStock;
      _isHot = p.isHot;
      _imageUrl = p.image;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final categories = store.currentCategories;

    return Stack(
      children: [
        // ── Main Content ──────────────────────────
        Container(
          color: AppColors.slate50,
          child: Column(
            children: [
              // ── Header ────────────────────────────
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
                      _isEditMode ? 'Sửa sản phẩm' : 'Thêm sản phẩm',
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

              // ── Content Panel ─────────────────────
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
                        // ── Image Upload Area ─────────
                        Center(
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () => setState(
                                    () => _showImagePicker = true),
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: AppColors.slate50,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppColors.slate200,
                                        width: 1.5),
                                  ),
                                  child: _buildImagePreview(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isEditMode
                                    ? 'Thay đổi ảnh sản phẩm'
                                    : 'Thêm ảnh sản phẩm',
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

                        // ── Tên sản phẩm ─────────────
                        const Text('Tên sản phẩm',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate700)),
                        const SizedBox(height: 8),
                        _buildInput(
                          controller: _nameCtrl,
                          hint: 'VD: Phở bò, Trà sữa...',
                          icon: Icons.restaurant_menu_rounded,
                        ),
                        const SizedBox(height: 20),

                        // ── Giá bán + Đơn vị ─────────
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text('Giá bán',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.slate700)),
                                  const SizedBox(height: 8),
                                  _buildInput(
                                    controller: _priceCtrl,
                                    hint: '0 đ',
                                    icon: Icons
                                        .monetization_on_outlined,
                                    keyboardType:
                                        TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter
                                          .digitsOnly,
                                      _ThousandSeparatorFormatter(),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text('Đơn vị',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.slate700)),
                                  const SizedBox(height: 8),
                                  _buildInput(
                                    controller: _unitCtrl,
                                    hint: 'VD: Phần, Ly, Tô',
                                    icon: Icons.straighten_outlined,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── Danh mục ─────────────────
                        const Text('Danh mục',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate700)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: AppColors.slate200),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedCategory.isNotEmpty
                                ? _selectedCategory
                                : null,
                            hint: Row(
                              children: [
                                Icon(Icons.sell_outlined,
                                    color: AppColors.slate400,
                                    size: 20),
                                const SizedBox(width: 10),
                                Text('Chọn danh mục',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.slate400)),
                              ],
                            ),
                            isExpanded: true,
                            underline: const SizedBox(),
                            icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.slate400),
                            items: [
                              const DropdownMenuItem(
                                  value: '',
                                  child: Text('Không có')),
                              ...categories.map((c) =>
                                  DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name))),
                            ],
                            onChanged: (v) => setState(
                                () => _selectedCategory = v ?? ''),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Mô tả (tùy chọn) ────────
                        const Text('Mô tả (tùy chọn)',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate700)),
                        const SizedBox(height: 8),
                        _buildInput(
                          controller: _descCtrl,
                          hint: 'Mô tả ngắn về sản phẩm',
                          icon: Icons.description_outlined,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 20),

                        // ── Toggle: Còn hàng ─────────
                        _buildToggleRow(
                          icon: Icons.inventory_2_outlined,
                          iconColor: _isOutOfStock
                              ? AppColors.red500
                              : AppColors.emerald500,
                          label: 'Tình trạng kho',
                          subtitle: _isOutOfStock
                              ? 'Hết hàng'
                              : 'Còn hàng',
                          value: !_isOutOfStock,
                          activeColor: AppColors.emerald500,
                          onChanged: (v) =>
                              setState(() => _isOutOfStock = !v),
                        ),
                        const SizedBox(height: 12),

                        // ── Toggle: Bán chạy ─────────
                        _buildToggleRow(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: _isHot
                              ? AppColors.orange500
                              : AppColors.slate400,
                          label: 'Sản phẩm bán chạy',
                          subtitle: _isHot
                              ? 'Đang là sản phẩm bán chạy'
                              : 'Không phải sản phẩm bán chạy',
                          value: _isHot,
                          activeColor: AppColors.orange500,
                          onChanged: (v) =>
                              setState(() => _isHot = v),
                        ),
                        const SizedBox(height: 32),

                        // ── Action Buttons ────────────
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: widget.onBack,
                                icon: const Icon(Icons.close,
                                    size: 18),
                                label: const Text('Hủy bỏ'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.red500,
                                  side: const BorderSide(
                                      color: AppColors.red500,
                                      width: 1.5),
                                  minimumSize: const Size(0, 52),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                  textStyle: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _saveProduct,
                                icon: Icon(
                                    _isEditMode
                                        ? Icons.save_outlined
                                        : Icons.add_circle_outline,
                                    size: 18),
                                label: Text(_isEditMode
                                    ? 'Cập nhật'
                                    : 'Thêm sản phẩm'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppColors.emerald500,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 52),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                  textStyle: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
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
        ),

        // ── Image picker overlay with blur ────────
        if (_showImagePicker) _buildImagePickerOverlay(),
      ],
    );
  }

  // ── Image picker centered panel with blur ─────
  Widget _buildImagePickerOverlay() {
    return Stack(
      children: [
        // Blurred background
        Positioned.fill(
          child: GestureDetector(
            onTap: () => setState(() => _showImagePicker = false),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
        // Centered panel
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                const Text('Chọn ảnh sản phẩm',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate800)),
                const SizedBox(height: 20),
                // Two options
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _doPickImage(ImageSource.camera),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: AppColors.blue50,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: AppColors.blue200),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.camera_alt_rounded,
                                  color: Color(0xFF3B82F6), size: 40),
                              const SizedBox(height: 8),
                              Text('Máy ảnh',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Color(0xFF3B82F6))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            _doPickImage(ImageSource.gallery),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: AppColors.emerald50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.emerald200),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.photo_library_rounded,
                                  color: AppColors.emerald500,
                                  size: 40),
                              const SizedBox(height: 8),
                              Text('Thư viện',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppColors.emerald500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _showImagePicker = false),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.slate500,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Hủy',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    // Show picked image
    if (_pickedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Image.network(
          _pickedImage!.path,
          fit: BoxFit.cover,
          width: 120,
          height: 120,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
        ),
      );
    }
    // Show existing image URL (edit mode)
    if (_imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Image.network(
          _imageUrl,
          fit: BoxFit.cover,
          width: 120,
          height: 120,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
        ),
      );
    }
    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            size: 36, color: AppColors.slate300),
      ],
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate700)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.slate400)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: activeColor,
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.slate400, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.slate400, size: 20),
        filled: true,
        fillColor: AppColors.slate50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emerald400),
        ),
      ),
    );
  }

  Future<void> _doPickImage(ImageSource source) async {
    setState(() => _showImagePicker = false);

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _pickedImage = picked;
          _imageUrl = picked.path;
        });
      }
    } catch (e) {
      if (mounted) {
        context.read<AppStore>().showToast(
            'Không thể chọn ảnh. Vui lòng thử lại.', 'error');
      }
    }
  }

  void _saveProduct() {
    final store = context.read<AppStore>();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      store.showToast('Tên sản phẩm không được trống', 'error');
      return;
    }
    final priceText = _priceCtrl.text.replaceAll('.', '');
    final price = double.tryParse(priceText) ?? 0;
    if (price <= 0) {
      store.showToast('Giá phải lớn hơn 0', 'error');
      return;
    }

    if (_isEditMode) {
      store.updateProduct(widget.existingProduct!.copyWith(
        name: name,
        price: price,
        image: _imageUrl,
        category: _selectedCategory,
        description: _descCtrl.text.trim(),
        isOutOfStock: _isOutOfStock,
        isHot: _isHot,
      ));
      store.showToast('Đã cập nhật sản phẩm "$name"!');
    } else {
      store.addProduct(ProductModel(
        id: '',
        name: name,
        price: price,
        image: _imageUrl,
        category: _selectedCategory,
        description: _descCtrl.text.trim(),
        isOutOfStock: _isOutOfStock,
        isHot: _isHot,
      ));
      store.showToast('Đã thêm sản phẩm "$name"!');
    }
    widget.onBack?.call();
  }
}
