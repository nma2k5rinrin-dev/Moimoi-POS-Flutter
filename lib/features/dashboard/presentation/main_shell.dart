import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';

import 'package:moimoi_pos/core/state/ui_store.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';
import 'package:moimoi_pos/features/pos_order/logic/cart_store_standalone.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/state/order_filter_store.dart';
import 'package:moimoi_pos/core/utils/quota_helper.dart';
import 'package:moimoi_pos/features/premium/presentation/widgets/upgrade_dialog.dart';
import 'package:moimoi_pos/features/notifications/presentation/notification_bell.dart';

import 'package:moimoi_pos/features/pos_order/presentation/widgets/mobile_cart_sheet.dart';
import 'package:moimoi_pos/features/dashboard/presentation/widgets/account_dialog.dart';
import 'package:moimoi_pos/services/api/cloudflare_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

// Add imports in place 

class _MainShellState extends State<MainShell> {
  DateTime? _currentBackPressTime;
  final List<String> _tabHistory = [];

  static const List<_NavItem> _sadminMenuItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Tổng quan', path: '/admin'),
    _NavItem(icon: Icons.settings_rounded, label: 'Cài đặt', path: '/settings'),
  ];

  List<_NavItem> _getAdminMenuItems(bool canUseCashflow) => [
    _NavItem(icon: Icons.bar_chart, label: 'Báo Cáo', path: '/dashboard'),
    _NavItem(icon: PhosphorIconsBold.storefront, label: 'Bán hàng', path: '/'),
    _NavItem(
      icon: PhosphorIconsBold.clipboardText,
      label: 'Đơn hàng',
      path: '/orders',
    ),
    _NavItem(
      icon: PhosphorIconsBold.package,
      label: 'Quản lý kho',
      path: '/inventory',
    ),
    _NavItem(
      icon: Icons.account_balance_wallet_rounded,
      label: 'Thu nhập/Chi tiêu',
      path: '/settings?tab=cashflow',
      isLocked: !canUseCashflow,
    ),
  ];

  // Staff tabs: Order + Orders only
  static const List<_NavItem> _staffMenuItems = [
    _NavItem(icon: PhosphorIconsBold.storefront, label: 'Bán hàng', path: '/'),
    _NavItem(
      icon: PhosphorIconsBold.clipboardText,
      label: 'Đơn hàng',
      path: '/orders',
    ),
  ];

  List<_NavItem> _getMenuItems(UIStore store) {
    final role = context.watch<AuthStore>().currentUser?.role;
    final quota = QuotaHelper(context.read<ManagementStore>().quotaProvider);
    final canUseCashflow = quota.canUseThuChi;

    if (role == 'sadmin') return _sadminMenuItems;
    if (role == 'admin') return _getAdminMenuItems(canUseCashflow);

    List<_NavItem> items = [];

    if (context.read<ManagementStore>().hasPermission('tab_dashboard')) {
      items.add(const _NavItem(icon: Icons.bar_chart, label: 'Báo Cáo', path: '/dashboard'));
    }
    if (context.read<ManagementStore>().hasPermission('tab_pos')) {
      items.add(const _NavItem(icon: PhosphorIconsBold.storefront, label: 'Bán hàng', path: '/'));
    }
    if (context.read<ManagementStore>().hasPermission('tab_orders')) {
      items.add(const _NavItem(icon: PhosphorIconsBold.clipboardText, label: 'Đơn hàng', path: '/orders'));
    }
    if (context.read<ManagementStore>().hasPermission('tab_inventory')) {
      items.add(const _NavItem(icon: PhosphorIconsBold.package, label: 'Quản lý kho', path: '/inventory'));
    }
    if (context.read<ManagementStore>().hasPermission('tab_cashflow')) {
      items.add(_NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Thu chi', path: '/settings?tab=cashflow', isLocked: !canUseCashflow));
    }

    // Luôn cho xem cài đặt tối thiểu (vd: xem tài khoản cá nhân để đổi mật khẩu)
    items.add(const _NavItem(icon: Icons.settings_rounded, label: 'Cài đặt', path: '/settings'));

    return items;
  }

  void _onTabTapped(int index, List<_NavItem> items, int currentIdx) {
    if (items[index].isLocked) {
      final quota = QuotaHelper(context.read<ManagementStore>().quotaProvider);
      showUpgradePrompt(context, quota.transactionLimitMsg);
      return;
    }
    
    final location = GoRouterState.of(context).matchedLocation;
    final nextLocation = items[index].path;
    if (index == currentIdx) {
      if (GoRouter.of(context).canPop()) {
        // Clear push stack to return to the base of the current tab
        context.go(location);
      } else {
        context.read<UIStore>().triggerScrollToTop(nextLocation);
      }
    } else {
      _tabHistory.add(location);
      context.go(nextLocation);
    }
  }

  int _getCurrentIndex(List<_NavItem> items) {
    if (items.isEmpty) return -1;
    var location = GoRouterState.of(context).matchedLocation;
    final uri = GoRouterState.of(context).uri;
    final role = context.read<AuthStore>().currentUser?.role;

    // Default base match
    int idx = items.indexWhere((item) => item.path == location);

    // Custom highlight logic for admin menus inside Settings
    if (location == '/settings') {
      final tab = uri.queryParameters['tab'];
      if (tab == 'cashflow' || tab == 'thu-chi') {
        idx = items.indexWhere((item) => item.path.contains('tab=cashflow'));
      } else if (role != 'sadmin') {
        // If they enter settings without a cashflow tab, map to overview for admin
        location = '/admin';
        idx = items.indexWhere((item) => item.path == location);
      } else {
        idx = items.indexWhere((item) => item.path == '/settings');
      }
    }

    // Custom highlight logic when on sub-pages (nhap-thu/nhap-chi)
    if (location == '/nhap-thu' || location == '/nhap-chi') {
      if (role == 'sadmin') {
        idx = items.indexWhere((item) => item.path == '/settings');
      } else {
        idx = items.indexWhere((item) => item.path.contains('tab=cashflow'));
      }
    }

    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final isOnOrderPage = GoRouterState.of(context).matchedLocation == '/';

    final authState = context.watch<AuthStore>();
    final cartState = context.watch<CartStore>();
    final filterState = context.watch<OrderFilterStore>();
    final mgmtState = context.watch<ManagementStore>();

    final user = authState.currentUser;
    final role = user?.role;
    final avatar = user?.avatar;
    final storeInfo = mgmtState.storeInfos[mgmtState.getStoreId()];
    
    final hasCart = cartState.cart.isNotEmpty;
    final cartLen = cartState.cart.length;
    final cartItemCount = cartState.cartItemCount;
    final cartTotal = cartState.getCartTotal();
    
    final pendingCount = filterState.pendingProcessing;
    final processingCount = filterState.processingProcessing;

    final store = context.read<UIStore>();
    final menuItems = _getMenuItems(store);
    final currentIdx = _getCurrentIndex(menuItems);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;

            // 1. Pop pushed routes or dialogs
            if (GoRouter.of(context).canPop()) {
              context.pop();
              return;
            }

            // 2. Pop tab history
            if (_tabHistory.isNotEmpty) {
              final prev = _tabHistory.removeLast();
              context.go(prev);
              return;
            }

            // 3. Jump to Main Role Screen
            final role = context.read<AuthStore>().currentUser?.role;
            final mgmtStore = context.read<ManagementStore>();
            String homePath = '/';
            if (role == 'sadmin') {
              homePath = '/admin';
            } else if (role == 'admin' || mgmtStore.hasPermission('tab_dashboard')) {
              homePath = '/dashboard';
            }

            final location = GoRouterState.of(context).matchedLocation;
            if (location != homePath) {
              context.go(homePath);
              return;
            }

            // 4. Exit App
            DateTime now = DateTime.now();
            if (_currentBackPressTime == null ||
                now.difference(_currentBackPressTime!) >
                    const Duration(seconds: 2)) {
              _currentBackPressTime = now;
              store.showToast('Nhấn quay lại lần nữa để thoát');
            } else {
              SystemNavigator.pop();
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.scaffoldBg,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (MediaQuery.of(context).size.width < 600)
                    _MobileHeader(
                      store: store,
                      storeInfo: storeInfo,
                    ),
                  Expanded(
                    child: widget.child,
                  ),
                ],
              ),
            ),

            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOnOrderPage &&
                    hasCart &&
                    MediaQuery.of(context).size.width < 600)
                  _MobileCartBar(store: store),
                RepaintBoundary(
                  child: _MobileBottomNav(
                    menuItems: menuItems,
                    currentIndex: currentIdx,
                    store: store,
                    onTap: (i) => _onTabTapped(i, menuItems, currentIdx),
                  ),
                ),
              ],
            ),
          ),
        );
  }
}

