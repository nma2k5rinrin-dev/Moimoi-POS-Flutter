import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../store/app_store.dart';
import '../screens/auth/auth_page.dart';
import '../screens/main_shell.dart';
import '../screens/order/order_page.dart';
import '../screens/orders/orders_page.dart';
import '../screens/dashboard/dashboard_page.dart';
import '../screens/settings/settings_page.dart';
import '../screens/inventory/inventory_page.dart';
import '../screens/settings/menu_management.dart';
import '../screens/admin/admin_dashboard_page.dart';

import '../screens/thu_chi/nhap_thu_page.dart';
import '../screens/thu_chi/nhap_chi_page.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

GoRouter createRouter(AppStore store) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    // Only re-evaluate redirects when auth state changes (login/logout),
    // NOT on every cart, toast, or search update.
    refreshListenable: store.authNotifier,
    redirect: (context, state) {
      final isLoggedIn = store.currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login';
      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) {
        // Sadmin → Admin dashboard, Admin → Reports, Staff → Order page
        final role = store.currentUser?.role;
        if (role == 'sadmin') return '/admin';
        if (role == 'admin') return '/dashboard';
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AuthPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => _fadeTransitionPage(
              key: state.pageKey,
              child: const OrderPage(),
            ),
          ),
          GoRoute(
            path: '/orders',
            pageBuilder: (context, state) => _fadeTransitionPage(
              key: state.pageKey,
              child: const OrdersPage(),
            ),
          ),
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => _fadeTransitionPage(
              key: state.pageKey,
              child: const DashboardPage(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => _fadeTransitionPage(
              key: state.pageKey,
              child: const SettingsPage(),
            ),
          ),

          GoRoute(
            path: '/admin',
            pageBuilder: (context, state) => _fadeTransitionPage(
              key: state.pageKey,
              child: const AdminDashboardPage(),
            ),
          ),
          GoRoute(
            path: '/inventory',
            pageBuilder: (context, state) => _fadeTransitionPage(
              key: state.pageKey,
              child: const MenuManagementSection(),
            ),
          ),

          GoRoute(
            path: '/nhap-thu',
            pageBuilder: (context, state) => _fadeTransitionPage(
              key: state.pageKey,
              child: const NhapThuPage(),
            ),
          ),
          GoRoute(
            path: '/nhap-chi',
            pageBuilder: (context, state) => _fadeTransitionPage(
              key: state.pageKey,
              child: const NhapChiPage(),
            ),
          ),
        ],
      ),
    ],
  );
}

/// Quick fade transition for in-app page switches (200ms).
CustomTransitionPage _fadeTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: child,
      );
    },
  );
}
