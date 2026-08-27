import 'package:flutter/material.dart';

import '../../../transactions/domain/transaction_entity.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';

class RecentTransactionsList extends StatelessWidget {
  const RecentTransactionsList({super.key, required this.transactions});

  final List<TransactionEntity> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent transactions', style: theme.textTheme.labelLarge),
            if (transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Nothing recorded yet.', style: theme.textTheme.bodyMedium),
              )
            else
              for (final tx in transactions) TransactionTile(transaction: tx),
          ],
        ),
      ),
    );
  }
}
