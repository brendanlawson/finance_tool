import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/debts/presentation/debts_screen.dart';
import '../features/settings/presentation/more_screen.dart';
import '../features/transactions/presentation/fast_add_screen.dart';
import '../features/transactions/presentation/transaction_list_screen.dart';
import 'adaptive_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _dashboardNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'dashboard');
final _transactionsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'transactions');
final _debtsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'debts');
final _moreNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'more');

/// Four persistent sections (Dashboard/Transactions/Debts/More), each with
/// its own navigation stack via [StatefulShellBranch] so switching tabs
/// doesn't lose where you were in another tab. "Fast Add" (§9) is
/// deliberately not a fifth branch — it is a single-purpose modal flow
/// pushed on the root navigator (see [_fastAddRoute]), matching how it is
/// triggered (a FAB, not a persistent destination) in
/// lib/app/adaptive_shell.dart.
final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AdaptiveShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          navigatorKey: _dashboardNavigatorKey,
          routes: [
            GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _transactionsNavigatorKey,
          routes: [
            GoRoute(
              path: '/transactions',
              builder: (context, state) => const TransactionListScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _debtsNavigatorKey,
          routes: [
            GoRoute(path: '/debts', builder: (context, state) => const DebtsScreen()),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _moreNavigatorKey,
          routes: [
            GoRoute(path: '/more', builder: (context, state) => const MoreScreen()),
          ],
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/fast-add',
      pageBuilder: (context, state) => const MaterialPage(
        fullscreenDialog: true,
        child: FastAddScreen(),
      ),
    ),
  ],
);
