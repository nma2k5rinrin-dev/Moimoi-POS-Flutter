import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/core/state/ui_store.dart';
import 'package:moimoi_pos/core/state/order_filter_store.dart';
import 'package:moimoi_pos/features/pos_order/logic/cart_store_standalone.dart';
import 'package:moimoi_pos/features/inventory/logic/inventory_store_standalone.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';

import 'package:moimoi_pos/core/state/audio_store_standalone.dart';
import 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/utils/format.dart';
import 'package:moimoi_pos/core/utils/image_helper.dart';
import 'package:moimoi_pos/features/inventory/models/product_model.dart';
import 'package:moimoi_pos/features/pos_order/models/order_model.dart';

import 'package:moimoi_pos/features/inventory/models/category_model.dart';
import 'package:moimoi_pos/features/pos_order/presentation/widgets/payment_confirmation_dialog.dart';
import 'package:moimoi_pos/services/hardware/printer_service.dart';
import 'package:moimoi_pos/features/pos_order/presentation/widgets/mobile_cart_sheet.dart';

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
              Expanded(child: _ProductGrid()),
              SizedBox(
                width: 340,
                child: Container(
                  decoration: BoxDecoration(
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
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _scrollToTopSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTopSub = context.read<UIStore>().scrollToTopStream.listen((
        path,
      ) {
        if (path == '/' && mounted) {
          if (_scrollController.hasClients)
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
        }
      });
    });
    // Reset category to 'all' when entering POS tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ui = context.read<UIStore>();
      if (ui.selectedCategory != 'all') {
        ui.setCategory('all');
      }
    });
  }

  @override
  void dispose() {
    _scrollToTopSub?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<
      InventoryStore,
      ({
        List<ProductModel> products,
        List<CategoryModel> categories,
      })
    >(
      selector: (_, inv) => (
        products: inv.currentProducts,
        categories: inv.currentCategories,
      ),
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, invData, _) {
        final ui = context.watch<UIStore>();
        final selectedCategory = ui.selectedCategory;
        final searchQuery = ui.searchQuery;
        final allProducts = invData.products;
        final allCategories = invData.categories;

        // Sync controller text with store searchQuery (e.g. after category tap clears it)
        if (searchQuery.isEmpty && _searchController.text.isNotEmpty) {
          _searchController.clear();
        }

        var filteredProducts = allProducts.toList();
        if (selectedCategory != 'all') {
          filteredProducts = filteredProducts
              .where((p) => p.category == selectedCategory)
              .toList();
        }
        if (searchQuery.isNotEmpty) {
          filteredProducts = filteredProducts
              .where(
                (p) => p.name.toLowerCase().contains(searchQuery.toLowerCase()),
              )
              .toList();
        }

        // Sort by Best Seller (isHot) first, then alphabetically A-Z
        filteredProducts.sort((a, b) {
          if (a.isHot && !b.isHot) return -1;
          if (!a.isHot && b.isHot) return 1;
          return a.name.compareTo(b.name);
        });

        return Container(
          color: AppColors.scaffoldBg,
          child: Column(
            children: [
              // Body: Categories (Left) + Product Grid (Right)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Sidebar (Left)
                    Container(
                      width: 76,
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        border: Border(
                          right: BorderSide(
                            color: AppColors.slate200,
                            width: 1,
                          ),
                        ),
                      ),
                      child: ListView(
                        padding: EdgeInsets.only(bottom: 100),
                        children: [
                          _CategoryChip(
                            label: 'Tất cả',
                            isActive: selectedCategory == 'all',
                            count: allProducts.length,
                            onTap: () => ui.setCategory('all'),
                          ),
                          ...allCategories.map((cat) {
                            final count = allProducts
                                .where((p) => p.category == cat.id)
                                .length;
                            return _CategoryChip(
                              label: cat.name,
                              isActive: selectedCategory == cat.id,
                              count: count,
                              onTap: () => ui.setCategory(cat.id),
                            );
                          }),
                        ],
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
                                  controller: _scrollController,
                                  padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        childAspectRatio: childAspectRatio,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                      ),
                                  itemCount: filteredProducts.length,
                                  itemBuilder: (ctx, i) {
                                    return RepaintBoundary(
                                      child: _ProductCard(
                                        product: filteredProducts[i],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
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
            child: Icon(
              Icons.inventory_2_rounded,
              size: 36,
              color: AppColors.slate300,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Chưa có sản phẩm',
            style: TextStyle(
              color: AppColors.slate500,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Thêm sản phẩm trong Quản lý kho → Quản lý danh mục / sản phẩm',
            style: TextStyle(color: AppColors.slate400, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 20),
        decoration: BoxDecoration(
          color: isActive ? AppColors.emerald50 : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isActive ? AppColors.emerald500 : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? AppColors.emerald700 : AppColors.slate600,
              ),
            ),
          ],
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
    final cartStore = context.read<CartStore>();
    return Selector<CartStore, OrderItemModel?>(
      selector: (_, s) => s.cart.where((c) => c.id == product.id).firstOrNull,
      builder: (context, cartItem, _) {
        final isOutOfStock = product.isOutOfStock;
        final inCart = cartItem != null;

        return GestureDetector(
          onTap: isOutOfStock ? null : () => cartStore.addToCart(product),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: inCart
                        ? AppColors.emerald500
                        : (isOutOfStock
                              ? AppColors.slate200
                              : AppColors.slate100),
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
                        decoration: BoxDecoration(
                          color: AppColors.slate50,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: SmartImage(
                          imageData: product.image,
                          placeholder: _buildPlaceholder(),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(10, 8, 10, 2),
                      child: Text(
                        product.name,
                        style: TextStyle(
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
                      padding: EdgeInsets.fromLTRB(10, 0, 10, 6),
                      child: Text(
                        formatCurrency(product.price),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.emerald500,
                        ),
                      ),
                    ),
                    if (!isOutOfStock)
                      inCart ? _buildQtyRow(cartStore, cartItem) : _buildAddRow(),
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
                      child: Text(
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
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
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
                    child: Row(
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
  Widget _buildQtyRow(CartStore store, OrderItemModel cartItem) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 38,
        margin: EdgeInsets.fromLTRB(8, 0, 8, 8),
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
                  style: TextStyle(
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
                onTap: () => store.updateQuantity(product.id, 1),
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: AppColors.slate600,
                  ),
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
      margin: EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Center(
        child: Icon(Icons.add_rounded, size: 20, color: AppColors.slate400),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.inventory_2_rounded,
        color: AppColors.slate300.withValues(alpha: 0.6),
        size: 36,
      ),
    );
  }
}

// ─── Table Selector Button ────────────────────────────
class _TableSelectorBtn extends StatelessWidget {
  final CartStore cartStore;
  final OrderFilterStore orderFilter;
  final List<String> tables;
  const _TableSelectorBtn({required this.cartStore, required this.orderFilter, required this.tables});

  static String _areaOf(String raw) {
    final parts = raw.split(' · ');
    return parts.length > 1 ? parts[0] : '';
  }

  static String _nameOf(String raw) {
    // Strip ★ prefix for default tables
    final clean = raw.startsWith('★') ? raw.substring(1) : raw;
    final parts = clean.split(' · ');
    return parts.length > 1 ? parts.sublist(1).join(' · ') : clean;
  }

  static String _displayText(String raw) {
    final area = _areaOf(raw);
    final name = _nameOf(raw);
    if (area.isNotEmpty) return '$name · $area';
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final selected = context.select<CartStore, String>((s) => s.selectedTable);
    return InkWell(
      onTap: () => _showTablePicker(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 50,
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.slate200, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_restaurant_rounded,
              size: 18,
              color: AppColors.slate800,
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                selected.isEmpty
                    ? 'Chọn bàn'
                    : (selected.startsWith('★')
                          ? selected.substring(1)
                          : _displayText(selected)),
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
            SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.slate400,
            ),
          ],
        ),
      ),
    );
  }

  void _showTablePicker(BuildContext context) {
    // Separate default (★ prefix) tables from area-grouped tables
    final defaultTables = tables.where((t) => t.startsWith('★')).toList();
    final nonDefaultTables = tables.where((t) => !t.startsWith('★')).toList();

    final Map<String, List<String>> areaGroups = {};
    for (final t in nonDefaultTables) {
      final area = _areaOf(t);
      final groupName = area.isEmpty ? 'Mặc định' : area;
      areaGroups.putIfAbsent(groupName, () => []);
      areaGroups[groupName]!.add(t);
    }

    // Compute occupied tables (have pending or processing orders)
    final activeOrders = orderFilter.visibleOrders.where(
      (o) => o.status == 'pending' || o.status == 'processing',
    );
    final occupiedTables = <String>{};
    for (final o in activeOrders) {
      if (o.table.isNotEmpty && !o.table.startsWith('★')) {
        occupiedTables.add(o.table);
      }
    }

    // ── Dialog for table selection ──
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
              maxWidth: 400,
            ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Chọn bàn',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Default tables at top
                    ...defaultTables.map((raw) {
                      final displayName = raw.substring(1); // strip ★
                      return ListTile(
                        leading: Icon(
                          Icons.shopping_bag_outlined,
                          color: AppColors.orange500,
                        ),
                        title: Text(
                          displayName,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: cartStore.selectedTable == raw
                            ? Icon(
                                Icons.check_circle,
                                color: AppColors.emerald500,
                              )
                            : null,
                        onTap: () {
                          cartStore.setSelectedTable(raw);
                          Navigator.pop(context);
                        },
                      );
                    }),
                    ...areaGroups.entries.map((entry) {
                      final areaName = entry.key;
                      final areaTables = entry.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              areaName.toUpperCase(),
                              style: TextStyle(
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
                                color: isBusy
                                    ? AppColors.slate400
                                    : AppColors.emerald500,
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    tableName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isBusy
                                          ? AppColors.slate400
                                          : AppColors.slate800,
                                    ),
                                  ),
                                  if (isBusy) ...[
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.red50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Đang dùng',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.red500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: area.isNotEmpty
                                  ? Text(
                                      area,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.slate400,
                                      ),
                                    )
                                  : null,
                              trailing: cartStore.selectedTable == t
                                  ? Icon(
                                      Icons.check_circle,
                                      color: AppColors.emerald500,
                                    )
                                  : null,
                              onTap: isBusy
                                  ? () {
                                      // Need UIStore for toast — grab from closest context
                                      Navigator.pop(context);
                                    }
                                  : () {
                                      cartStore.setSelectedTable(t);
                                      Navigator.pop(context);
                                    },
                            );
                          }),
                        ],
                      );
                    }),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
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
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected
            ? AppColors.emerald50
            : (isBusy ? AppColors.slate50 : Colors.transparent),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isBusy
                          ? AppColors.slate400
                          : isSelected
                          ? AppColors.emerald600
                          : AppColors.slate700,
                    ),
                  ),
                  if (isBusy) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.red50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Đang dùng',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.red500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.emerald500,
              ),
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
    final store = context.read<CartStore>();
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
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
              child: SmartImage(
                imageData: item.image,
                width: 56,
                height: 56,
                placeholder: Icon(Icons.fastfood, color: AppColors.slate400),
              ),
            ),
          ),
          SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.slate800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  formatCurrency(item.price * item.quantity),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.emerald600,
                  ),
                ),
                if (item.note.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sticky_note_2_outlined,
                          size: 12,
                          color: AppColors.amber500,
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.note,
                            style: TextStyle(
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
          SizedBox(width: 8),
          // Qty controls
          _buildQtyControls(context.read<CartStore>()),
        ],
      ),
    );
  }

  Widget _buildQtyControls(CartStore store) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
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
              style: TextStyle(
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
  const _QtyBtn({required this.icon, required this.color, required this.onTap});

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
void _showPaymentConfirmation(BuildContext context) {
  final cart = context.read<CartStore>();
  final orderStore = context.read<OrderStore>();
  final audio = context.read<AudioStore>();
  final ui = context.read<UIStore>();

  showPaymentConfirmation(
    context,
    amount: cart.getCartTotal(),
    onPaid: (method) {
      // Save order data for printing before checkout clears it
      final orderForPrint = OrderModel(
        id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
        items: List.from(cart.cart),
        totalAmount: cart.getCartTotal(),
        table: cart.selectedTable,
        time: DateTime.now().toIso8601String(),
        status: 'paid',
      );
      orderStore.checkoutOrder(paymentStatus: 'paid', paymentMethod: method);
      audio.playPaymentSound();
      ui.showToast('Thanh toán thành công!');
      // Auto-print if printer connected
      _autoPrintReceipt(context, orderForPrint);
    },
    onUnpaid: () {
      final orderForPrint = OrderModel(
        id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
        items: List.from(cart.cart),
        totalAmount: cart.getCartTotal(),
        table: cart.selectedTable,
        time: DateTime.now().toIso8601String(),
        status: 'pending',
      );
      orderStore.checkoutOrder(paymentStatus: 'unpaid');
      ui.showToast('Đơn đã tạo, chưa thu tiền');
      _autoPrintReceipt(context, orderForPrint);

      // Auto navigate to Orders (Sales) tab
      context.go('/orders');
    },
  );
}

void _autoPrintReceipt(BuildContext context, OrderModel order) async {
  final printer = PrinterService();
  await printer.refreshConnection();
  if (printer.isConnected) {
    final storeInfo = context.read<ManagementStore>().currentStoreInfo;
    final ok = await printer.printReceipt(order, storeInfo);
    if (ok) {
      context.read<UIStore>().showToast('Đã in hóa đơn', 'success');
    }
  }
}

// ─── Cart Bottom Sheet (for mobile) ────────────────────
void showCartBottomSheet(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(24),
        child: Consumer<CartStore>(
          builder: (_, cartStore, _) {
            final cart = cartStore.cart;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
                maxWidth: 480,
              ),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 32,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_bag_rounded,
                            color: AppColors.emerald500,
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Giỏ hàng (${cart.length})',
                            style: TextStyle(
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
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: AppColors.slate500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Cart items
                Flexible(
                  child: cart.isEmpty
                      ? Padding(
                          padding: EdgeInsets.all(40),
                          child: Text(
                            'Giỏ hàng trống',
                            style: TextStyle(color: AppColors.slate400),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 0,
                          ),
                          itemCount: cart.length,
                          itemBuilder: (_, i) =>
                              _CartItemCard(item: cart[i], index: i),
                        ),
                ),

                if (cart.isNotEmpty) ...[
                  // Footer total
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.slate100),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tổng thanh toán',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: AppColors.slate500,
                          ),
                        ),
                        Text(
                          formatCurrency(cartStore.getCartTotal()),
                          style: TextStyle(
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
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      children: [
                        Builder(
                          builder: (ctx) {
                            final mgmt = ctx.watch<ManagementStore>();
                            final orderFilter = ctx.read<OrderFilterStore>();
                            return _TableSelectorBtn(
                              cartStore: cartStore,
                              orderFilter: orderFilter,
                              tables: mgmt.currentTables,
                            );
                          },
                        ),
                        SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showPaymentConfirmation(context);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF059669),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                height: 50,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
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
                  SizedBox(height: MediaQuery.of(ctx).padding.bottom),
                ],
              ],
            ),
          );
        },
      ),
      );
    },
  );
}
