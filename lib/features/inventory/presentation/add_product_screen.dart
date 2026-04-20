import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/features/inventory/logic/inventory_store_standalone.dart';
import 'package:moimoi_pos/features/inventory/models/product_model.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/utils/avatar_picker.dart';
import 'package:moimoi_pos/services/api/cloudflare_service.dart';
import 'package:moimoi_pos/core/widgets/crop/square_crop_dialog.dart';
import 'package:moimoi_pos/core/utils/image_helper.dart';

/// Formats number with thousand separators (e.g. 15000 → 15.000)
class _ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
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
      _priceCtrl.text = _ThousandSeparatorFormatter._formatNumber(
        p.price.toInt(),
      );
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
        _costPriceCtrl.text = _ThousandSeparatorFormatter._formatNumber(
          p.costPrice.toInt(),
        );
      }
      if (p.unit.isNotEmpty) {
        _unitCtrl.text = p.unit;
      }
    }

    _animCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: Offset(0, 0.15),
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
    final store = context.watch<InventoryStore>();
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
                  child: Container(color: Colors.black.withValues(alpha: 0.4)),
                ),
              ),
            ),

            // ── Panel ───────────────────────────
            Positioned(
              left: 0,
              right: 0,
              top: MediaQuery.of(context).padding.top + 40,
              bottom: MediaQuery.of(context).viewInsets.bottom,
              child: Center(
                child: SlideTransition(
                  position: _slideAnim,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: 480,
                      maxHeight:
                          MediaQuery.of(context).size.height * 0.85 -
                          MediaQuery.of(context).viewInsets.bottom,
                    ),
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 40,
                          offset: Offset(0, 12),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: Offset(0, 4),
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
                            padding: EdgeInsets.fromLTRB(24, 16, 24, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Image Upload Area ────
                                _buildImageSection(),
                                SizedBox(height: 18),

                                // ── Tên sản phẩm ────────
                                _buildLabel('Tên sản phẩm'),
                                SizedBox(height: 6),
                                _buildTextField(
                                  controller: _nameCtrl,
                                  hint: 'VD: Trà sữa trân châu...',
                                  icon: Icons.inventory_2_outlined,
                                ),
                                SizedBox(height: 18),

                                // ── Giá + Đơn vị ────────
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildLabel('Giá bán'),
                                          SizedBox(height: 6),
                                          _buildTextField(
                                            controller: _priceCtrl,
                                            hint: '0',
                                            icon:
                                                Icons.monetization_on_outlined,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              _ThousandSeparatorFormatter(),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildLabel('Đơn vị'),
                                          SizedBox(height: 6),
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
                                SizedBox(height: 14),

                                // ── Giá gốc ─────────────
                                _buildLabel('Giá gốc (tùy chọn)'),
                                SizedBox(height: 6),
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
                                SizedBox(height: 18),

                                // ── Danh mục ─────────────
                                _buildLabel('Danh mục'),
                                SizedBox(height: 6),
                                _buildCategoryDropdown(categories),
                                SizedBox(height: 18),

                                // ── Mô tả ────────────────
                                _buildLabel('Mô tả (tùy chọn)'),
                                SizedBox(height: 6),
                                _buildTextField(
                                  controller: _descCtrl,
                                  hint: 'Mô tả ngắn về sản phẩm',
                                  icon: Icons.description_outlined,
                                ),
                                SizedBox(height: 18),

                                // ── Số lượng ─────────────
                                _buildLabel('Số lượng tồn kho'),
                                SizedBox(height: 6),
                                _buildTextField(
                                  controller: _qtyCtrl,
                                  hint: '0 = không giới hạn',
                                  icon: Icons.inventory_2_outlined,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                                SizedBox(height: 18),

                                // ── Toggle Switches ──────
                                _buildToggleRow(
                                  icon: Icons.local_fire_department_rounded,
                                  iconColor: Color(0xFFF59E0B),
                                  bgColor: AppColors.orange50,
                                  label: 'Bán chạy',
                                  desc: 'Đánh dấu sản phẩm bán chạy',
                                  value: _isHot,
                                  onChanged: (v) => setState(() => _isHot = v),
                                ),
                                SizedBox(height: 10),
                                _buildToggleRow(
                                  icon: Icons.remove_shopping_cart_outlined,
                                  iconColor: AppColors.red500,
                                  bgColor: AppColors.red50,
                                  label: 'Hết hàng',
                                  desc: 'Tạm ngưng bán sản phẩm',
                                  value: _isOutOfStock,
                                  onChanged: (v) =>
                                      setState(() => _isOutOfStock = v),
                                ),
                                SizedBox(height: 18),

                                // ── Action Buttons ───────
                                // Moved down outside scroll view
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Padding(
                          padding: EdgeInsets.fromLTRB(24, 0, 24, 20),
                          child: _buildButtons(),
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
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary50, AppColors.cardBg],
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.add_shopping_cart_rounded,
            color: AppColors.primary600,
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              _isEditMode ? 'Sửa sản phẩm' : 'Thêm sản phẩm',
              style: TextStyle(
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
              child: Icon(Icons.close, size: 18, color: AppColors.slate500),
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
          SizedBox(height: 8),
          Text(
            _isEditMode ? 'Thay đổi ảnh sản phẩm' : 'Thêm ảnh sản phẩm',
            style: TextStyle(
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
    if (_imageUrl.isEmpty) return _buildImagePlaceholder();

    // URL (Cloudflare R2 or any HTTP URL)
    if (CloudflareService.isUrl(_imageUrl)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: CachedNetworkImage(
          imageUrl: _imageUrl,
          fit: BoxFit.cover,
          width: 120,
          height: 120,
          placeholder: (_, _) => _buildImagePlaceholder(),
          errorWidget: (_, _, _) => _buildImagePlaceholder(),
        ),
      );
    }
    return SmartImage(
      imageData: _imageUrl,
      width: 120,
      height: 120,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(15),
      errorWidget: _buildImagePlaceholder(),
      placeholder: _buildImagePlaceholder(),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 36,
          color: AppColors.slate400,
        ),
      ],
    );
  }

  // ── Label ───────────────────────────────────────
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
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
        hintStyle: TextStyle(color: AppColors.slate400, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.slate400, size: 18),
        filled: true,
        fillColor: AppColors.slate50,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary400),
        ),
      ),
    );
  }

  // ── Category Dropdown ───────────────────────────
  Widget _buildCategoryDropdown(List categories) {
    final catFieldKey = GlobalKey();
    final selectedName =
        categories
            .where((c) => c.id == _selectedCategory)
            .map((c) => c.name)
            .firstOrNull ??
        '';
    final hasValue = _selectedCategory.isNotEmpty && selectedName.isNotEmpty;

    return GestureDetector(
      key: catFieldKey,
      onTap: () {
        final renderBox =
            catFieldKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final position = renderBox.localToGlobal(Offset.zero);
        final fieldSize = renderBox.size;
        final screenHeight = MediaQuery.of(
          catFieldKey.currentContext!,
        ).size.height;

        final items = <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: '',
            height: 48,
            child: Text(
              'Không có',
              style: TextStyle(fontSize: 14, color: AppColors.slate500),
            ),
          ),
          ...categories.map(
            (c) => PopupMenuItem<String>(
              value: c.id,
              height: 48,
              child: Row(
                children: [
                  Icon(
                    Icons.sell_outlined,
                    size: 16,
                    color: c.id == _selectedCategory
                        ? AppColors.primary600
                        : AppColors.slate400,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: c.id == _selectedCategory
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: c.id == _selectedCategory
                            ? AppColors.primary600
                            : AppColors.slate800,
                      ),
                    ),
                  ),
                  if (c.id == _selectedCategory)
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppColors.primary600,
                    ),
                ],
              ),
            ),
          ),
        ];

        final totalMenuHeight = items.length * 48.0 + 16;
        final spaceBelow = screenHeight - position.dy - fieldSize.height;
        final dropUp =
            spaceBelow < totalMenuHeight && position.dy > totalMenuHeight;
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          children: [
            Icon(Icons.sell_outlined, color: AppColors.slate400, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                hasValue ? selectedName : 'Chọn danh mục',
                style: TextStyle(
                  fontSize: 14,
                  color: hasValue ? AppColors.slate800 : AppColors.slate400,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.slate400),
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
                color: AppColors.red50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.red500, width: 1),
              ),
              child: Row(
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
        SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _saveProduct,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary500,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isEditMode ? Icons.save : Icons.add_circle,
                    size: 20,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _isEditMode ? 'Lưu thay đổi' : 'Thêm sản phẩm',
                    style: TextStyle(
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
                child: Container(color: Colors.black.withValues(alpha: 0.3)),
              ),
            ),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 340),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 32),
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Chọn ảnh sản phẩm',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate800,
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx);
                                _doPickImage(ImageSource.camera);
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                decoration: BoxDecoration(
                                  color: AppColors.blue50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.blue200),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.camera_alt_rounded,
                                      color: Color(0xFF3B82F6),
                                      size: 40,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Máy ảnh',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx);
                                _doPickImage(ImageSource.gallery);
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                decoration: BoxDecoration(
                                  color: AppColors.primary50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.primary200,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.photo_library_rounded,
                                      color: AppColors.primary500,
                                      size: 40,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Thư viện',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: AppColors.primary500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.slate500,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Hủy',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
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
    );
  }

  Future<void> _doPickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      // Read bytes for validation and crop dialog
      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      // Auto-resize & compress if needed
      final prepared = await prepareImageBytes(bytes);

      if (!context.mounted) return;

      // Show square crop dialog (FB-style)
      final base64Result = await showSquareCropDialog(
        context,
        imageBytes: prepared,
        borderRadius: 16,
        title: 'Cắt ảnh sản phẩm',
      );

      if (base64Result == null || !mounted) return;

      // Try uploading to Cloudflare R2
      try {
        final url = await CloudflareService.uploadBase64(
          base64Data: base64Result,
          folder: 'products',
        );
        setState(() => _imageUrl = url);
      } catch (e) {
        // Fallback: store as base64 if R2 upload fails
        debugPrint('[AddProduct] R2 upload failed, using base64 fallback: $e');
        setState(() => _imageUrl = base64Result);
      }
    } catch (e) {
      if (mounted) {
        context.read<InventoryStore>().showToast(
          'Không thể chọn ảnh. Vui lòng thử lại.',
          'error',
        );
      }
    }
  }

  // ── Save Product ────────────────────────────────
  void _saveProduct() async {
    final store = context.read<InventoryStore>();
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
      store.updateProduct(
        widget.existingProduct!.copyWith(
          name: name,
          price: price,
          image: _imageUrl,
          category: _selectedCategory,
          description: _descCtrl.text.trim(),
          isOutOfStock: _isOutOfStock,
          isHot: _isHot,
          quantity: int.tryParse(_qtyCtrl.text) ?? 0,
          costPrice: costPrice,
          unit: _unitCtrl.text.trim(),
        ),
      );
      store.showToast('Đã cập nhật sản phẩm "$name"!');
    } else {
      final success = await store.addProduct(
        ProductModel(
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
          unit: _unitCtrl.text.trim(),
        ),
      );
      if (!success) return; // Bị chặn bởi Quota, ngưng đóng modal
      if (mounted) store.showToast('Đã thêm sản phẩm "$name"!');
    }
    if (mounted) _closeWithAnimation();
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
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
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
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(fontSize: 11, color: AppColors.slate400),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.primary500,
            ),
          ),
        ],
      ),
    );
  }
}
