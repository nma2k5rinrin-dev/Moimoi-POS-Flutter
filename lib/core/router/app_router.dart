import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';
import 'package:moimoi_pos/features/auth/presentation/auth_page.dart';
import 'package:moimoi_pos/features/dashboard/presentation/main_shell.dart';
import 'package:moimoi_pos/features/pos_order/presentation/order_page.dart';
import 'package:moimoi_pos/features/pos_order/presentation/history/orders_page.dart';
import 'package:moimoi_pos/features/dashboard/presentation/dashboard_page.dart';
import 'package:moimoi_pos/features/settings/presentation/settings_page.dart';
import 'package:moimoi_pos/features/settings/presentation/menu_management.dart';
import 'package:moimoi_pos/features/sadmin/presentation/admin_dashboard_page.dart';

import 'package:moimoi_pos/features/cashflow/presentation/income_page.dart';
import 'package:moimoi_pos/features/cashflow/presentation/expense_page.dart';
import 'package:moimoi_pos/features/sadmin/presentation/sadmin_notifications_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

GoRouter createRouter(AuthStore store) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) => _noTransitionPage(
                  key: state.pageKey,
                  child: const OrderPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                pageBuilder: (context, state) => _noTransitionPage(
                  key: state.pageKey,
                  child: const OrdersPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                pageBuilder: (context, state) => _noTransitionPage(
                  key: state.pageKey,
                  child: const DashboardPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) => _noTransitionPage(
                  key: state.pageKey,
                  child: const SettingsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin',
                pageBuilder: (context, state) => _noTransitionPage(
                  key: state.pageKey,
                  child: const AdminDashboardPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory',
                pageBuilder: (context, state) => _noTransitionPage(
                  key: state.pageKey,
                  child: const MenuManagementSection(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sadmin/notifications',
                pageBuilder: (context, state) => _noTransitionPage(
                  key: state.pageKey,
                  child: const SadminNotificationsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/nhap-thu',
                pageBuilder: (context, state) => _noTransitionPage(
                  key: state.pageKey,
                  child: const IncomePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/nhap-chi',
                pageBuilder: (context, state) => _noTransitionPage(
                  key: state.pageKey,
                  child: const ExpensePage(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// No transition for tab routing to feel instantaneous like normal bottom navigation widget
NoTransitionPage _noTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return NoTransitionPage(
    key: key,
    child: child,
  );
}
