import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../utils/constants.dart';
import '../../utils/format.dart';
import 'add_category_screen.dart';
import 'add_product_screen.dart';

class MenuManagementSection extends StatefulWidget {
  const MenuManagementSection({super.key});

  @override
  State<MenuManagementSection> createState() => _MenuManagementSectionState();
}

class _MenuManagementSectionState extends State<MenuManagementSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String? _subScreen; // 'addCategory' | 'addProduct' | null
  ProductModel? _editingProduct;
  CategoryModel? _editingCategory;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _closePanel() {
    setState(() {
      _subScreen = null;
      _editingCategory = null;
      _editingProduct = null;
    });
  }

  void _showPanelDialog(Widget panel) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      useRootNavigator: true,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, _, __) {
        return panel;
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    final store = context.watch<AppStore>();
    final categories = store.currentCategories;
    final isProductsTab = _tabController.index == 0;


    final mainContent = Column(
      children: [

          // ── Content Area ────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                children: [
                  const SizedBox(height: 12),

                  // ── Panel 1: Pill Tab Bar ───────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppColors.slate500,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                      unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      indicator: BoxDecoration(
                        color: AppColors.emerald500,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      padding: const EdgeInsets.all(4),
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.restaurant_menu_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Sản Phẩm'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.sell_outlined, size: 18),
                              SizedBox(width: 6),
                              Text('Danh Mục'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Panel 2: Search Bar ────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 20, color: AppColors.slate400),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (q) => setState(() => _searchQuery = q),
                            decoration: InputDecoration(
                              hintText: isProductsTab
                                  ? 'Tìm kiếm sản phẩm...'
                                  : 'Tìm kiếm danh mục...',
                              hintStyle: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.slate400),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── List Content ──────────────────
                  Expanded(
                    child: TabBarView(
                        controller: _tabController,
                        children: [
                          _ProductsTab(
                            searchQuery: _searchQuery,
                            onEditProduct: (product) {
                              setState(() {
                                _editingProduct = product;
                                _subScreen = 'addProduct';
                              });
                              _showPanelDialog(AddProductPanel(
                                existingProduct: product,
                                onClose: () {
                                  Navigator.of(context, rootNavigator: true).pop();
                                  _closePanel();
                                },
                              ));
                            },
                          ),
                          Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.slate200),
                            ),
                            child: _CategoriesTab(
                              searchQuery: _searchQuery,
                              onEditCategory: (cat) {
                                setState(() {
                                  _editingCategory = cat;
                                  _subScreen = 'addCategory';
                                });
                                _showPanelDialog(AddCategoryPanel(
                                  existingCategory: cat,
                                  onClose: () {
                                    Navigator.of(context, rootNavigator: true).pop();
                                    _closePanel();
                                  },
                                ));
                              },
                            ),
                          ),
                        ],
                      ),
                  ),
                  const SizedBox(height: 12),

                  // ── Bottom Add Button ──────────────────────
                  GestureDetector(
                    onTap: () {
                      if (isProductsTab) {
                        setState(() => _subScreen = 'addProduct');
                        _showPanelDialog(AddProductPanel(
                          onClose: () {
                            Navigator.of(context, rootNavigator: true).pop();
                            _closePanel();
                          },
                        ));
                      } else {
                        setState(() => _subScreen = 'addCategory');
                        _showPanelDialog(AddCategoryPanel(
                          onClose: () {
                            Navigator.of(context, rootNavigator: true).pop();
                            _closePanel();
                          },
                        ));
                      }
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.emerald500, AppColors.emerald600],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emerald500.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isProductsTab ? Icons.restaurant_menu : Icons.sell_outlined, size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(isProductsTab
                              ? 'Thêm sản phẩm mới'
                              : 'Thêm danh mục mới',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
              ),
            ),
          ),
        ],
    );

    return mainContent;
  }

  // ── Product Dialog ───────────────────────────────
  void _showProductDialog(BuildContext context, AppStore store,
      List<CategoryModel> categories, ProductModel? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl =
        TextEditingController(text: existing?.price.toStringAsFixed(0) ?? '');
    final imageCtrl = TextEditingController(text: existing?.image ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String selectedCat = existing?.category ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            existing != null ? 'Sửa Sản Phẩm' : 'Thêm Sản Phẩm Mới',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogInput(controller: nameCtrl, label: 'Tên sản phẩm *'),
                const SizedBox(height: 10),
                _DialogInput(
                  controller: priceCtrl,
                  label: 'Giá (VNĐ) *',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                const Text('Danh mục',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate700)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: DropdownButton<String>(
                    value: selectedCat.isNotEmpty ? selectedCat : null,
                    hint: const Text('Chọn danh mục',
                        style: TextStyle(fontSize: 14)),
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('Không có')),
                      ...categories.map((c) => DropdownMenuItem(
                          value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => selectedCat = v ?? ''),
                  ),
                ),
                const SizedBox(height: 10),
                _DialogInput(
                    controller: imageCtrl,
                    label: 'URL hình ảnh (tùy chọn)'),
                const SizedBox(height: 10),
                _DialogInput(
                    controller: descCtrl,
                    label: 'Mô tả (tùy chọn)',
                    maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy',
                  style: TextStyle(color: AppColors.slate500)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) {
                  store.showToast('Tên sản phẩm không được trống', 'error');
                  return;
                }
                final price =
                    double.tryParse(priceCtrl.text.replaceAll(',', '')) ?? 0;
                if (price <= 0) {
                  store.showToast('Giá phải lớn hơn 0', 'error');
                  return;
                }
                if (existing != null) {
                  store.updateProduct(existing.copyWith(
                    name: nameCtrl.text.trim(),
                    price: price,
                    image: imageCtrl.text.trim(),
                    category: selectedCat,
                    description: descCtrl.text.trim(),
                  ));
                  store.showToast('Đã cập nhật sản phẩm!');
                } else {
                  store.addProduct(ProductModel(
                    id: '',
                    name: nameCtrl.text.trim(),
                    price: price,
                    image: imageCtrl.text.trim(),
                    category: selectedCat,
                    description: descCtrl.text.trim(),
                  ));
                  store.showToast('Đã thêm sản phẩm!');
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(existing != null ? 'Cập nhật' : 'Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category Dialog ──────────────────────────────
  void _showCategoryDialog(
      BuildContext context, AppStore store, CategoryModel? existing) {
    final controller = TextEditingController(text: existing?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          existing != null ? 'Sửa Danh Mục' : 'Thêm Danh Mục',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'VD: Đồ uống, Cơm, Phở...',
            filled: true,
            fillColor: AppColors.slate50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate200),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                store.showToast('Tên danh mục không được trống', 'error');
                return;
              }
              if (existing != null) {
                store.updateCategory(CategoryModel(
                  id: existing.id,
                  name: name,
                  storeId: existing.storeId,
                ));
                store.showToast('Đã cập nhật danh mục!');
              } else {
                store.addCategory(name);
                store.showToast('Đã thêm danh mục!');
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(existing != null ? 'Cập nhật' : 'Thêm'),
          ),
        ],
      ),
    );
  }
}

