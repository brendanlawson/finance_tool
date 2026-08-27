import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../domain/net_worth.dart';

class NetWorthCard extends StatelessWidget {
  const NetWorthCard({super.key, required this.netWorth, required this.baseCurrency});

  final NetWorth netWorth;
  final String baseCurrency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = netWorth.forCurrency(baseCurrency) ?? Money.zero(baseCurrency);
    final assets = netWorth.assetsByCurrency[baseCurrency] ?? Money.zero(baseCurrency);
    final liabilities = netWorth.liabilitiesByCurrency[baseCurrency] ?? Money.zero(baseCurrency);
    final otherCurrencies = netWorth.currencies.where((c) => c != baseCurrency).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Net worth', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              total.format(),
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _MiniStat(label: 'Assets', value: assets.format(), color: theme.colorScheme.primary),
                const SizedBox(width: 24),
                _MiniStat(
                  label: 'Liabilities',
                  value: liabilities.format(),
                  color: theme.colorScheme.error,
                ),
              ],
            ),
            if (otherCurrencies.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Also holds balances in ${otherCurrencies.join(', ')}, not included above.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16)),
      ],
    );
  }
}
