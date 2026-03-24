import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../utils/constants.dart';
import '../../utils/format.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../models/store_info_model.dart';
import '../../models/category_model.dart';
import '../../widgets/payment_confirmation_dialog.dart';
import '../../services/printer_service.dart';
import '../../widgets/mobile_cart_sheet.dart';

class OrderPage extends StatelessWidget {
  const OrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSideCart = constraints.maxWidth >= 600;
        if (showSideCart) {
          return Row(
            children: [
              const Expanded(child: _ProductGrid()),
              SizedBox(
                width: 340,
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: AppColors.slate100, width: 1),
                    ),
                  ),
                  child: const MobileCartSheet(embedded: true),
                ),
              ),
            ],
          );
        }
        return const _ProductGrid();
      },
    );
  }
}

// ─── Product Grid ──────────────────────────────────────
class _ProductGrid extends StatefulWidget {
  const _ProductGrid();

  @override
  State<_ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<_ProductGrid> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppStore, ({List<ProductModel> products, List<CategoryModel> categories, String selectedCategory, String searchQuery, StoreInfoModel storeInfo, String? userRole})>(
      selector: (_, s) => (
        products: s.currentProducts,
        categories: s.currentCategories,
        selectedCategory: s.selectedCategory,
        searchQuery: s.searchQuery,
        storeInfo: s.currentStoreInfo,
        userRole: s.currentUser?.role,
      ),
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, data, _) {
    final store = context.read<AppStore>();
    final storeInfo = data.storeInfo;
    final allProducts = data.products;
    final allCategories = data.categories;
    final selectedCategory = data.selectedCategory;
    final searchQuery = data.searchQuery;

    // Sync controller text with store searchQuery (e.g. after category tap clears it)
    if (searchQuery.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    var filteredProducts = allProducts.toList();
    if (selectedCategory != 'all') {
      filteredProducts =
          filteredProducts.where((p) => p.category == selectedCategory).toList();
    }
    if (searchQuery.isNotEmpty) {
      filteredProducts = filteredProducts
          .where((p) =>
              p.name.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }

    return Container(
      color: const Color(0xFFFAFBFC),
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.slate200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => store.setSearchQuery(v),
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm sản phẩm...',
                  hintStyle: TextStyle(
                    color: AppColors.slate400.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 10),
                    child: Icon(Icons.search_rounded,
                        color: AppColors.slate400, size: 22),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0),
                  suffixIcon: searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            store.setSearchQuery('');
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: Icon(Icons.close_rounded,
                                color: AppColors.slate400, size: 20),
                          ),
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(minWidth: 0),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),


          // Category Chips
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                children: [
                  _CategoryChip(
                    label: 'Tất cả',
                    isActive: selectedCategory == 'all',
                    count: allProducts.length,
                    onTap: () => store.setCategory('all'),
                  ),
                  ...allCategories.map((cat) {
                    final count = allProducts
                        .where((p) => p.category == cat.id)
                        .length;
                    return _CategoryChip(
                      label: cat.name,
                      isActive: selectedCategory == cat.id,
                      count: count,
                      onTap: () => store.setCategory(cat.id),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Product Grid
          Expanded(
            child: filteredProducts.isEmpty
                ? _buildEmptyState()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      int crossAxisCount;
                      double childAspectRatio;
                      if (width >= 1024) {
                        crossAxisCount = 5;
                        childAspectRatio = 0.7;
                      } else if (width >= 600) {
                        crossAxisCount = 3;
                        childAspectRatio = 0.7;
                      } else {
                        crossAxisCount = 2;
                        childAspectRatio = 0.7;
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (ctx, i) {
                          return RepaintBoundary(
                            child: _ProductCard(product: filteredProducts[i]),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.restaurant_menu_rounded,
                size: 36, color: AppColors.slate300),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có sản phẩm',
            style: TextStyle(
              color: AppColors.slate500,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Thêm sản phẩm trong Quản lý kho → Quản lý danh mục / sản phẩm',
            style: TextStyle(color: AppColors.slate400, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showStoreSelector(BuildContext context, AppStore store) {
    final adminUsers = store.users.where((u) => u.role == 'admin').toList();
    final renderBox = context.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          // Blur backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          // Dropdown panel below the selector
          Positioned(
            top: offset.dy + 60,
            left: 20,
            right: MediaQuery.of(context).size.width > 768
                ? MediaQuery.of(context).size.width - 380 + 20
                : 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 320),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text('Chọn cửa hàng',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate800)),
                        ),
                        _storeOption(
                          ctx, store,
                          icon: Icons.home_rounded,
                          label: 'Tất cả cửa hàng',
                          isSelected: store.sadminViewStoreId == 'all',
                          onTap: () {
                            store.setSadminViewStoreId('all');
                            Navigator.pop(ctx);
                          },
                        ),
                        ...adminUsers.map((admin) {
                          final storeName =
                              store.storeInfos[admin.username]?.name ??
                                  admin.fullname;
                          return _storeOption(
                            ctx, store,
                            icon: Icons.store,
                            label: storeName,
                            isSelected:
                                store.sadminViewStoreId == admin.username,
                            onTap: () {
                              store.setSadminViewStoreId(admin.username);
                              Navigator.pop(ctx);
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _storeOption(BuildContext ctx, AppStore store,
      {required IconData icon,
      required String label,
      required bool isSelected,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? AppColors.emerald50 : Colors.transparent,
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.emerald500),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.emerald600
                        : AppColors.slate700,
                  )),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  size: 20, color: AppColors.emerald500),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final int count;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isActive,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? AppColors.emerald500 : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive ? AppColors.emerald500 : AppColors.slate200,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.emerald500.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppColors.slate800,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : AppColors.slate200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            isActive ? const Color(0xFF2EC4B6) : AppColors.slate500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Product Card with inline qty ─────────────────────
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Selector<AppStore, OrderItemModel?>(
      selector: (_, s) => s.cart.where((c) => c.id == product.id).firstOrNull,
      builder: (context, cartItem, _) {
    final isOutOfStock = product.isOutOfStock;
    final inCart = cartItem != null;

    return GestureDetector(
      onTap: isOutOfStock ? null : () => store.addToCart(product),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: inCart
                    ? AppColors.emerald500
                    : (isOutOfStock ? AppColors.slate200 : AppColors.slate100),
                width: inCart ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: product.image.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: product.image.startsWith('data:')
                                ? Image.memory(
                                    base64Decode(product.image.split(',').last),
                                    fit: BoxFit.cover,
                                    cacheWidth: 300,
                                    cacheHeight: 300,
                                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                                  )
                                : Image.network(
                                    product.image,
                                    fit: BoxFit.cover,
                                    cacheWidth: 300,
                                    cacheHeight: 300,
                                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                                  ),
                          )
                        : _buildPlaceholder(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate800,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                  child: Text(
                    formatCurrency(product.price),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.emerald500,
                    ),
                  ),
                ),
                if (!isOutOfStock)
                  inCart ? _buildQtyRow(store, cartItem) : _buildAddRow(),
              ],
            ),
          ),
          if (isOutOfStock)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Transform.rotate(
                  angle: -0.45,
                  child: const Text(
                    'HẾT HÀNG',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (product.isHot && !isOutOfStock)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEF4444)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange500.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🔥 ', style: TextStyle(fontSize: 10)),
                    Text(
                      'Bán chạy',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
      },
    );
  }

  /// Full-width qty stepper: [ − | count | + ]
  Widget _buildQtyRow(AppStore store, OrderItemModel cartItem) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 38,
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  if (cartItem.quantity <= 1) {
                    store.removeFromCart(cartItem.id);
                  } else {
                    store.updateQuantity(cartItem.id, -1);
                  }
                },
                child: Center(
                  child: Icon(
                    cartItem.quantity <= 1
                        ? Icons.delete_outline_rounded
                        : Icons.remove_rounded,
                    size: 18,
                    color: cartItem.quantity <= 1
                        ? AppColors.red400
                        : AppColors.slate600,
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 20, color: AppColors.slate200),
            Expanded(
              child: Center(
                child: Text(
                  '${cartItem.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.slate800,
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 20, color: AppColors.slate200),
            Expanded(
              child: InkWell(
                onTap: () => store.addToCart(product),
                child: const Center(
                  child: Icon(Icons.add_rounded,
                      size: 18, color: AppColors.slate600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Full-width "+" row when not in cart
  Widget _buildAddRow() {
    return Container(
      height: 38,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.slate200),
      ),
      child: const Center(
        child: Icon(Icons.add_rounded, size: 20, color: AppColors.slate400),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.restaurant_rounded,
        color: AppColors.slate300.withValues(alpha: 0.6),
        size: 36,
      ),
    );
  }
}


// ─── Table Selector Button ────────────────────────────
class _TableSelectorBtn extends StatelessWidget {
  final AppStore store;
  final List<String> tables;
  const _TableSelectorBtn({required this.store, required this.tables});

  static String _areaOf(String raw) {
    final parts = raw.split('::');
    return parts.length > 1 ? parts[0] : '';
  }

  static String _nameOf(String raw) {
    final parts = raw.split('::');
    return parts.length > 1 ? parts.sublist(1).join('::') : raw;
  }

  static String _displayText(String raw) {
    final area = _areaOf(raw);
    final name = _nameOf(raw);
    if (area.isNotEmpty) return '$name · $area';
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final selected = context.select<AppStore, String>((s) => s.selectedTable);
    return InkWell(
      onTap: () => _showTablePicker(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.slate200, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.table_restaurant_rounded,
                size: 18, color: AppColors.slate800),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                selected.isEmpty
                    ? 'Chọn bàn'
                    : (selected == 'Mang về' ? selected : _displayText(selected)),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected.isEmpty
                      ? AppColors.slate800
                      : AppColors.emerald600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }

  void _showTablePicker(BuildContext context) {
    final Map<String, List<String>> areaGroups = {};
    for (final t in tables) {
      final area = _areaOf(t);
      final groupName = area.isEmpty ? 'Mặc định' : area;
      areaGroups.putIfAbsent(groupName, () => []);
      areaGroups[groupName]!.add(t);
    }

    // Compute occupied tables (have pending or cooking orders)
    final activeOrders = store.visibleOrders.where(
      (o) => o.status == 'pending' || o.status == 'cooking',
    );
    final occupiedTables = <String>{};
    for (final o in activeOrders) {
      if (o.table.isNotEmpty) occupiedTables.add(o.table);
    }

      // ── Bottom sheet for mobile ──
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        builder: (_) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Chọn bàn',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.shopping_bag_outlined,
                            color: AppColors.orange500),
                        title: const Text('Mang về',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        trailing: store.selectedTable == 'Mang về'
                            ? const Icon(Icons.check_circle,
                                color: AppColors.emerald500)
                            : null,
                        onTap: () {
                          store.setSelectedTable('Mang về');
                          Navigator.pop(context);
                        },
                      ),
                      ...areaGroups.entries.map((entry) {
                        final areaName = entry.key;
                        final areaTables = entry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                areaName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate400,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            ...areaTables.map((t) {
                              final tableName = _nameOf(t);
                              final area = _areaOf(t);
                              final isBusy = occupiedTables.contains(t);
                              return ListTile(
                                leading: Icon(
                                    Icons.table_restaurant_outlined,
                                    color: isBusy ? AppColors.slate400 : AppColors.emerald500),
                                title: Row(
                                  children: [
                                    Text(tableName,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: isBusy ? AppColors.slate400 : AppColors.slate800)),
                                    if (isBusy) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.red50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('Đang dùng',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.red500)),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: area.isNotEmpty
                                    ? Text(area,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.slate400))
                                    : null,
                                trailing: store.selectedTable == t
                                    ? const Icon(Icons.check_circle,
                                        color: AppColors.emerald500)
                                    : null,
                                onTap: isBusy
                                    ? () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Bàn đang có đơn xử lý'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    : () {
                                        store.setSelectedTable(t);
                                        Navigator.pop(context);
                                      },
                              );
                            }),
                          ],
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
  }


  static Widget _tableOption(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isBusy = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? AppColors.emerald50 : (isBusy ? AppColors.slate50 : Colors.transparent),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isBusy
                            ? AppColors.slate400
                            : isSelected
                                ? AppColors.emerald600
                                : AppColors.slate700,
                      )),
                  if (isBusy) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.red50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Đang dùng',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.red500)),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: AppColors.emerald500),
          ],
        ),
      ),
    );
  }

}


// ─── Cart Item Card (used by mobile cart sheet) ──────
class _CartItemCard extends StatelessWidget {
  final OrderItemModel item;
  final int index;
  const _CartItemCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 56,
              height: 56,
              color: AppColors.slate100,
              child: (item.image != null && item.image!.isNotEmpty)
                  ? (item.image!.startsWith('data:')
                      ? Image.memory(
                          base64Decode(item.image!.split(',').last),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.fastfood, color: AppColors.slate400),
                        )
                      : Image.network(
                          item.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.fastfood, color: AppColors.slate400),
                        ))
                  : const Icon(Icons.fastfood, color: AppColors.slate400),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.slate800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(item.price * item.quantity),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.emerald600,
                  ),
                ),
                if (item.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.sticky_note_2_outlined,
                            size: 12, color: AppColors.amber500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.note,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.slate500,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Qty controls
          _buildQtyControls(store),
        ],
      ),
    );
  }

  Widget _buildQtyControls(AppStore store) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyBtn(
            icon: item.quantity <= 1
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            color: item.quantity <= 1 ? AppColors.red500 : AppColors.slate600,
            onTap: () {
              if (item.quantity <= 1) {
                store.removeFromCart(item.id);
              } else {
                store.updateQuantity(item.id, -1);
              }
            },
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 30),
            alignment: Alignment.center,
            child: Text(
              '${item.quantity}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.slate800,
              ),
            ),
          ),
          _QtyBtn(
            icon: Icons.add_rounded,
            color: AppColors.emerald600,
            onTap: () => store.updateQuantity(item.id, 1),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QtyBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ─── Payment Confirmation Dialog ──────────────────────
void _showPaymentConfirmation(BuildContext context, AppStore store) {
  showPaymentConfirmation(
    context,
    amount: store.getCartTotal(),
    onPaid: (method) {
      // Save order data for printing before checkout clears it
      final orderForPrint = OrderModel(
        id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
        items: List.from(store.cart),
        totalAmount: store.getCartTotal(),
        table: store.selectedTable,
        time: DateTime.now().toIso8601String(),
        status: 'paid',
      );
      store.checkoutOrder(paymentStatus: 'paid', paymentMethod: method);
      store.showToast('Thanh toán thành công!');
      // Auto-print if printer connected
      _autoPrintReceipt(store, orderForPrint);
    },
    onUnpaid: () {
      final orderForPrint = OrderModel(
        id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
        items: List.from(store.cart),
        totalAmount: store.getCartTotal(),
        table: store.selectedTable,
        time: DateTime.now().toIso8601String(),
        status: 'pending',
      );
      store.checkoutOrder(paymentStatus: 'unpaid');
      store.showToast('Đơn đã tạo, chưa thu tiền');
      _autoPrintReceipt(store, orderForPrint);
    },
  );
}

void _autoPrintReceipt(AppStore store, OrderModel order) async {
  final printer = PrinterService();
  await printer.refreshConnection();
  if (printer.isConnected) {
    final storeInfo = store.currentStoreInfo;
    final ok = await printer.printReceipt(order, storeInfo);
    if (ok) {
      store.showToast('Đã in hóa đơn', 'success');
    }
  }
}

// ─── Cart Bottom Sheet (for mobile) ────────────────────
void showCartBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Consumer<AppStore>(
        builder: (_, store, __) {
          final cart = store.cart;
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 32,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_bag_rounded,
                              color: AppColors.emerald500, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            'Giỏ hàng (${cart.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: AppColors.slate800,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.slate100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.close,
                              size: 18, color: AppColors.slate500),
                        ),
                      ),
                    ],
                  ),
                ),

                // Cart items
                Flexible(
                  child: cart.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Text('Giỏ hàng trống',
                              style: TextStyle(color: AppColors.slate400)),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 0),
                          itemCount: cart.length,
                          itemBuilder: (_, i) =>
                              _CartItemCard(item: cart[i], index: i),
                        ),
                ),

                if (cart.isNotEmpty) ...[
                  // Footer total
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: AppColors.slate100)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tổng thanh toán',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: AppColors.slate500,
                          ),
                        ),
                        Text(
                          formatCurrency(store.getCartTotal()),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 26,
                            color: AppColors.emerald500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      children: [
                        _TableSelectorBtn(
                          store: store,
                          tables: store.currentTables,
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showPaymentConfirmation(context, store);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF059669)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                height: 50,
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded,
                                        size: 18, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Thanh toán thôi',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Colors.white,
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
                  SizedBox(
                      height: MediaQuery.of(ctx).padding.bottom),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}
