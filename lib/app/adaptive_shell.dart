import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Below this width, use a mobile bottom nav bar; at or above it, a
/// desktop navigation rail with a side panel — the same breakpoint
/// Material 3 guidance uses for compact vs. medium/expanded layouts.
/// Reused wherever a screen needs its own responsive split (e.g. the
/// dashboard's single-column vs. multi-column layout), so the whole app
/// switches layouts at one consistent point rather than each screen
/// guessing its own threshold.
const double kDesktopBreakpoint = 700;

const _destinations = [
  (icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard'),
  (icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Transactions'),
  (icon: Icons.credit_card_outlined, selectedIcon: Icons.credit_card, label: 'Debts'),
  (icon: Icons.more_horiz, selectedIcon: Icons.more_horiz, label: 'More'),
];

/// Wraps go_router's [StatefulShellRoute] indexed stack with either a
/// bottom [NavigationBar] (mobile) or a side [NavigationRail] (desktop) —
/// same routes, same domain/application layer underneath, different shell
/// widget only (§23: "reuse domain and application logic across
/// layouts... do not simply stretch a mobile interface onto desktop").
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    return isDesktop ? _buildDesktop(context) : _buildMobile(context);
  }

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/fast-add'),
        tooltip: 'Add transaction',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) =>
            navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            labelType: NavigationRailLabelType.all,
            leading: FloatingActionButton(
              onPressed: () => context.push('/fast-add'),
              tooltip: 'Add transaction',
              child: const Icon(Icons.add),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
