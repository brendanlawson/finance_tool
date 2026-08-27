import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wallets/application/wallet_providers.dart';
import '../application/transaction_providers.dart';
import '../domain/transaction_entity.dart';
import 'widgets/transaction_tile.dart';

/// A single reactive page of recent transactions, optionally filtered by
/// wallet. §19 asks that a large ledger not be loaded into memory wholesale
/// — this screen honors that with a bounded page size rather than
/// streaming the entire table; going further with infinite-scroll
/// pagination is left as a follow-on (see the roadmap), not because it is
/// unimportant but because a single bounded page is already enough to
/// prove the reactive pipeline end to end.
class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  String? _walletFilter;

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsProvider).value ?? const [];
    final query = TransactionQuery(walletId: _walletFilter, limit: 200);
    final transactions = ref.watch(transactionsProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _walletFilter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('All wallets')),
              for (final w in wallets) PopupMenuItem(value: w.id, child: Text(w.name)),
            ],
          ),
        ],
      ),
      body: transactions.when(
        data: (list) => _TransactionList(transactions: list),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Could not load: $error')),
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.transactions});

  final List<TransactionEntity> transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(child: Text('No transactions yet.'));
    }
    return ListView.separated(
      itemCount: transactions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) => TransactionTile(transaction: transactions[index]),
    );
  }
}
