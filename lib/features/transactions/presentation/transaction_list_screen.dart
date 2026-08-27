import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wallets/application/wallet_providers.dart';
import '../application/transaction_providers.dart';
import '../domain/transaction_entity.dart';
import 'widgets/transaction_tile.dart';

const _pageSize = 200;

/// A reactive, paginated view of the ledger, optionally filtered by
/// wallet. §19 asks that a large history not be loaded into memory
/// wholesale — this screen honors that by only ever asking for
/// [_limit] rows (growing in [_pageSize] steps via "Load more" rather
/// than fetching everything up front).
class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  String? _walletFilter;
  int _limit = _pageSize;

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsProvider).value ?? const [];
    final query = TransactionQuery(walletId: _walletFilter, limit: _limit);
    final transactions = ref.watch(transactionsProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() {
              _walletFilter = value;
              _limit = _pageSize;
            }),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('All wallets')),
              for (final w in wallets) PopupMenuItem(value: w.id, child: Text(w.name)),
            ],
          ),
        ],
      ),
      body: transactions.when(
        data: (list) => _TransactionList(
          transactions: list,
          hasMore: list.length >= _limit,
          onLoadMore: () => setState(() => _limit += _pageSize),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Could not load: $error')),
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({
    required this.transactions,
    required this.hasMore,
    required this.onLoadMore,
  });

  final List<TransactionEntity> transactions;
  final bool hasMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(child: Text('No transactions yet.'));
    }
    return ListView.separated(
      itemCount: transactions.length + (hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= transactions.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: TextButton(onPressed: onLoadMore, child: const Text('Load more')),
            ),
          );
        }
        return TransactionTile(transaction: transactions[index]);
      },
    );
  }
}
