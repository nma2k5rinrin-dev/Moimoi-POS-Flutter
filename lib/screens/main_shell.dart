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
  static const List<_NavItem> _adminMenuItems = [
    _NavItem(icon: Icons.bar_chart, label: 'Báo Cáo', path: '/dashboard'),
    _NavItem(icon: PhosphorIconsBold.storefront, label: 'Bán hàng', path: '/'),
    _NavItem(icon: PhosphorIconsBold.clipboardText, label: 'Đơn hàng', path: '/orders'),
    _NavItem(icon: PhosphorIconsBold.package, label: 'Quản lý kho', path: '/inventory'),
    _NavItem(icon: Icons.settings_outlined, label: 'Cài đặt', path: '/settings'),
  ];

  // Staff tabs: Order + Orders only
  static const List<_NavItem> _staffMenuItems = [
    _NavItem(icon: PhosphorIconsBold.storefront, label: 'Bán hàng', path: '/'),
    _NavItem(icon: PhosphorIconsBold.clipboardText, label: 'Đơn hàng', path: '/orders'),
  ];

  List<_NavItem> _getMenuItems(AppStore store) {
    final isAdmin = ['admin', 'sadmin'].contains(store.currentUser?.role);
    return isAdmin ? _adminMenuItems : _staffMenuItems;
  }

  void _onTabTapped(int index, List<_NavItem> items) {
    context.go(items[index].path);
  }

  int _getCurrentIndex(List<_NavItem> items) {
    var location = GoRouterState.of(context).matchedLocation;
    // Settings sub-routes → map to /settings
    if (location == '/nhap-thu' || location == '/nhap-chi' || location == '/premium') {
      location = '/settings';
    }
    for (int i = 0; i < items.length; i++) {
      if (items[i].path == location) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    final isOnOrderPage =
        GoRouterState.of(context).matchedLocation == '/';

    return Selector<AppStore, ({String? role, dynamic storeInfo, bool hasCart, int cartLen, int cartItemCount, double cartTotal})>(
      selector: (_, s) => (
        role: s.currentUser?.role,
        storeInfo: s.currentStoreInfo,
        hasCart: s.cart.isNotEmpty,
        cartLen: s.cart.length,
        cartItemCount: s.cartItemCount,
        cartTotal: s.getCartTotal(),
      ),
      builder: (context, data, child) {
    final store = context.read<AppStore>();
    final menuItems = _getMenuItems(store);
    final currentIdx = _getCurrentIndex(menuItems);
    final storeInfo = data.storeInfo;

    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar (Desktop) ────────────────
          if (isWide)
            RepaintBoundary(
              child: _DesktopSidebar(
                store: store,
                menuItems: menuItems,
                currentIndex: currentIdx,
                storeInfo: storeInfo,
                onTap: (i) => _onTabTapped(i, menuItems),
              ),
            ),

          // ── Main Content ────────────────────
          Expanded(
            child: Column(
              children: [
                // Mobile header
                if (!isWide)
                  _MobileHeader(store: store, storeInfo: storeInfo),


                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),

      // ── Cart Bar (Mobile) ──────────────────
      bottomNavigationBar: isWide
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient cart bar
                if (!isWide && isOnOrderPage && data.hasCart)
                  _MobileCartBar(store: store),
                // Bottom Navigation
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

// ─── Desktop Sidebar ──────────────────────────────────
class _DesktopSidebar extends StatelessWidget {
  final AppStore store;
  final List<_NavItem> menuItems;
  final int currentIndex;
  final dynamic storeInfo;
  final ValueChanged<int> onTap;

  const _DesktopSidebar({
    required this.store,
    required this.menuItems,
    required this.currentIndex,
    required this.storeInfo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isExpanded = MediaQuery.of(context).size.width >= 1024;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isExpanded ? 250 : 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        border:
            Border(right: BorderSide(color: AppColors.slate200, width: 1)),
      ),
      child: Column(
        children: [
          // Logo / Store Name
          Container(
            height: 80,
            padding:
                EdgeInsets.symmetric(horizontal: isExpanded ? 20 : 12),
            alignment:
                isExpanded ? Alignment.centerLeft : Alignment.center,
            decoration: const BoxDecoration(
              border: Border(
                  bottom:
                      BorderSide(color: AppColors.slate100, width: 1)),
            ),
            child: Row(
              mainAxisSize:
                  isExpanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.emerald500,
                        AppColors.emerald600
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color:
                            AppColors.emerald500.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: storeInfo.logoUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: storeInfo.logoUrl.startsWith('data:')
                              ? Image.memory(
                                  _decodeAvatar(storeInfo.logoUrl),
                                  fit: BoxFit.cover,
                                  width: 40,
                                  height: 40,
                                  errorBuilder: (_, __, ___) => const Text(
                                    'POS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : Image.network(
                                  storeInfo.logoUrl,
                                  fit: BoxFit.cover,
                                  width: 40,
                                  height: 40,
                                  errorBuilder: (_, __, ___) => const Text(
                                    'POS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                        )
                      : const Text(
                          'POS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      storeInfo.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.slate800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Navigation Items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 24, horizontal: 12),
              child: Column(
                children: List.generate(menuItems.length, (i) {
                  final item = menuItems[i];
                  final isActive = i == currentIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onTap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: isExpanded ? 16 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.emerald50
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: isExpanded
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: [
                              if (isActive)
                                Container(
                                  width: 3,
                                  height: 24,
                                  margin:
                                      const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald500,
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                ),
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    item.icon,
                                    color: isActive
                                        ? AppColors.emerald600
                                        : AppColors.slate500,
                                    size: isActive ? 26 : 24,
                                  ),
                                  // Pending badge (red, top-left)
                                  if (item.path == '/orders' &&
                                      store.pendingProcessing > 0)
                                    Positioned(
                                      top: -6,
                                      left: -8,
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
                                                minWidth: 18,
                                                minHeight: 18),
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
                                  // Cooking badge (orange, top-right)
                                  if (item.path == '/orders' &&
                                      store.cookingProcessing > 0)
                                    Positioned(
                                      top: -6,
                                      right: -8,
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
                                                minWidth: 18,
                                                minHeight: 18),
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
                              if (isExpanded) ...[
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: TextStyle(
                                      fontWeight: isActive
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isActive
                                          ? AppColors.emerald600
                                          : AppColors.slate500,
                                      fontSize: 15,
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
                }),
              ),
            ),
          ),

          // Notification bell (desktop)
          if (store.notifications.isNotEmpty ||
              store.notifications.any((n) => !n.read))
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: NotificationBell(),
            ),

          // User Profile
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: AppColors.slate100, width: 1)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                context.go('/settings?tab=account');
              },
              child: Row(
                mainAxisAlignment: isExpanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  _buildAvatarWidget(store, 20),
                  if (isExpanded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            store.currentUser?.fullname.isNotEmpty ==
                                    true
                                ? store.currentUser!.fullname
                                : store.currentUser?.username ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.slate800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            store.currentUser?.role == 'sadmin'
                                ? 'Super Admin 👑'
                                : store.currentUser?.isPremium == true
                                    ? 'Premium 💎'
                                    : 'Gói Basic',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  store.currentUser?.isPremium == true
                                      ? AppColors.amber500
                                      : AppColors.slate500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildAvatarWidget(store, 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.currentUser?.fullname.isNotEmpty ==
                                    true
                                ? store.currentUser!.fullname
                                : store.currentUser?.username ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.slate800,
                            ),
                          ),
                          Text(
                            '@${store.currentUser?.username ?? ''}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: store.currentUser?.role == 'sadmin'
                            ? AppColors.violet100
                            : store.currentUser?.role == 'admin'
                                ? AppColors.emerald50
                                : AppColors.slate100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        store.currentUser?.role == 'sadmin'
                            ? '👑 SA'
                            : store.currentUser?.role == 'admin'
                                ? 'Admin'
                                : 'Staff',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: store.currentUser?.role == 'sadmin'
                              ? AppColors.violet600
                              : store.currentUser?.role == 'admin'
                                  ? AppColors.emerald600
                                  : AppColors.slate600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                // Upgrade option for non-premium
                if (store.currentUser?.role == 'admin' &&
                    store.currentUser?.isPremium != true)
                  ListTile(
                    leading: const Icon(Icons.diamond,
                        color: AppColors.amber500),
                    title: const Text(
                      'Nâng cấp VIP',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.amber600,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      store.setUpgradeModalOpen(true);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.logout,
                      color: AppColors.red500),
                  title: const Text(
                    'Đăng xuất',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.red500,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    store.logout();
                    context.go('/login');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
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
          // Logo
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.emerald500,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Text(
              'POS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              storeInfo.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.slate800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
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
}

// ─── Mobile Cart Bar ──────────────────────────────────
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
