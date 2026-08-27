import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/debt_providers.dart';
import '../domain/debt_entity.dart';
import 'debt_detail_screen.dart';
import 'widgets/create_debt_sheet.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(debtsProvider(null));
    return Scaffold(
      appBar: AppBar(title: const Text('Debts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => const CreateDebtSheet(),
        ),
        child: const Icon(Icons.add),
      ),
      body: debts.when(
        data: (list) => list.isEmpty
            ? const Center(child: Text('No debts yet. Tap + to add one.'))
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [for (final d in list) _DebtCard(debt: d)],
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Could not load: $error')),
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        title: Text(debt.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: debt.progressRatio),
            ),
            const SizedBox(height: 6),
            Text(
              '${debt.currentPrincipal.format()} remaining of ${debt.originalPrincipal.format()}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Text('${(debt.progressRatio * 100).toStringAsFixed(0)}%'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => DebtDetailScreen(debtId: debt.id)),
        ),
      ),
    );
  }
}
