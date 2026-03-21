import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../models/product_model.dart';
import '../../utils/constants.dart';
import '../../utils/avatar_picker.dart';
import '../../widgets/square_crop_dialog.dart';

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

class AddProductPanel extends StatefulWidget {
  final VoidCallback onClose;
  final ProductModel? existingProduct;

  const AddProductPanel({
    super.key,
    required this.onClose,
    this.existingProduct,
  });

  @override
  State<AddProductPanel> createState() => _AddProductPanelState();
}

class _AddProductPanelState extends State<AddProductPanel>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  String _selectedCategory = '';
  bool _isOutOfStock = false;
  bool _isHot = false;

  // Image
  final ImagePicker _picker = ImagePicker();
  String _imageUrl = '';

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool get _isEditMode => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;
    if (p != null) {
      _nameCtrl.text = p.name;
      _priceCtrl.text =
          _ThousandSeparatorFormatter._formatNumber(p.price.toInt());
      _selectedCategory = p.category;
      _isOutOfStock = p.isOutOfStock;
      _isHot = p.isHot;
      _imageUrl = p.image;
      if (p.description.isNotEmpty) {
        _descCtrl.text = p.description;
      }
      if (p.quantity > 0) {
        _qtyCtrl.text = p.quantity.toString();
      }
      if (p.costPrice > 0) {
        _costPriceCtrl.text = _ThousandSeparatorFormatter._formatNumber(p.costPrice.toInt());
      }
    }

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _costPriceCtrl.dispose();
    _unitCtrl.dispose();
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _closeWithAnimation() async {
    await _animCtrl.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final categories = store.currentCategories;

    return Material(
      type: MaterialType.transparency,
      child: FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          // ── Dim Overlay ─────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeWithAnimation,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),

          // ── Panel ───────────────────────────
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).padding.top + 40,
            child: Center(
            child: SlideTransition(
              position: _slideAnim,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 480,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Panel Header ──────────────
                    _buildHeader(),

                    // ── Form Body ────────────────
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Image Upload Area ────
                            _buildImageSection(),
                            const SizedBox(height: 18),

                            // ── Tên sản phẩm ────────
                            _buildLabel('Tên sản phẩm'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _nameCtrl,
                              hint: 'VD: Trà sữa trân châu...',
                              icon: Icons.restaurant,
                            ),
                            const SizedBox(height: 18),

                            // ── Giá + Đơn vị ────────
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel('Giá bán'),
                                      const SizedBox(height: 6),
                                      _buildTextField(
                                        controller: _priceCtrl,
                                        hint: '0',
                                        icon: Icons.monetization_on_outlined,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          _ThousandSeparatorFormatter(),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel('Đơn vị'),
                                      const SizedBox(height: 6),
                                      _buildTextField(
                                        controller: _unitCtrl,
                                        hint: 'VD: ly, phần...',
                                        icon: Icons.straighten_outlined,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // ── Giá gốc ─────────────
                            _buildLabel('Giá gốc (tùy chọn)'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _costPriceCtrl,
                              hint: '0',
                              icon: Icons.price_change_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _ThousandSeparatorFormatter(),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // ── Danh mục ─────────────
                            _buildLabel('Danh mục'),
                            const SizedBox(height: 6),
                            _buildCategoryDropdown(categories),
                            const SizedBox(height: 18),

                            // ── Mô tả ────────────────
                            _buildLabel('Mô tả (tùy chọn)'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _descCtrl,
                              hint: 'Mô tả ngắn về sản phẩm',
                              icon: Icons.description_outlined,
                            ),
                            const SizedBox(height: 18),

                            // ── Số lượng ─────────────
                            _buildLabel('Số lượng tồn kho'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _qtyCtrl,
                              hint: '0 = không giới hạn',
                              icon: Icons.inventory_2_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                            const SizedBox(height: 18),

                            // ── Toggle Switches ──────
                            _buildToggleRow(
                              icon: Icons.local_fire_department_rounded,
                              iconColor: const Color(0xFFF59E0B),
                              bgColor: const Color(0xFFFFF7ED),
                              label: 'Bán chạy',
                              desc: 'Đánh dấu sản phẩm bán chạy',
                              value: _isHot,
                              onChanged: (v) => setState(() => _isHot = v),
                            ),
                            const SizedBox(height: 10),
                            _buildToggleRow(
                              icon: Icons.remove_shopping_cart_outlined,
                              iconColor: AppColors.red500,
                              bgColor: const Color(0xFFFEF2F2),
                              label: 'Hết hàng',
                              desc: 'Tạm ngưng bán sản phẩm',
                              value: _isOutOfStock,
                              onChanged: (v) => setState(() => _isOutOfStock = v),
                            ),
                            const SizedBox(height: 18),

                            // ── Action Buttons ───────
                            _buildButtons(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    ),
    );
  }

  // ── Panel Header with gradient ──────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.emerald50, Colors.white],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.add_shopping_cart_rounded,
              color: AppColors.emerald600, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isEditMode ? 'Sửa sản phẩm' : 'Thêm sản phẩm',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.slate800,
              ),
            ),
          ),
          GestureDetector(
            onTap: _closeWithAnimation,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(16),
              ),
              child:
                  const Icon(Icons.close, size: 18, color: AppColors.slate500),
            ),
          ),
        ],
      ),
    );
  }

  // ── Image Section ───────────────────────────────
  Widget _buildImageSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showImagePickerDialog,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate200, width: 2),
              ),
              child: _buildImagePreview(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isEditMode ? 'Thay đổi ảnh sản phẩm' : 'Thêm ảnh sản phẩm',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.slate400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    // Base64 data URI (from crop dialog)
    if (_imageUrl.startsWith('data:')) {
      final base64Part = _imageUrl.split(',').last;
      final bytes = base64Decode(base64Part);
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: 120,
          height: 120,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
        ),
      );
    }
    if (_imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
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
            size: 36, color: AppColors.slate400),
      ],
    );
  }

  // ── Label ───────────────────────────────────────
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.slate600,
      ),
    );
  }

  // ── Text Field ──────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.slate400, size: 18),
        filled: true,
        fillColor: Colors.white,
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

  // ── Category Dropdown ───────────────────────────
  Widget _buildCategoryDropdown(List categories) {
    final catFieldKey = GlobalKey();
    final selectedName = categories
        .where((c) => c.id == _selectedCategory)
        .map((c) => c.name)
        .firstOrNull ?? '';
    final hasValue = _selectedCategory.isNotEmpty && selectedName.isNotEmpty;

    return GestureDetector(
      key: catFieldKey,
      onTap: () {
        final renderBox = catFieldKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final position = renderBox.localToGlobal(Offset.zero);
        final fieldSize = renderBox.size;
        final screenHeight = MediaQuery.of(catFieldKey.currentContext!).size.height;

        final items = <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: '',
            height: 48,
            child: Text('Không có', style: TextStyle(fontSize: 14, color: AppColors.slate500)),
          ),
          ...categories.map((c) => PopupMenuItem<String>(
            value: c.id,
            height: 48,
            child: Row(
              children: [
                Icon(Icons.sell_outlined, size: 16,
                    color: c.id == _selectedCategory ? AppColors.emerald600 : AppColors.slate400),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(c.name, style: TextStyle(
                    fontSize: 14,
                    fontWeight: c.id == _selectedCategory ? FontWeight.w700 : FontWeight.w500,
                    color: c.id == _selectedCategory ? AppColors.emerald600 : AppColors.slate800,
                  )),
                ),
                if (c.id == _selectedCategory)
                  const Icon(Icons.check_circle, size: 18, color: AppColors.emerald600),
              ],
            ),
          )),
        ];

        final totalMenuHeight = items.length * 48.0 + 16;
        final spaceBelow = screenHeight - position.dy - fieldSize.height;
        final dropUp = spaceBelow < totalMenuHeight && position.dy > totalMenuHeight;
        final menuTop = dropUp
            ? position.dy - totalMenuHeight
            : position.dy + fieldSize.height;

        showMenu<String>(
          context: catFieldKey.currentContext!,
          position: RelativeRect.fromLTRB(
            position.dx,
            menuTop,
            position.dx + fieldSize.width,
            menuTop + totalMenuHeight,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 8,
          constraints: BoxConstraints(
            minWidth: fieldSize.width,
            maxWidth: fieldSize.width,
          ),
          items: items,
        ).then((v) {
          if (v != null) setState(() => _selectedCategory = v);
        });
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          children: [
            Icon(Icons.sell_outlined, color: AppColors.slate400, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasValue ? selectedName : 'Chọn danh mục',
                style: TextStyle(fontSize: 14, color: hasValue ? AppColors.slate800 : AppColors.slate400),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }

  // ── Action Buttons ──────────────────────────────
  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _closeWithAnimation,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.red500, width: 1),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close, size: 20, color: AppColors.red500),
                  SizedBox(width: 8),
                  Text(
                    'Hủy bỏ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.red500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _saveProduct,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.emerald500,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isEditMode ? Icons.save : Icons.add_circle,
                      size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _isEditMode ? 'Lưu thay đổi' : 'Thêm sản phẩm',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Image Picker Dialog ─────────────────────────
  void _showImagePickerDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
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
                    const Text('Chọn ảnh sản phẩm',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate800)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _doPickImage(ImageSource.camera);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              decoration: BoxDecoration(
                                color: AppColors.blue50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.blue200),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.camera_alt_rounded,
                                      color: Color(0xFF3B82F6), size: 40),
                                  SizedBox(height: 8),
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
                            onTap: () {
                              Navigator.pop(ctx);
                              _doPickImage(ImageSource.gallery);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              decoration: BoxDecoration(
                                color: AppColors.emerald50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.emerald200),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.photo_library_rounded,
                                      color: AppColors.emerald500, size: 40),
                                  SizedBox(height: 8),
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
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.slate500,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Hủy',
                            style:
                                TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doPickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
      );
      if (picked == null) return;

      // Read bytes for validation and crop dialog
      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      // Auto-resize & compress if needed (max 1024px, under 1MB)
      final prepared = await prepareImageBytes(bytes);

      // Show square crop dialog
      final result = await showSquareCropDialog(
        context,
        imageBytes: prepared,
        borderRadius: 16,
        title: 'Cắt ảnh sản phẩm',
      );

      if (result != null && mounted) {
        setState(() {
          _imageUrl = result;
        });
      }
    } catch (e) {
      if (mounted) {
        context
            .read<AppStore>()
            .showToast('Không thể chọn ảnh. Vui lòng thử lại.', 'error');
      }
    }
  }

  // ── Save Product ────────────────────────────────
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
    final costPriceText = _costPriceCtrl.text.replaceAll('.', '');
    final costPrice = double.tryParse(costPriceText) ?? 0;

    if (_isEditMode) {
      store.updateProduct(widget.existingProduct!.copyWith(
        name: name,
        price: price,
        image: _imageUrl,
        category: _selectedCategory,
        description: _descCtrl.text.trim(),
        isOutOfStock: _isOutOfStock,
        isHot: _isHot,
        quantity: int.tryParse(_qtyCtrl.text) ?? 0,
        costPrice: costPrice,
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
        quantity: int.tryParse(_qtyCtrl.text) ?? 0,
        costPrice: costPrice,
      ));
      store.showToast('Đã thêm sản phẩm "$name"!');
    }
    _closeWithAnimation();
  }

  // ── Toggle Row ──────────────────────────────────
  Widget _buildToggleRow({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String desc,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate800)),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.slate400)),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.emerald500,
            ),
          ),
        ],
      ),
    );
  }
}

