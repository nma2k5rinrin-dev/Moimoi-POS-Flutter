import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../utils/constants.dart';
import '../../utils/format.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';

class OrderPage extends StatelessWidget {
  const OrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    return Row(
      children: [
        const Expanded(child: _ProductGrid()),
        if (isWide)
          const SizedBox(
            width: 380,
            child: _CartPanel(),
          ),
      ],
    );
  }
}

// ─── Product Grid ──────────────────────────────────────
class _ProductGrid extends StatelessWidget {
  const _ProductGrid();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final allProducts = store.currentProducts;
    final allCategories = store.currentCategories;
    final selectedCategory = store.selectedCategory;
    final searchQuery = store.searchQuery;

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
          // Search + count
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.slate200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (v) => store.setSearchQuery(v),
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm món...',
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
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.restaurant_menu_rounded,
                          size: 18, color: AppColors.emerald500),
                      const SizedBox(width: 6),
                      Text(
                        '${filteredProducts.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.slate700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Category Chips
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
          const SizedBox(height: 14),

          // Product Grid
          Expanded(
            child: filteredProducts.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      childAspectRatio: 0.72,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (ctx, i) {
                      return _ProductCard(product: filteredProducts[i]);
                    },
                  ),
          ),
        ],
      ),
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
            'Thêm món ăn trong Cài đặt → Quản lý thực đơn',
            style: TextStyle(color: AppColors.slate400, fontSize: 13),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? AppColors.emerald500 : Colors.white,
              borderRadius: BorderRadius.circular(12),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppColors.slate600,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.25)
                          : AppColors.slate100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color:
                            isActive ? Colors.white : AppColors.slate500,
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

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final isOutOfStock = product.isOutOfStock;

    return GestureDetector(
      onTap: isOutOfStock ? null : () => store.addToCart(product),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isOutOfStock ? AppColors.slate200 : AppColors.slate100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.emerald50.withValues(alpha: 0.5),
                          AppColors.slate50,
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18)),
                    ),
                    child: product.image.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(18)),
                            child: Image.network(
                              product.image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildPlaceholder(),
                            ),
                          )
                        : _buildPlaceholder(),
                  ),
                ),
                // Info
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate800,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatCurrency(product.price),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.emerald600,
                              ),
                            ),
                            if (!isOutOfStock)
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.emerald50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add_rounded,
                                    size: 18, color: AppColors.emerald600),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Out of stock overlay
            if (isOutOfStock)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.red50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.red200),
                    ),
                    child: const Text(
                      'Hết hàng',
                      style: TextStyle(
                        color: AppColors.red500,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            // Hot badge
            if (product.isHot && !isOutOfStock)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      Text('🔥 ',
                          style: TextStyle(fontSize: 10)),
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

// ─── Cart Panel ───────────────────────────────────────
class _CartPanel extends StatelessWidget {
  const _CartPanel();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cart = store.cart;
    final tables = store.currentTables;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            const Border(left: BorderSide(color: AppColors.slate100, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.emerald50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: AppColors.emerald600, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đơn hàng',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.slate800,
                          ),
                        ),
                        if (cart.isNotEmpty)
                          Text(
                            '${store.cartItemCount} món',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.slate500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (cart.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => store.clearCart(),
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: AppColors.red400),
                    label: const Text(
                      'Xoá',
                      style: TextStyle(
                        color: AppColors.red400,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            color: AppColors.slate100,
          ),

          // Table Selection
          Container(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              initialValue: store.selectedTable.isNotEmpty &&
                      tables.contains(store.selectedTable)
                  ? store.selectedTable
                  : null,
              hint: const Row(
                children: [
                  Icon(Icons.table_restaurant_outlined,
                      size: 18, color: AppColors.slate400),
                  SizedBox(width: 8),
                  Text(
                    'Chọn bàn hoặc mang về...',
                    style: TextStyle(
                      color: AppColors.slate400,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              items: [
                const DropdownMenuItem(
                  value: 'Mang về',
                  child: Row(
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          size: 18, color: AppColors.orange500),
                      SizedBox(width: 8),
                      Text('Mang về'),
                    ],
                  ),
                ),
                ...tables.map((t) => DropdownMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          const Icon(Icons.table_restaurant_outlined,
                              size: 18, color: AppColors.emerald500),
                          const SizedBox(width: 8),
                          Text(t),
                        ],
                      ),
                    )),
              ],
              onChanged: (v) {
                if (v != null) store.setSelectedTable(v);
              },
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true,
                fillColor: AppColors.slate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.slate200),
                ),
              ),
            ),
          ),

          // Cart Items
          Expanded(
            child: cart.isEmpty
                ? _buildEmptyCart()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: cart.length,
                    itemBuilder: (ctx, i) {
                      return _CartItemCard(item: cart[i], index: i);
                    },
                  ),
          ),

          // Footer (Total + Checkout)
          if (cart.isNotEmpty) _buildCheckoutFooter(store),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 32, color: AppColors.slate300),
          ),
          const SizedBox(height: 14),
          const Text(
            'Chưa có món nào',
            style: TextStyle(
              color: AppColors.slate500,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Chạm vào món ăn để thêm vào đơn',
            style: TextStyle(
              color: AppColors.slate400,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutFooter(AppStore store) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            const Border(top: BorderSide(color: AppColors.slate100, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng cộng',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppColors.slate500,
                ),
              ),
              Text(
                formatCurrency(store.getCartTotal()),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  color: AppColors.emerald600,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      store.checkoutOrder(paymentStatus: 'unpaid');
                      store.showToast('Đơn đã tạo, chưa thu tiền');
                    },
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: const Text('Ghi nợ'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.amber600,
                      side: const BorderSide(
                          color: AppColors.amber200, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      store.checkoutOrder(paymentStatus: 'paid');
                      store.showToast('Thanh toán thành công!');
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 18),
                    label: const Text('Thanh toán'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final OrderItemModel item;
  final int index;
  const _CartItemCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Index badge
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.slate200,
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: AppColors.slate600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.slate800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatCurrency(item.price * item.quantity),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.emerald600,
                  ),
                ),
              ],
            ),
          ),
          // Quantity control
          Container(
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
                  color: item.quantity <= 1
                      ? AppColors.red400
                      : AppColors.slate600,
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
