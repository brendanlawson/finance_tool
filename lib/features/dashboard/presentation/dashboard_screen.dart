import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/adaptive_shell.dart';
import '../../categories/application/category_providers.dart';
import '../../categories/domain/category_entity.dart';
import '../../settings/application/profile_providers.dart';
import '../../transactions/domain/transaction_type.dart';
import '../../wallets/application/wallet_providers.dart';
import '../application/dashboard_providers.dart';
import 'widgets/cash_flow_card.dart';
import 'widgets/net_worth_card.dart';
import 'widgets/recent_transactions_list.dart';
import 'widgets/spending_breakdown_chart.dart';
import 'widgets/wallet_balances_list.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: profile.when(
        data: (p) => _DashboardBody(baseCurrency: p.baseCurrency),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Could not load: $error')),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.baseCurrency});

  final String baseCurrency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netWorth = ref.watch(netWorthProvider);
    final cashFlow = ref.watch(monthlyCashFlowProvider(baseCurrency));
    final breakdown = ref.watch(
      monthlyCategoryBreakdownProvider((currencyCode: baseCurrency, type: TransactionType.expense)),
    );
    final wallets = ref.watch(walletsProvider);
    final recent = ref.watch(recentTransactionsProvider);
    final categories = ref.watch(categoriesProvider(null));

    final categoriesById = <String, Category>{
      for (final c in categories.value ?? const <Category>[]) c.id: c,
    };

    final topSection = netWorth.when(
      data: (nw) => NetWorthCard(netWorth: nw, baseCurrency: baseCurrency),
      loading: () => const _LoadingCard(),
      error: (error, stackTrace) => _ErrorCard(error: error),
    );
    final cashFlowSection = cashFlow.when(
      data: (cf) => CashFlowCard(cashFlow: cf),
      loading: () => const _LoadingCard(),
      error: (error, stackTrace) => _ErrorCard(error: error),
    );
    final breakdownSection = breakdown.when(
      data: (entries) => SpendingBreakdownChart(entries: entries, categoriesById: categoriesById),
      loading: () => const _LoadingCard(),
      error: (error, stackTrace) => _ErrorCard(error: error),
    );
    final walletsSection = WalletBalancesList(wallets: wallets.value ?? const []);
    final recentSection = RecentTransactionsList(transactions: recent.value ?? const []);

    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

    if (isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  topSection,
                  const SizedBox(height: 16),
                  cashFlowSection,
                  const SizedBox(height: 16),
                  breakdownSection,
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                children: [walletsSection, const SizedBox(height: 16), recentSection],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        topSection,
        const SizedBox(height: 12),
        cashFlowSection,
        const SizedBox(height: 12),
        breakdownSection,
        const SizedBox(height: 12),
        walletsSection,
        const SizedBox(height: 12),
        recentSection,
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(20), child: Text('Could not load: $error')),
    );
  }
}
