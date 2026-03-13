import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../store/app_store.dart';
import '../utils/constants.dart';
import '../widgets/notification_bell.dart';
import '../widgets/store_selector.dart';
import '../widgets/mobile_cart_sheet.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const List<_NavItem> _allMenuItems = [
    _NavItem(icon: Icons.restaurant, label: 'Order', path: '/'),
    _NavItem(icon: Icons.soup_kitchen, label: 'Bếp', path: '/kitchen'),
    _NavItem(icon: Icons.bar_chart, label: 'Báo Cáo', path: '/dashboard'),
    _NavItem(icon: Icons.settings, label: 'Cài Đặt', path: '/settings'),
  ];

  List<_NavItem> _getMenuItems(AppStore store) {
    final isAdmin = ['admin', 'sadmin'].contains(store.currentUser?.role);
    if (isAdmin) return _allMenuItems;
    return _allMenuItems.sublist(0, 2); // Staff: Order + Kitchen only
  }

  void _onTabTapped(int index, List<_NavItem> items) {
    context.go(items[index].path);
  }

  int _getCurrentIndex(List<_NavItem> items) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < items.length; i++) {
      if (items[i].path == location) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final menuItems = _getMenuItems(store);
    final currentIdx = _getCurrentIndex(menuItems);
    final storeInfo = store.currentStoreInfo;
    final isWide = MediaQuery.of(context).size.width >= 768;
    final isOnOrderPage =
        GoRouterState.of(context).matchedLocation == '/';

    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar (Desktop) ────────────────
          if (isWide)
            _DesktopSidebar(
              store: store,
              menuItems: menuItems,
              currentIndex: currentIdx,
              storeInfo: storeInfo,
              onTap: (i) => _onTabTapped(i, menuItems),
            ),

          // ── Main Content ────────────────────
          Expanded(
            child: Column(
              children: [
                // Mobile header
                if (!isWide)
                  _MobileHeader(store: store, storeInfo: storeInfo),

                // SuperAdmin store selector
                if (store.currentUser?.role == 'sadmin')
                  const StoreSelector(),

                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),

      // ── Mobile Cart FAB ──────────────────
      floatingActionButton: (!isWide && isOnOrderPage && store.cart.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: () => MobileCartSheet.show(context),
              backgroundColor: AppColors.emerald500,
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: Text(
                '${store.cartItemCount} món · ${_formatShortCurrency(store.getCartTotal())}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      // ── Bottom Nav (Mobile) ──────────────
      bottomNavigationBar: isWide
          ? null
          : _MobileBottomNav(
              menuItems: menuItems,
              currentIndex: currentIdx,
              store: store,
              onTap: (i) => _onTabTapped(i, menuItems),
            ),
    );
  }

  String _formatShortCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}tr';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return '${amount.toStringAsFixed(0)}đ';
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
                          child: Image.network(
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
                                  if (item.path == '/kitchen' &&
                                      store.pendingKitchen > 0)
                                    Positioned(
                                      top: -6,
                                      right: -8,
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
                                          '${store.pendingKitchen > 99 ? '99+' : store.pendingKitchen}',
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
                _showUserMenu(context);
              },
              child: Row(
                mainAxisAlignment: isExpanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.emerald100,
                    backgroundImage:
                        store.currentUser?.avatar.isNotEmpty == true
                            ? NetworkImage(store.currentUser!.avatar)
                            : null,
                    child: store.currentUser?.avatar.isEmpty != false
                        ? Text(
                            (store.currentUser?.username.isNotEmpty ==
                                    true)
                                ? store.currentUser!.username[0]
                                    .toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.emerald600,
                            ),
                          )
                        : null,
                  ),
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
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.emerald100,
                      child: Text(
                        store.currentUser?.username.isNotEmpty == true
                            ? store.currentUser!.username[0]
                                .toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.emerald600,
                          fontSize: 18,
                        ),
                      ),
                    ),
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
            onTap: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (ctx) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.emerald100,
                              child: Text(
                                store.currentUser?.username
                                            .isNotEmpty ==
                                        true
                                    ? store.currentUser!.username[0]
                                        .toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.emerald600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  store.currentUser?.fullname
                                              .isNotEmpty ==
                                          true
                                      ? store.currentUser!.fullname
                                      : store.currentUser?.username ??
                                          '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.slate800,
                                  ),
                                ),
                                Text(
                                  store.currentUser?.role == 'sadmin'
                                      ? 'Super Admin 👑'
                                      : store.currentUser?.isPremium ==
                                              true
                                          ? 'VIP 💎'
                                          : 'Gói Miễn Phí',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.slate500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.logout,
                              color: AppColors.red500),
                          title: const Text('Đăng xuất',
                              style: TextStyle(
                                  color: AppColors.red500,
                                  fontWeight: FontWeight.w600)),
                          onTap: () {
                            Navigator.pop(ctx);
                            store.logout();
                            context.go('/login');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.emerald100,
              child: Text(
                store.currentUser?.username.isNotEmpty == true
                    ? store.currentUser!.username[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppColors.emerald600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
                          AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.emerald50
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item.icon,
                              color: isActive
                                  ? AppColors.emerald600
                                  : AppColors.slate400,
                              size: 24,
                            ),
                          ),
                          if (item.path == '/kitchen' &&
                              store.pendingKitchen > 0)
                            Positioned(
                              top: -4,
                              right: -6,
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
                                  '${store.pendingKitchen > 99 ? '99+' : store.pendingKitchen}',
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
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
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
