import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store/app_store.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../models/order_model.dart';
import 'payment_confirmation_dialog.dart';

/// Mobile cart bottom sheet matching Pencil design
class MobileCartSheet extends StatelessWidget {
  final bool embedded;
  const MobileCartSheet({super.key, this.embedded = false});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (_) => Stack(
        children: [
          // Blurred backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  color: const Color(0x66000000),
                ),
              ),
            ),
          ),
          // Cart sheet centered on screen with rounded corners
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const MobileCartSheet(),
            ),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cart = store.cart;
    final maxHeight = embedded ? double.infinity : MediaQuery.of(context).size.height * 0.7;

    return ClipRRect(
      borderRadius: BorderRadius.circular(embedded ? 0 : 24),
      child: Container(
        constraints: embedded ? null : BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(embedded ? 0 : 24)),
          boxShadow: embedded ? [] : const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 32,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
        mainAxisSize: embedded ? MainAxisSize.max : MainAxisSize.min,
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
                if (!embedded)
                InkWell(
                  onTap: () => Navigator.pop(context),
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

          // Cart Items
          Expanded(
            child: cart.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_bag_outlined,
                            size: 56, color: AppColors.slate300),
                        const SizedBox(height: 8),
                        const Text(
                          'Giỏ hàng trống',
                          style: TextStyle(
                            color: AppColors.slate400,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Chọn sản phẩm để thêm vào giỏ',
                          style: TextStyle(
                              color: AppColors.slate400, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: !embedded,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: cart.length,
                    itemBuilder: (_, i) =>
                        _CartItem(item: cart[i], index: i),
                  ),
          ),

          // Footer
          if (cart.isNotEmpty)
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    top: BorderSide(color: AppColors.slate100, width: 1)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Total row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                        children: [
                          // Table selector
                          _TableSelectorBtn(store: store),
                          const SizedBox(height: 10),

                          // Pay button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                _showPaymentConfirmation(context, store, embedded: embedded);
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
                                      Color(0xFF059669),
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
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }
}

// ─── Cart Item (matching Pencil design) ────────────────
class _CartItem extends StatefulWidget {
  final OrderItemModel item;
  final int index;
  const _CartItem({required this.item, required this.index});

  @override
  State<_CartItem> createState() => _CartItemState();
}

class _CartItemState extends State<_CartItem> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.item.note);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  OrderItemModel get item => widget.item;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 56,
              height: 56,
              color: AppColors.slate100,
              child: item.image != null && item.image!.isNotEmpty
                  ? (item.image!.startsWith('data:')
                      ? Image.memory(
                          base64Decode(item.image!.split(',').last),
                          fit: BoxFit.cover,
                          cacheWidth: 112, cacheHeight: 112,
                          errorBuilder: (_, __, ___) => const Icon(
                                Icons.restaurant_rounded,
                                color: AppColors.slate300,
                                size: 24,
                              ))
                      : Image.network(item.image!, fit: BoxFit.cover,
                          cacheWidth: 112, cacheHeight: 112,
                          errorBuilder: (_, __, ___) => const Icon(
                                Icons.restaurant_rounded,
                                color: AppColors.slate300,
                                size: 24,
                              )))
                  : const Icon(Icons.restaurant_rounded,
                      color: AppColors.slate300, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          // Info column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.slate800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatCurrency(item.price),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.emerald500,
                  ),
                ),
                const SizedBox(height: 6),
                // Note input
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: TextField(
                    controller: _noteController,
                    onChanged: (v) => store.addNote(item.id, v),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.slate600),
                    decoration: InputDecoration(
                      hintText: 'Ghi chú (Ví dụ: ít đường)...',
                      hintStyle: TextStyle(
                        color: AppColors.slate400.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Qty row
                _buildQtyRow(store),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Delete button only
          InkWell(
            onTap: () => store.removeFromCart(item.id),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 16, color: AppColors.red400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyRow(AppStore store) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minus button (left rounded)
        GestureDetector(
          onTap: () {
            if (item.quantity <= 1) {
              store.removeFromCart(item.id);
            } else {
              store.updateQuantity(item.id, -1);
            }
          },
          child: Container(
            width: 30,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              item.quantity <= 1
                  ? Icons.delete_outline_rounded
                  : Icons.remove_rounded,
              size: 14,
              color: item.quantity <= 1
                  ? AppColors.red400
                  : AppColors.slate600,
            ),
          ),
        ),
        // Number center
        Container(
          width: 30,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.slate50,
            border: Border.symmetric(
              vertical: BorderSide(color: AppColors.slate200, width: 1),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '${item.quantity}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.slate800,
            ),
          ),
        ),
        // Plus button (right rounded)
        GestureDetector(
          onTap: () => store.updateQuantity(item.id, 1),
          child: Container(
            width: 30,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.add_rounded,
                size: 14, color: AppColors.emerald600),
          ),
        ),
      ],
    );
  }
}

