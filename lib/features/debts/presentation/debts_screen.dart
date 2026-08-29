import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/debt_providers.dart';
import '../domain/debt_entity.dart';
import 'debt_detail_screen.dart';
import 'widgets/create_debt_sheet.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(debtsProvider(null)).value ?? const <Debt>[];
    final visible = _showArchived
        ? debts
        : debts.where((d) => d.status != DebtStatus.archived).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debts'),
        actions: [
          IconButton(
            icon: Icon(_showArchived ? Icons.visibility_off_outlined : Icons.archive_outlined),
            tooltip: _showArchived ? 'Hide archived' : 'Show archived',
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => const CreateDebtSheet(),
        ),
        child: const Icon(Icons.add),
      ),
      body: visible.isEmpty
          ? const Center(child: Text('No debts yet. Tap + to add one.'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [for (final d in visible) _DebtCard(debt: d)],
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
    final isArchived = debt.status == DebtStatus.archived;
    return Card(
      child: ListTile(
        title: Text(
          debt.name,
          style: isArchived ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
        ),
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
              '${debt.currentPrincipal.format()} remaining of ${debt.originalPrincipal.format()}'
              '${debt.status == DebtStatus.defaulted ? ' · Defaulted' : ''}',
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
