import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../utils/constants.dart';
import '../../utils/format.dart';

class MenuManagementSection extends StatefulWidget {
  final VoidCallback? onBack;
  const MenuManagementSection({super.key, this.onBack});

  @override
  State<MenuManagementSection> createState() => _MenuManagementSectionState();
}

class _MenuManagementSectionState extends State<MenuManagementSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.slate50,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (widget.onBack != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: widget.onBack,
                      ),
                    const Expanded(
                      child: Text(
                        'Quản Lý Thực Đơn',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                    indicator: BoxDecoration(
                      color: AppColors.emerald500,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(4),
                    tabs: const [
                      Tab(text: '🍽️ Sản Phẩm'),
                      Tab(text: '🏷️ Danh Mục'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ProductsTab(
                  searchQuery: _searchQuery,
                  onSearchChanged: (q) => setState(() => _searchQuery = q),
                ),
                const _CategoriesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Products Tab ──────────────────────────────────
class _ProductsTab extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const _ProductsTab({
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final products = store.currentProducts;
    final categories = store.currentCategories;

    var filtered = products.toList();
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
              (p) => p.name.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }

    return Column(
      children: [
        // Search + Add
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Tìm sản phẩm...',
                    hintStyle: const TextStyle(color: AppColors.slate400),
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.slate400),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.slate200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.slate200),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () =>
                    _showProductDialog(context, store, categories, null),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Thêm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald500,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),

        // Product List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu,
                          size: 56, color: AppColors.slate300),
                      const SizedBox(height: 12),
                      const Text('Chưa có sản phẩm nào',
                          style: TextStyle(color: AppColors.slate400)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    final catName = categories
                        .where((c) => c.id == p.category)
                        .map((c) => c.name)
                        .firstOrNull;
                    return _ProductListTile(
                      product: p,
                      categoryName: catName,
                      onEdit: () => _showProductDialog(
                          context, store, categories, p),
                      onDelete: () {
                        store.showConfirm(
                          'Xóa sản phẩm "${p.name}"?',
                          () => store.deleteProduct(p.id),
                        );
                      },
                      onToggleStock: () {
                        store.updateProduct(
                            p.copyWith(isOutOfStock: !p.isOutOfStock));
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

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
              child:
                  const Text('Hủy', style: TextStyle(color: AppColors.slate500)),
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
}

class _ProductListTile extends StatelessWidget {
  final ProductModel product;
  final String? categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStock;

  const _ProductListTile({
    required this.product,
    required this.categoryName,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          // Image
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: product.image.isNotEmpty
                ? Image.network(product.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.restaurant,
                        color: AppColors.slate300))
                : const Icon(Icons.restaurant, color: AppColors.slate300),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (product.isOutOfStock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.red100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Hết hàng',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.red500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      formatCurrency(product.price),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.emerald500,
                        fontSize: 13,
                      ),
                    ),
                    if (categoryName != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.blue50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          categoryName!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.blue600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  product.isOutOfStock
                      ? Icons.check_circle_outline
                      : Icons.block,
                  color: product.isOutOfStock
                      ? AppColors.emerald500
                      : AppColors.amber500,
                  size: 20,
                ),
                tooltip:
                    product.isOutOfStock ? 'Còn hàng' : 'Đánh dấu hết hàng',
                onPressed: onToggleStock,
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.blue500, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.red400, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Categories Tab ────────────────────────────────
class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final categories = store.currentCategories;
    final products = store.currentProducts;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showCategoryDialog(context, store, null),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Thêm Danh Mục'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
        Expanded(
          child: categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category_outlined,
                          size: 56, color: AppColors.slate300),
                      const SizedBox(height: 12),
                      const Text('Chưa có danh mục nào',
                          style: TextStyle(color: AppColors.slate400)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  itemBuilder: (_, i) {
                    final cat = categories[i];
                    final count =
                        products.where((p) => p.category == cat.id).length;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.emerald50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.category,
                                color: AppColors.emerald500),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate800,
                                  ),
                                ),
                                Text(
                                  '$count sản phẩm',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.slate500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: AppColors.blue500, size: 20),
                            onPressed: () =>
                                _showCategoryDialog(context, store, cat),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.red400, size: 20),
                            onPressed: () {
                              store.showConfirm(
                                'Xóa danh mục "${cat.name}"?\nCác sản phẩm trong danh mục này sẽ không bị xóa.',
                                () => store.deleteCategory(cat.id),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

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

// ─── Shared Dialog Input ───────────────────────────
class _DialogInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;

  const _DialogInput({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.slate700)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.slate50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate200),
            ),
          ),
        ),
      ],
    );
  }
}