// ─── Table Selector Button ────────────────────────────
class _TableSelectorBtn extends StatefulWidget {
  final AppStore store;
  const _TableSelectorBtn({required this.store});

  @override
  State<_TableSelectorBtn> createState() => _TableSelectorBtnState();
}

class _TableSelectorBtnState extends State<_TableSelectorBtn> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final buttonSize = renderBox.size;
    final tables = widget.store.currentTables;

    // Separate default (★ prefix) tables from area-grouped tables
    const defaultPrefix = '★';
    final defaultTables = tables.where((t) => t.startsWith(defaultPrefix)).toList();
    final nonDefaultTables = tables.where((t) => !t.startsWith(defaultPrefix)).toList();

    // Group non-default tables by area
    final Map<String, List<String>> areaGroups = {};
    for (final t in nonDefaultTables) {
      final parts = t.split('::');
      final area = parts.length > 1 ? parts[0] : 'Mặc định';
      areaGroups.putIfAbsent(area, () => []);
      areaGroups[area]!.add(t);
    }

    // Compute occupied tables
    final activeOrders = widget.store.visibleOrders.where(
      (o) => o.status == 'pending' || o.status == 'cooking',
    );
    final occupiedTables = <String>{};
    for (final o in activeOrders) {
      if (o.table.isNotEmpty && !o.table.startsWith('★')) occupiedTables.add(o.table);
    }

    // Total items for height calculation
    final itemCount = tables.length + defaultTables.length + areaGroups.length;
    final dropdownHeight = (itemCount * 42.0 + 18).clamp(0.0, 350.0);

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Tap-away barrier
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeDropdown,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Dropdown positioned above button
          Positioned(
            width: buttonSize.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, -dropdownHeight),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 350),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.slate200),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Default tables at top (full width, like old "Mang về")
                        ...defaultTables.map((raw) {
                          final displayName = raw.substring(1); // strip ★
                          return _buildDropItem(
                            displayName,
                            Icons.shopping_bag_rounded,
                            isSelected: widget.store.selectedTable == raw,
                            isBusy: false,
                            rawValue: raw,
                          );
                        }),
                        if (defaultTables.isNotEmpty && areaGroups.isNotEmpty)
                          const SizedBox(height: 8),
                        // Grouped tables in 2-column grid
                        ...areaGroups.entries.expand((entry) {
                          final areaName = entry.key;
                          final areaTables = entry.value;
                          return [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 12, color: AppColors.emerald600),
                                  const SizedBox(width: 4),
                                  Text(areaName,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slate500)),
                                  const SizedBox(width: 4),
                                  Text('${areaTables.length} bàn',
                                      style: const TextStyle(fontSize: 10, color: AppColors.slate400)),
                                ],
                              ),
                            ),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                const crossAxisCount = 2;
                                const spacing = 6.0;
                                final itemWidth = (constraints.maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
                                return Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  children: areaTables.map((t) {
                                    final parts = t.split('::');
                                    final tableName = parts.length > 1 ? parts.sublist(1).join('::') : t;
                                    final isBusy = occupiedTables.contains(t);
                                    final isSelected = widget.store.selectedTable == t;
                                    return SizedBox(
                                      width: itemWidth,
                                      child: _buildGridItem(tableName, isSelected: isSelected, isBusy: isBusy, rawValue: t),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                          ];
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

    overlay.insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
    if (mounted) setState(() {});
  }

  Widget _buildDropItem(String label, IconData icon,
      {required bool isSelected, bool isBusy = false, String? rawValue}) {
    return InkWell(
      onTap: () {
        if (isBusy) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bàn đang có đơn xử lý'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        widget.store.setSelectedTable(rawValue ?? label);
        _closeDropdown();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.emerald50
              : (isBusy ? AppColors.slate50 : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: isBusy
                    ? AppColors.slate400
                    : isSelected
                        ? AppColors.emerald600
                        : AppColors.slate400),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isBusy
                          ? AppColors.slate400
                          : isSelected
                              ? AppColors.emerald600
                              : AppColors.slate800,
                    ),
                  ),
                  if (isBusy) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.red50,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('Đang dùng',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.red500)),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  size: 20, color: AppColors.emerald500),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItem(String label, {required bool isSelected, bool isBusy = false, String? rawValue}) {
    return GestureDetector(
      onTap: () {
        if (isBusy) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bàn đang có đơn xử lý'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        widget.store.setSelectedTable(rawValue ?? label);
        _closeDropdown();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.emerald50 : (isBusy ? AppColors.slate100 : AppColors.slate50),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: AppColors.emerald200, width: 1.5) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: (isSelected ? AppColors.emerald500 : AppColors.slate400).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.table_restaurant_outlined,
                  size: 16,
                  color: isBusy ? AppColors.slate400 : isSelected ? AppColors.emerald500 : AppColors.slate400),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isBusy ? AppColors.slate400 : isSelected ? AppColors.emerald600 : AppColors.slate800,
                      )),
                  const SizedBox(height: 2),
                  if (isBusy)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.red50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Đang dùng',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.red500)),
                    )
                  else if (isSelected)
                    const Text('Đã chọn',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.emerald500))
                  else
                    const Text('Trống',
                        style: TextStyle(fontSize: 10, color: AppColors.slate400)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, size: 14, color: AppColors.emerald500),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.store.selectedTable;
    final hasSelection = selected.isNotEmpty;

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: _toggleDropdown,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: hasSelection ? AppColors.emerald50 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  hasSelection ? AppColors.emerald500 : AppColors.slate200,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.table_restaurant_rounded,
                  size: 18,
                  color: hasSelection
                      ? AppColors.emerald600
                      : AppColors.slate800),
              const SizedBox(width: 8),
              Text(
                hasSelection
                    ? (selected.startsWith('★')
                        ? selected.substring(1)
                        : selected.contains('::')
                            ? '${selected.split('::').sublist(1).join('::')} · ${selected.split('::')[0]}'
                            : selected)
                    : 'Chọn bàn',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      hasSelection ? FontWeight.w700 : FontWeight.w600,
                  color: hasSelection
                      ? AppColors.emerald600
                      : AppColors.slate800,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                hasSelection
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: hasSelection
                    ? AppColors.emerald500
                    : AppColors.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─── Payment Confirmation Dialog ──────────────────────
void _showPaymentConfirmation(BuildContext context, AppStore store, {bool embedded = false}) {
  showPaymentConfirmation(
    context,
    amount: store.getCartTotal(),
    onPaid: (method) {
      if (!embedded) Navigator.pop(context); // close cart sheet (only if bottom sheet)
      store.checkoutOrder(paymentStatus: 'paid', paymentMethod: method);
      store.showToast('Thanh toán thành công!');
    },
    onUnpaid: () {
      if (!embedded) Navigator.pop(context); // close cart sheet (only if bottom sheet)
      store.checkoutOrder(paymentStatus: 'unpaid');
      store.showToast('Đơn đã tạo, chưa thu tiền');
    },
  );
}