// ─── Products Tab ──────────────────────────────────
class _ProductsTab extends StatefulWidget {
  final String searchQuery;
  final void Function(ProductModel) onEditProduct;
  const _ProductsTab({required this.searchQuery, required this.onEditProduct});

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  final Set<String> _collapsedCategories = {};

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final products = store.currentProducts;
    final categories = store.currentCategories;

    var filtered = products.toList();
    if (widget.searchQuery.isNotEmpty) {
      filtered = filtered
          .where((p) => p.name.toLowerCase().contains(widget.searchQuery.toLowerCase()))
          .toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.restaurant_menu,
                  size: 32, color: AppColors.slate300),
            ),
            const SizedBox(height: 12),
            const Text('Chưa có sản phẩm nào',
                style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    // Group products by category
    final Map<String, List<ProductModel>> categoryGroups = {};
    for (final p in filtered) {
      final catId = p.category.isNotEmpty ? p.category : '_uncategorized';
      categoryGroups.putIfAbsent(catId, () => []);
      categoryGroups[catId]!.add(p);
    }

    // Sort: real categories first, uncategorized last
    final sortedKeys = categoryGroups.keys.toList()
      ..sort((a, b) {
        if (a == '_uncategorized') return 1;
        if (b == '_uncategorized') return -1;
        return a.compareTo(b);
      });

    return ListView(
      padding: EdgeInsets.zero,
      children: sortedKeys.map((catId) {
        final items = categoryGroups[catId]!;
        final isCollapsed = _collapsedCategories.contains(catId);
        final catName = catId == '_uncategorized'
            ? 'Chưa phân loại'
            : categories.where((c) => c.id == catId).map((c) => c.name).firstOrNull ?? 'Danh mục không xác định';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category Header
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    isCollapsed
                        ? _collapsedCategories.remove(catId)
                        : _collapsedCategories.add(catId);
                  }),
                  child: Row(
                    children: [
                      Icon(
                        catId == '_uncategorized' ? Icons.label_off_outlined : Icons.restaurant_menu,
                        size: 16,
                        color: catId == '_uncategorized' ? AppColors.slate400 : AppColors.emerald600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(catName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emerald50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${items.length} sản phẩm',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.emerald600)),
                      ),
                      const SizedBox(width: 8),
                      Icon(isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                          size: 18, color: AppColors.slate400),
                    ],
                  ),
                ),
                // Product Cards (collapsible)
                if (!isCollapsed)
                  ...items.map((p) {
                    final catDisplayName = categories
                        .where((c) => c.id == p.category)
                        .map((c) => c.name)
                        .firstOrNull;
                    return _ProductListTile(
                      product: p,
                      categoryName: catDisplayName,
                      onEdit: () => widget.onEditProduct(p),
                      onDelete: () {
                        final initials = p.name.length >= 2
                            ? p.name.substring(0, 2).toUpperCase()
                            : p.name[0].toUpperCase();
                        store.showConfirm(
                          'Xóa sản phẩm "${p.name}"?',
                          () => store.deleteProduct(p.id),
                          title: 'Xóa sản phẩm?',
                          description: 'Bạn có chắc muốn xóa sản phẩm này? Hành động này không thể hoàn tác.',
                          icon: Icons.delete_forever_rounded,
                          itemName: p.name,
                          itemSubtitle: catDisplayName ?? 'Không có danh mục',
                          avatarInitials: initials,
                          avatarColor: AppColors.emerald500,
                        );
                      },
                      onToggleStock: () {
                        store.updateProduct(p.copyWith(isOutOfStock: !p.isOutOfStock));
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}


// ─── Product List Tile ─────────────────────────────
class _ProductListTile extends StatelessWidget {
  final ProductModel product;
  final String? categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStock;

  const _ProductListTile({
    required this.product, required this.categoryName,
    required this.onEdit, required this.onDelete, required this.onToggleStock,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(14)),
          child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: product.image.isNotEmpty
                  ? (product.image.startsWith('data:')
                      ? Image.memory(
                          base64Decode(product.image.split(',').last),
                          fit: BoxFit.cover,
                          cacheWidth: 120, cacheHeight: 120,
                          errorBuilder: (_, __, ___) => const Icon(Icons.restaurant,
                              size: 22, color: AppColors.slate300))
                      : Image.network(product.image, fit: BoxFit.cover,
                          cacheWidth: 120, cacheHeight: 120,
                          errorBuilder: (_, __, ___) => const Icon(Icons.restaurant,
                              size: 22, color: AppColors.slate300)))
                  : const Icon(Icons.restaurant, size: 22, color: AppColors.slate300),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(product.name,
                        style: const TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w700, color: AppColors.slate800),
                        overflow: TextOverflow.ellipsis)),
                    if (product.isHot)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(6)),
                        child: const Text('Bán chạy', style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
                      ),
                    if (product.isOutOfStock)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.red100, borderRadius: BorderRadius.circular(6)),
                        child: const Text('Hết hàng', style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w700, color: AppColors.red500)),
                      ),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(formatCurrency(product.price),
                        style: const TextStyle(fontWeight: FontWeight.w700,
                            color: AppColors.emerald500, fontSize: 12)),
                    if (categoryName != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.blue50, borderRadius: BorderRadius.circular(6)),
                        child: Text(categoryName!, style: const TextStyle(fontSize: 10,
                            color: AppColors.blue600, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            _ActionButton(icon: Icons.delete_outline,
                bgColor: const Color(0xFFFEF2F2), iconColor: AppColors.red500,
                tooltip: 'Xóa', onTap: onDelete),
          ],
          ),
        ),
      ),
    );
  }
}