// ─── NavItem ──────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  final String path;
  final bool isLocked;
  const _NavItem({required this.icon, required this.label, required this.path, this.isLocked = false});
}

// ─── Mobile Header ────────────────────────────────────
class _MobileHeader extends StatelessWidget {
  final UIStore store;
  final dynamic storeInfo;

  const _MobileHeader({required this.store, required this.storeInfo});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(bottom: BorderSide(color: AppColors.slate200, width: 1)),
      ),
      child: Row(
        children: [
          // Logo + Store name (tappable for sadmin to switch stores)
          Expanded(child: _buildStoreSelectorArea(context)),

          // Notification Bell
          const NotificationBell(),

          SizedBox(width: 16), // Thêm khoảng cách giữa chuông và hình đại diện
          // User Avatar
          GestureDetector(
            onTap: () => showAccountDialog(context),
            child: _buildAvatarWidget(context.watch<AuthStore>(), 16), // Tăng kích thước avatar
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSelectorArea(BuildContext context) {
    final isSadmin = context.watch<AuthStore>().currentUser?.role == 'sadmin';

    // Current display name
    String displayName = storeInfo?.name ?? 'Đang tải...';
    if (isSadmin) {
      displayName = 'Moimoi POS';
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStoreLogoWidget(
          isSadmin ? '' : (storeInfo?.logoUrl ?? ''),
          40,
        ), // Tăng kích thước logo
        SizedBox(width: 12),
        Flexible(
          child: Text(
            displayName,
            style: TextStyle(
              fontWeight: FontWeight.w700, // Đậm hơn chút
              fontSize: 16, // Tên to hơn
              color: AppColors.slate800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (isSadmin) {
            context.go('/admin');
          } else {
            context.go('/');
          }
        },
        child: content,
      ),
    );
  }
}

class _MobileCartBar extends StatelessWidget {
  final UIStore store;
  const _MobileCartBar({required this.store});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => MobileCartSheet.show(context),
      child: Container(
        height: 72, // Chiều cao cố định cho panel
        padding: EdgeInsets.only(left: 20), // Xoá padding trên dưới và phải để nút chiếm trọn
        decoration: BoxDecoration(
          gradient: LinearGradient(
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
          crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch để nút view cart full chiều cao
          children: [
            // Cart icon with badge
            Center( // Center contents vertically
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 30),
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.red500,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.emerald600, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${context.watch<CartStore>().cartItemCount}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            // Price
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatCurrency(context.read<CartStore>().getCartTotal()),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22, // Tăng font size từ 16 lên 22
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Text 'Xem giỏ hàng' (No button shape)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Xem giỏ hàng',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '$formatted đ';
  }
}

// ─── Sticky Header Delegate ─────────────────────────────
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyHeaderDelegate({required this.child});
  @override
  double get minExtent => 64.0;
  @override
  double get maxExtent => 64.0;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.cardBg, child: child);
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

// ─── Mobile Bottom Nav ────────────────────────────────
class _MobileBottomNav extends StatelessWidget {
  final List<_NavItem> menuItems;
  final int currentIndex;
  final UIStore store;
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
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.slate200, width: 1)),
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
                            duration: const Duration(milliseconds: 300),
                            padding: EdgeInsets.symmetric(
                              horizontal: isActive ? 16 : 6,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.emerald50
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              item.icon,
                              color: isActive
                                  ? AppColors.emerald600
                                  : AppColors.slate400,
                              size: isActive ? 22 : 24,
                            ),
                          ),
                          // Locked badge (amber padlock, top right)
                          if (item.isLocked)
                            Positioned(
                              top: -2,
                              right: -4,
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: AppColors.amber500,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.cardBg,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.lock_rounded,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          // Pending badge (red, left)
                          if (item.path == '/orders' &&
                              context.watch<OrderFilterStore>().pendingProcessing > 0)
                            Positioned(
                              top: -4,
                              left: -6,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.red500,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.cardBg,
                                    width: 2,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 17,
                                  minHeight: 17,
                                ),
                                child: Text(
                                  '${context.watch<OrderFilterStore>().pendingProcessing > 99 ? '99+' : context.watch<OrderFilterStore>().pendingProcessing}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          // Processing badge (orange, right)
                          if (item.path == '/orders' &&
                              context.watch<OrderFilterStore>().processingProcessing > 0)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.amber500,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.cardBg,
                                    width: 2,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 17,
                                  minHeight: 17,
                                ),
                                child: Text(
                                  '${context.watch<OrderFilterStore>().processingProcessing > 99 ? '99+' : context.watch<OrderFilterStore>().processingProcessing}',
                                  style: TextStyle(
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
                      SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
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

Widget _buildAvatarWidget(AuthStore authStore, double radius) {
  final user = authStore.currentUser;
  final hasAvatar = user?.avatar.isNotEmpty == true;
  final fn = user?.fullname ?? '';
  final ph = user?.phone ?? '';
  final fallbackName = fn.isNotEmpty ? fn : (ph.isNotEmpty ? ph : 'U');
  final letter = fallbackName[0].toUpperCase();

  Widget fallbackAvatar() => CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.emerald100,
    child: Text(
      letter,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.7,
        color: AppColors.emerald600,
      ),
    ),
  );

  if (user == null || !hasAvatar) return fallbackAvatar();

  final avatar = user.avatar;
  if (CloudflareService.isUrl(avatar)) {
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatar,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (_, _) => const CircularProgressIndicator(strokeWidth: 2),
        errorWidget: (_, _, _) => fallbackAvatar(),
      ),
    );
  }
  try {
    final bytes = _decodeAvatar(avatar);
    return ClipOval(
      child: Image.memory(
        bytes,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallbackAvatar(),
      ),
    );
  } catch (_) {}
  return fallbackAvatar();
}

Widget _buildStoreLogoWidget(String logoUrl, double size) {
  Widget fallbackLogo() => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.asset(
      'assets/images/app_logo_1024x1024.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    ),
  );

  if (logoUrl.isEmpty) return fallbackLogo();

  if (CloudflareService.isUrl(logoUrl)) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallbackLogo(),
        errorWidget: (_, _, _) => fallbackLogo(),
      ),
    );
  }

  try {
    final bytes = _decodeAvatar(logoUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallbackLogo(),
      ),
    );
  } catch (_) {
    return fallbackLogo();
  }
}
