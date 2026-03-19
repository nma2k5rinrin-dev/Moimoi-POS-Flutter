import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../store/app_store.dart';
import '../screens/auth/auth_page.dart';
import '../screens/main_shell.dart';
import '../screens/order/order_page.dart';
import '../screens/kitchen/kitchen_page.dart';
import '../screens/dashboard/dashboard_page.dart';
import '../screens/settings/settings_page.dart';
import '../screens/premium/premium_page.dart';
import '../screens/inventory/inventory_page.dart';
import '../screens/settings/menu_management.dart';

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
      if (isLoggedIn && isLoggingIn) return '/';
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
            path: '/kitchen',
            pageBuilder: (context, state) => _fadeTransitionPage(
              key: state.pageKey,
              child: const KitchenPage(),
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
            path: '/premium',
            pageBuilder: (context, state) => _fadeTransitionPage(
              key: state.pageKey,
              child: const PremiumPage(),
            ),
          ),
          GoRoute(
            path: '/inventory',
            pageBuilder: (context, state) => _fadeTransitionPage(
              key: state.pageKey,
              child: const MenuManagementSection(),
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