// ─── Categories Tab ────────────────────────────────
class _CategoriesTab extends StatelessWidget {
  final String searchQuery;
  final void Function(CategoryModel) onEditCategory;
  const _CategoriesTab({required this.searchQuery, required this.onEditCategory});

  static final _catColors = [
    (AppColors.emerald50, AppColors.emerald500, PhosphorIconsDuotone.coffee),
    (AppColors.blue50, const Color(0xFF3B82F6), PhosphorIconsDuotone.forkKnife),
    (const Color(0xFFFFF7ED), const Color(0xFFF59E0B), PhosphorIconsDuotone.cake),
    (const Color(0xFFFFF7ED), const Color(0xFFF97316), PhosphorIconsDuotone.bowlSteam),
    (const Color(0xFFFEF2F2), const Color(0xFFEF4444), PhosphorIconsDuotone.pizza),
    (const Color(0xFFF5F3FF), const Color(0xFF8B5CF6), PhosphorIconsDuotone.iceCream),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final categories = store.currentCategories;
    final products = store.currentProducts;

    var filtered = categories.toList();
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where((c) => c.name.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }

    // Add default "Chưa phân loại" category
    final uncategorizedCount = products.where((p) => p.category.isEmpty).length;
    final defaultCategory = CategoryModel(
      id: '_uncategorized',
      name: 'Chưa phân loại',
      storeId: '',
    );

    // Build full list: default + filtered
    final allCategories = [defaultCategory, ...filtered];

    if (searchQuery.isNotEmpty && allCategories.length == 1 && !defaultCategory.name.toLowerCase().contains(searchQuery.toLowerCase())) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.category_outlined,
                  size: 32, color: AppColors.slate300),
            ),
            const SizedBox(height: 12),
            const Text('Không tìm thấy danh mục',
                style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allCategories.length,
      itemBuilder: (_, i) {
        final cat = allCategories[i];
        final isDefault = cat.id == '_uncategorized';
        final count = isDefault
            ? uncategorizedCount
            : products.where((p) => p.category == cat.id).length;
        final colorSet = isDefault
            ? (AppColors.slate100, AppColors.slate500, PhosphorIconsDuotone.question)
            : _catColors[(i - 1) % _catColors.length];

        // Parse saved color from category, or fall back to colorSet
        Color catColor = colorSet.$2;
        Color catBg = colorSet.$1;
        if (!isDefault && cat.color.isNotEmpty) {
          try {
            final hex = cat.color.replaceFirst('#', '');
            catColor = Color(int.parse('FF$hex', radix: 16));
            catBg = catColor.withValues(alpha: 0.1);
          } catch (_) {}
        }

        // Determine icon widget: emoji from DB or fallback PhosphorIcon
        Widget iconWidget;
        if (!isDefault && cat.emoji.isNotEmpty) {
          iconWidget = Center(child: Text(cat.emoji, style: const TextStyle(fontSize: 22)));
        } else {
          iconWidget = PhosphorIcon(colorSet.$3, color: catColor, size: 22);
        }

        return GestureDetector(
          onTap: () => onEditCategory(cat),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: catBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: iconWidget,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat.name, style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w700, color: AppColors.slate800)),
                      Text('$count sản phẩm', style: const TextStyle(
                          fontSize: 12, color: AppColors.slate500)),
                    ],
                  ),
                ),
                if (!isDefault)
                  _ActionButton(icon: Icons.delete_outline,
                      bgColor: const Color(0xFFFEF2F2), iconColor: AppColors.red500,
                      tooltip: 'Xóa', onTap: () {
                        final catInitials = cat.name.length >= 2
                            ? cat.name.substring(0, 2).toUpperCase()
                            : cat.name[0].toUpperCase();
                        store.showConfirm(
                          'Xóa danh mục "${cat.name}"?',
                          () => store.deleteCategory(cat.id),
                          title: 'Xóa danh mục?',
                          description:
                              'Bạn có chắc muốn xóa danh mục này? Các sản phẩm trong danh mục này sẽ không bị xóa.',
                          icon: Icons.category_rounded,
                          itemName: cat.name,
                          itemSubtitle: 'Danh mục sản phẩm',
                          avatarInitials: catInitials,
                          avatarColor: const Color(0xFFF59E0B),
                        );
                      }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCategoryDialog(
      BuildContext context, AppStore store, CategoryModel? existing) {
    final controller = TextEditingController(text: existing?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(existing != null ? 'Sửa Danh Mục' : 'Thêm Danh Mục',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller, autofocus: true,
          decoration: InputDecoration(
            hintText: 'VD: Đồ uống, Cơm, Phở...',
            filled: true, fillColor: AppColors.slate50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate200)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                store.showToast('Tên danh mục không được trống', 'error');
                return;
              }
              if (existing != null) {
                store.updateCategory(CategoryModel(
                    id: existing.id, name: name, storeId: existing.storeId));
                store.showToast('Đã cập nhật danh mục!');
              } else {
                store.addCategory(name);
                store.showToast('Đã thêm danh mục!');
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald500, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(existing != null ? 'Cập nhật' : 'Thêm'),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon, required this.bgColor, required this.iconColor,
    required this.tooltip, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }
}

class _DialogInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;

  const _DialogInput({
    required this.controller, required this.label,
    this.keyboardType, this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13,
            fontWeight: FontWeight.w600, color: AppColors.slate700)),
        const SizedBox(height: 4),
        TextField(
          controller: controller, keyboardType: keyboardType, maxLines: maxLines,
          decoration: InputDecoration(
            filled: true, fillColor: AppColors.slate50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate200)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate200)),
          ),
        ),
      ],
    );
  }
}
