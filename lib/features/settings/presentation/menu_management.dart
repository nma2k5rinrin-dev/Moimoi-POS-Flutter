import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/features/inventory/logic/inventory_store_standalone.dart';
import 'package:moimoi_pos/core/state/ui_store.dart';
import 'package:moimoi_pos/features/inventory/models/product_model.dart';
import 'package:moimoi_pos/features/inventory/models/category_model.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/utils/format.dart';
import 'package:moimoi_pos/features/inventory/presentation/add_category_screen.dart';
import 'package:moimoi_pos/features/inventory/presentation/add_product_screen.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:moimoi_pos/core/utils/image_helper.dart';

class MenuManagementSection extends StatefulWidget {
  const MenuManagementSection({super.key});

  @override
  State<MenuManagementSection> createState() => _MenuManagementSectionState();
}

class _MenuManagementSectionState extends State<MenuManagementSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ScrollController? __productsController;
  ScrollController get _productsController =>
      __productsController ??= ScrollController();

  ScrollController? __categoriesController;
  ScrollController get _categoriesController =>
      __categoriesController ??= ScrollController();
  StreamSubscription<String>? _scrollToTopSub;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTopSub = context.read<UIStore>().scrollToTopStream.listen((
        path,
      ) {
        if ((path == '/inventory' || path.contains('tab=management')) &&
            mounted) {
          final controller = _tabController.index == 1
              ? _productsController
              : _categoriesController;
          if (controller.hasClients) {
            controller.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } else {
            context.read<UIStore>().showToast(
              'Lỗi: Controller chưa gắn vào list!',
            );
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollToTopSub?.cancel();
    _productsController.dispose();
    _categoriesController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _closePanel() {}

  void _showPanelDialog(Widget panel) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      useRootNavigator: true,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, _, _) {
        return panel;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<InventoryStore>();
    final isProductsTab = _tabController.index == 1;

    final mainContent = Column(
      children: [
        // ── Content Area ────────────────────────────
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 9),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  SizedBox(height: 12),

                  // ── Panel 1: Pill Tab Bar ───────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppColors.slate500,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      indicator: BoxDecoration(
                        color: AppColors.emerald500,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      padding: EdgeInsets.all(4),
                      tabs: const [
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
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Sản Phẩm'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),

                  // ── Panel 2: Search Bar ────────────────────
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 20, color: AppColors.slate400),
                        SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (q) => setState(() => _searchQuery = q),
                            decoration: InputDecoration(
                              hintText: isProductsTab
                                  ? 'Tìm kiếm sản phẩm...'
                                  : 'Tìm kiếm danh mục...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: AppColors.slate400,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),

                  // ── List Content ──────────────────
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.slate200),
                          ),
                          child: _CategoriesTab(
                            scrollController: _categoriesController,
                            searchQuery: _searchQuery,
                            onEditCategory: (cat) {
                              _showPanelDialog(
                                AddCategoryPanel(
                                  existingCategory: cat,
                                  onClose: () {
                                    Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).pop();
                                    _closePanel();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        _ProductsTab(
                          isActive: isProductsTab,
                          scrollController: _productsController,
                          searchQuery: _searchQuery,
                          onEditProduct: (product) {
                            _showPanelDialog(
                              AddProductPanel(
                                existingProduct: product,
                                onClose: () {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop();
                                  _closePanel();
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),

                  // ── Bottom Add Button ──────────────────────
                  GestureDetector(
                    onTap: () {
                      if (isProductsTab) {
                        _showPanelDialog(
                          AddProductPanel(
                            onClose: () {
                              Navigator.of(context, rootNavigator: true).pop();
                              _closePanel();
                            },
                          ),
                        );
                      } else {
                        _showPanelDialog(
                          AddCategoryPanel(
                            onClose: () {
                              Navigator.of(context, rootNavigator: true).pop();
                              _closePanel();
                            },
                          ),
                        );
                      }
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
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
                          Icon(
                            isProductsTab
                                ? Icons.inventory_2_rounded
                                : Icons.sell_outlined,
                            size: 20,
                            color: AppColors.cardBg,
                          ),
                          SizedBox(width: 8),
                          Text(
                            isProductsTab
                                ? 'Thêm sản phẩm mới'
                                : 'Thêm danh mục mới',
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
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    return mainContent;
  }
}

// ─── Products Tab ──────────────────────────────────
class _ProductsTab extends StatefulWidget {
  final ScrollController scrollController;
  final String searchQuery;
  final void Function(ProductModel) onEditProduct;
  final bool isActive;
  const _ProductsTab({
    required this.scrollController,
    required this.searchQuery,
    required this.onEditProduct,
    required this.isActive,
  });

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  final Set<String> _collapsedCategories = {};
  bool _hasBeenActive = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isActive) {
      _hasBeenActive = true;
    }

    if (!_hasBeenActive) {
      return const SizedBox(); // Ngăn hiển thị và load resource khi chưa active
    }

    final store = context.watch<InventoryStore>();
    final products = store.currentProducts;
    final categories = store.currentCategories;

    var filtered = products.toList();
    if (widget.searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (p) =>
                p.name.toLowerCase().contains(widget.searchQuery.toLowerCase()),
          )
          .toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.inventory_2_rounded,
                size: 32,
                color: AppColors.slate300,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Chưa có sản phẩm nào',
              style: TextStyle(
                color: AppColors.slate400,
                fontWeight: FontWeight.w500,
              ),
            ),
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
      controller: widget.scrollController,
      padding: EdgeInsets.zero,
      children: sortedKeys.map((catId) {
        final items = categoryGroups[catId]!;
        final isCollapsed = _collapsedCategories.contains(catId);
        final catName = catId == '_uncategorized'
            ? 'Chưa phân loại'
            : categories
                      .where((c) => c.id == catId)
                      .map((c) => c.name)
                      .firstOrNull ??
                  'Danh mục không xác định';

        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Container(
            clipBehavior: Clip.antiAlias,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
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
                        catId == '_uncategorized'
                            ? Icons.label_off_outlined
                            : Icons.inventory_2_rounded,
                        size: 16,
                        color: catId == '_uncategorized'
                            ? AppColors.slate400
                            : AppColors.emerald600,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          catName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate800,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.emerald50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${items.length} sản phẩm',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.emerald600,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        isCollapsed
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        size: 18,
                        color: AppColors.slate400,
                      ),
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
                        context.read<UIStore>().showConfirm(
                          'Xóa sản phẩm "${p.name}"?',
                          () => store.deleteProduct(p.id),
                          title: 'Xóa sản phẩm?',
                          description:
                              'Bạn có chắc muốn xóa sản phẩm này? Hành động này không thể hoàn tác.',
                          icon: Icons.delete_forever_rounded,
                          itemName: p.name,
                          itemSubtitle: catDisplayName ?? 'Không có danh mục',
                          avatarInitials: initials,
                          avatarColor: AppColors.emerald500,
                        );
                      },
                      onToggleStock: () {
                        store.updateProduct(
                          p.copyWith(isOutOfStock: !p.isOutOfStock),
                        );
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
    required this.product,
    required this.categoryName,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStock,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 10),
      child: Slidable(
        key: ValueKey(product.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.45,
          children: [
            SlidableAction(
              onPressed: (context) => onEdit(),
              backgroundColor: AppColors.blue500,
              foregroundColor: Colors.white,
              icon: Icons.edit_rounded,
              label: 'Sửa',
            ),
            SlidableAction(
              onPressed: (context) => onDelete(),
              backgroundColor: AppColors.red500,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline_rounded,
              label: 'Xóa',
              borderRadius: BorderRadius.horizontal(right: Radius.circular(14)),
            ),
          ],
        ),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: SmartImage(
                  imageData: product.image,
                  width: 44,
                  height: 44,
                  placeholder: Icon(
                    Icons.inventory_2_rounded,
                    size: 22,
                    color: AppColors.slate300,
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (product.isHot)
                          Container(
                            margin: EdgeInsets.only(left: 6),
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.orange50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Bán chạy',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        if (product.isOutOfStock)
                          Container(
                            margin: EdgeInsets.only(left: 6),
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.red100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
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
                    SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          formatCurrency(product.price),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.emerald500,
                            fontSize: 12,
                          ),
                        ),
                        if (categoryName != null) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.blue50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              categoryName!,
                              style: TextStyle(
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
              Icon(Icons.chevron_left_rounded, color: AppColors.slate400),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Categories Tab ────────────────────────────────
class _CategoriesTab extends StatelessWidget {
  final ScrollController scrollController;
  final String searchQuery;
  final void Function(CategoryModel) onEditCategory;
  const _CategoriesTab({
    required this.scrollController,
    required this.searchQuery,
    required this.onEditCategory,
  });

  static final _catColors = [
    (AppColors.emerald50, AppColors.emerald500, PhosphorIconsDuotone.coffee),
    (AppColors.blue50, const Color(0xFF3B82F6), PhosphorIconsDuotone.forkKnife),
    (AppColors.amber50, const Color(0xFFF59E0B), PhosphorIconsDuotone.cake),
    (
      AppColors.orange50,
      const Color(0xFFF97316),
      PhosphorIconsDuotone.bowlSteam,
    ),
    (AppColors.red50, const Color(0xFFEF4444), PhosphorIconsDuotone.pizza),
    (
      AppColors.violet50,
      const Color(0xFF8B5CF6),
      PhosphorIconsDuotone.iceCream,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<InventoryStore>();
    final categories = store.currentCategories;
    final products = store.currentProducts;

    var filtered = categories.toList();
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (c) => c.name.toLowerCase().contains(searchQuery.toLowerCase()),
          )
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

    if (searchQuery.isNotEmpty &&
        allCategories.length == 1 &&
        !defaultCategory.name.toLowerCase().contains(
          searchQuery.toLowerCase(),
        )) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.category_outlined,
                size: 32,
                color: AppColors.slate300,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Không tìm thấy danh mục',
              style: TextStyle(
                color: AppColors.slate400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.all(16),
      itemCount: allCategories.length,
      itemBuilder: (_, i) {
        final cat = allCategories[i];
        final isDefault = cat.id == '_uncategorized';
        final count = isDefault
            ? uncategorizedCount
            : products.where((p) => p.category == cat.id).length;
        final colorSet = isDefault
            ? (
                AppColors.slate100,
                AppColors.slate500,
                PhosphorIconsDuotone.question,
              )
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
          iconWidget = Center(
            child: Text(cat.emoji, style: TextStyle(fontSize: 22)),
          );
        } else {
          iconWidget = PhosphorIcon(colorSet.$3, color: catColor, size: 22);
        }

        return Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Slidable(
            key: ValueKey(cat.id),
            endActionPane: isDefault
                ? null
                : ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.45,
                    children: [
                      SlidableAction(
                        onPressed: (context) => onEditCategory(cat),
                        backgroundColor: AppColors.blue500,
                        foregroundColor: Colors.white,
                        icon: Icons.edit_rounded,
                        label: 'Sửa',
                      ),
                      SlidableAction(
                        onPressed: (context) {
                          final catInitials = cat.name.length >= 2
                              ? cat.name.substring(0, 2).toUpperCase()
                              : cat.name[0].toUpperCase();
                          context.read<UIStore>().showConfirm(
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
                        },
                        backgroundColor: AppColors.red500,
                        foregroundColor: Colors.white,
                        icon: Icons.delete_outline_rounded,
                        label: 'Xóa',
                        borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(14),
                        ),
                      ),
                    ],
                  ),
            child: Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: catBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: iconWidget,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate800,
                          ),
                        ),
                        Text(
                          '$count sản phẩm',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_left_rounded, color: AppColors.slate400),
                ],
              ),
            ),
          ),
        );
      },
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
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }
}
