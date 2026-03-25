import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../store/app_store.dart';
import '../utils/constants.dart';
import '../widgets/notification_bell.dart';
import '../widgets/store_selector.dart';
import '../widgets/mobile_cart_sheet.dart';
import '../widgets/account_dialog.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Sadmin: SaaS admin tabs
  static const List<_NavItem> _sadminMenuItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Tổng quan', path: '/admin'),
    _NavItem(icon: PhosphorIconsBold.storefront, label: 'Cửa hàng', path: '/'),
    _NavItem(icon: Icons.verified_rounded, label: 'Phê duyệt', path: '/orders'),
    _NavItem(icon: Icons.settings_rounded, label: 'Cài đặt', path: '/settings'),
  ];

  // Admin: no settings, no admin dashboard
  static const List<_NavItem> _adminMenuItems = [
    _NavItem(icon: Icons.bar_chart, label: 'Báo Cáo', path: '/dashboard'),
    _NavItem(icon: PhosphorIconsBold.storefront, label: 'Bán hàng', path: '/'),
    _NavItem(icon: PhosphorIconsBold.clipboardText, label: 'Đơn hàng', path: '/orders'),
    _NavItem(icon: PhosphorIconsBold.package, label: 'Quản lý kho', path: '/inventory'),
  ];

  // Staff tabs: Order + Orders only
  static const List<_NavItem> _staffMenuItems = [
    _NavItem(icon: PhosphorIconsBold.storefront, label: 'Bán hàng', path: '/'),
    _NavItem(icon: PhosphorIconsBold.clipboardText, label: 'Đơn hàng', path: '/orders'),
  ];

  List<_NavItem> _getMenuItems(AppStore store) {
    final role = store.currentUser?.role;
    if (role == 'sadmin') return _sadminMenuItems;
    if (role == 'admin') return _adminMenuItems;
    return _staffMenuItems;
  }

  void _onTabTapped(int index, List<_NavItem> items) {
    context.go(items[index].path);
  }

  int _getCurrentIndex(List<_NavItem> items) {
    var location = GoRouterState.of(context).matchedLocation;
    // Settings sub-routes → map to /settings for sadmin, /admin for others
    if (location == '/nhap-thu' || location == '/nhap-chi') {
      location = '/settings';
    }
    // For non-sadmin, /settings maps to /admin
    if (location == '/settings') {
      final role = context.read<AppStore>().currentUser?.role;
      if (role != 'sadmin') location = '/admin';
    }
    for (int i = 0; i < items.length; i++) {
      if (items[i].path == location) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final isOnOrderPage =
        GoRouterState.of(context).matchedLocation == '/';

    return Selector<AppStore, ({String? role, dynamic storeInfo, bool hasCart, int cartLen, int cartItemCount, double cartTotal, int pendingCount, int cookingCount})>(
      selector: (_, s) => (
        role: s.currentUser?.role,
        storeInfo: s.currentStoreInfo,
        hasCart: s.cart.isNotEmpty,
        cartLen: s.cart.length,
        cartItemCount: s.cartItemCount,
        cartTotal: s.getCartTotal(),
        pendingCount: s.pendingProcessing,
        cookingCount: s.cookingProcessing,
      ),
      builder: (context, data, child) {
    final store = context.read<AppStore>();
    final menuItems = _getMenuItems(store);
    final currentIdx = _getCurrentIndex(menuItems);
    final storeInfo = data.storeInfo;

    return Scaffold(
      body: Column(
        children: [
          _MobileHeader(store: store, storeInfo: storeInfo),
          Expanded(child: widget.child),
        ],
      ),

      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOnOrderPage && data.hasCart && MediaQuery.of(context).size.width < 600)
            _MobileCartBar(store: store),
          RepaintBoundary(
            child: _MobileBottomNav(
              menuItems: menuItems,
              currentIndex: currentIdx,
              store: store,
              onTap: (i) => _onTabTapped(i, menuItems),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

// ─── NavItem ──────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  final String path;
  const _NavItem(
      {required this.icon, required this.label, required this.path});
}


// ─── Mobile Header ────────────────────────────────────
class _MobileHeader extends StatelessWidget {
  final AppStore store;
  final dynamic storeInfo;

  const _MobileHeader(
      {required this.store, required this.storeInfo});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
            bottom: BorderSide(color: AppColors.slate200, width: 1)),
      ),
      child: Row(
        children: [
          // Logo + Store name (tappable for sadmin to switch stores)
          Expanded(
            child: _buildStoreSelectorArea(context),
          ),

          // Notification Bell
          const NotificationBell(),

          // User Avatar
          GestureDetector(
            onTap: () => showAccountDialog(context),
            child: _buildAvatarWidget(store, 16),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSelectorArea(BuildContext context) {
    final isSadmin = store.currentUser?.role == 'sadmin';
    final fieldKey = GlobalKey();

    // Current display name
    String displayName = storeInfo.name;
    if (isSadmin) {
      displayName = 'Moimoi POS';
    }

    final content = Row(
      key: fieldKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: AppColors.emerald500,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Text('POS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            displayName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.slate800),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (isSadmin) return content;

    return GestureDetector(
      onTap: () {
        final renderBox = fieldKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final position = renderBox.localToGlobal(Offset.zero);
        final fieldSize = renderBox.size;

        final storeEntries = store.storeInfos.entries.where((e) => e.key != 'sadmin').toList();
        final currentViewId = store.sadminViewStoreId;

        final items = <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'all',
            height: 44,
            child: Row(
              children: [
                const Icon(Icons.all_inclusive, size: 16, color: AppColors.violet500),
                const SizedBox(width: 8),
                const Text('Tất cả cửa hàng', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (currentViewId == 'all') ...[
                  const Spacer(),
                  const Icon(Icons.check_circle, size: 16, color: AppColors.emerald500),
                ],
              ],
            ),
          ),
          ...storeEntries.map((entry) {
            final sid = entry.key;
            final info = entry.value;
            final name = info.name.isNotEmpty ? info.name : sid;
            return PopupMenuItem<String>(
              value: sid,
              height: 44,
              child: Row(
                children: [
                  const Icon(Icons.store, size: 16, color: AppColors.emerald500),
                  const SizedBox(width: 8),
                  Expanded(child: Text(name, style: TextStyle(
                    fontWeight: sid == currentViewId ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                    color: sid == currentViewId ? AppColors.emerald600 : AppColors.slate800,
                  ), overflow: TextOverflow.ellipsis)),
                  if (info.isPremium)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.amber500, AppColors.orange500]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('VIP', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                    ),
                  if (sid == currentViewId) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle, size: 16, color: AppColors.emerald500),
                  ],
                ],
              ),
            );
          }),
        ];

        showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            position.dx,
            position.dy + fieldSize.height + 4,
            position.dx + fieldSize.width,
            position.dy + fieldSize.height + 300,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 8,
          items: items,
        ).then((v) {
          if (v != null) store.setSadminViewStoreId(v);
        });
      },
      child: content,
    );
  }
}
class _MobileCartBar extends StatelessWidget {
  final AppStore store;
  const _MobileCartBar({required this.store});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => MobileCartSheet.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.emerald500, AppColors.emerald600],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald500.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Cart icon with badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_bag_rounded,
                    color: Colors.white, size: 28),
                Positioned(
                  top: -6,
                  right: -8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.red500,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${store.cartItemCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            // Price
            Expanded(
              child: Text(
                _formatCurrency(store.getCartTotal()),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // View cart button
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Xem giỏ hàng',
                    style: TextStyle(
                      color: AppColors.emerald600,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded,
                      size: 16, color: AppColors.emerald600),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '$formatted đ';
  }
}

// ─── Mobile Bottom Nav ────────────────────────────────
class _MobileBottomNav extends StatelessWidget {
  final List<_NavItem> menuItems;
  final int currentIndex;
  final AppStore store;
  final ValueChanged<int> onTap;

  const _MobileBottomNav({
    required this.menuItems,
    required this.currentIndex,
    required this.store,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border:
            Border(top: BorderSide(color: AppColors.slate200, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(menuItems.length, (i) {
              final item = menuItems[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Pill-shaped active indicator
                          AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 300),
                            padding: EdgeInsets.symmetric(
                              horizontal: isActive ? 16 : 6,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.emerald50
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(16),
                            ),
                            child: Icon(
                              item.icon,
                              color: isActive
                                  ? AppColors.emerald600
                                  : AppColors.slate400,
                              size: isActive ? 22 : 24,
                            ),
                          ),
                          // Pending badge (red, left)
                          if (item.path == '/orders' &&
                              store.pendingProcessing > 0)
                            Positioned(
                              top: -4,
                              left: -6,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.red500,
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.white,
                                      width: 2),
                                ),
                                constraints:
                                    const BoxConstraints(
                                        minWidth: 17,
                                        minHeight: 17),
                                child: Text(
                                  '${store.pendingProcessing > 99 ? '99+' : store.pendingProcessing}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          // Cooking badge (orange, right)
                          if (item.path == '/orders' &&
                              store.cookingProcessing > 0)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.amber500,
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.white,
                                      width: 2),
                                ),
                                constraints:
                                    const BoxConstraints(
                                        minWidth: 17,
                                        minHeight: 17),
                                child: Text(
                                  '${store.cookingProcessing > 99 ? '99+' : store.cookingProcessing}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration:
                            const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: isActive ? 12 : 10,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive
                              ? AppColors.emerald600
                              : AppColors.slate400,
                        ),
                        child: Text(item.label),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

Uint8List _decodeAvatar(String dataUri) {
  final base64Part = dataUri.contains(',') ? dataUri.split(',').last : dataUri;
  return base64Decode(base64Part);
}

Widget _buildAvatarWidget(AppStore store, double radius) {
  final hasAvatar = store.currentUser?.avatar.isNotEmpty == true;
  final letter = (store.currentUser?.username.isNotEmpty == true)
      ? store.currentUser!.username[0].toUpperCase()
      : 'U';
  if (hasAvatar) {
    try {
      final bytes = _decodeAvatar(store.currentUser!.avatar);
      return ClipOval(
        child: Image.memory(
          bytes,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.emerald100,
            child: Text(letter, style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.7,
              color: AppColors.emerald600,
            )),
          ),
        ),
      );
    } catch (_) {}
  }
  return CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.emerald100,
    child: Text(letter, style: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: radius * 0.7,
      color: AppColors.emerald600,
    )),
  );
}
