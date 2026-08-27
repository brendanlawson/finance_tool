import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/money/money.dart';
import '../../domain/monthly_report.dart';

class CashFlowCard extends StatelessWidget {
  const CashFlowCard({super.key, required this.cashFlow});

  final MonthlyCashFlow cashFlow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This month', style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Amount(
                    label: 'Income',
                    money: cashFlow.income,
                    color: theme.colorScheme.income,
                  ),
                ),
                Expanded(
                  child: _Amount(
                    label: 'Expenses',
                    money: cashFlow.expenses,
                    color: theme.colorScheme.expense,
                  ),
                ),
                Expanded(
                  child: _Amount(
                    label: 'Cash flow',
                    money: cashFlow.net,
                    color: cashFlow.net.isNegative ? theme.colorScheme.expense : theme.colorScheme.income,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.money, required this.color});

  final String label;
  final Money money;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          money.format(),
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
