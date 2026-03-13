import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../store/app_store.dart';
import '../screens/auth/auth_page.dart';
import '../screens/main_shell.dart';
import '../screens/order/order_page.dart';
import '../screens/kitchen/kitchen_page.dart';
import '../screens/dashboard/dashboard_page.dart';
import '../screens/settings/settings_page.dart';

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
        builder: (context, state) => const AuthPage(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: OrderPage(),
            ),
          ),
          GoRoute(
            path: '/kitchen',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: KitchenPage(),
            ),
          ),
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardPage(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsPage(),
            ),
          ),
        ],
      ),
    ],
  );
}
