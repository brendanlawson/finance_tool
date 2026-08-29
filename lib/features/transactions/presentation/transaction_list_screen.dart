import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/local_date.dart';
import '../../wallets/application/wallet_providers.dart';
import '../application/transaction_providers.dart';
import '../domain/transaction_entity.dart';
import 'widgets/transaction_tile.dart';

const _pageSize = 200;

/// A reactive, paginated view of the ledger — filterable by wallet, date
/// range, and note text (§2.1 lists "search transaction history" as a
/// core, must-work-offline operation). §19 asks that a large history not
/// be loaded into memory wholesale — this screen honors that by only ever
/// asking for [_limit] rows (growing via "Load more") and by running
/// search/date filters as real database queries, not a client-side scan
/// of an already-fetched page.
class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  String? _walletFilter;
  LocalDateRange? _dateFilter;
  int _limit = _pageSize;
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetPaging() => setState(() => _limit = _pageSize);

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _dateFilter == null
          ? null
          : DateTimeRange(start: _dateFilter!.start.toDateTime(), end: _dateFilter!.end.toDateTime()),
      initialEntryMode: DatePickerEntryMode.calendar,
      currentDate: now,
    );
    if (picked == null) return;
    setState(() {
      _dateFilter = LocalDateRange(
        start: LocalDate.fromDateTime(picked.start),
        end: LocalDate.fromDateTime(picked.end),
      );
      _limit = _pageSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsProvider).value ?? const [];
    final query = TransactionQuery(
      walletId: _walletFilter,
      range: _dateFilter,
      searchText: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      limit: _limit,
    );
    final transactions = ref.watch(transactionsProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search notes…',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(_resetPaging),
              )
            : const Text('Transactions'),
        leading: _searching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _searching = false;
                  _searchController.clear();
                  _resetPaging();
                }),
              )
            : null,
        actions: [
          if (!_searching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
          IconButton(
            icon: Icon(_dateFilter == null ? Icons.date_range_outlined : Icons.date_range),
            tooltip: 'Filter by date',
            onPressed: _pickDateRange,
          ),
          if (_dateFilter != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear date filter',
              onPressed: () => setState(() {
                _dateFilter = null;
                _resetPaging();
              }),
            ),
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by wallet',
            onSelected: (value) => setState(() {
              _walletFilter = value;
              _resetPaging();
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
          isFiltered: _walletFilter != null || _dateFilter != null || query.searchText != null,
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
    required this.isFiltered,
  });

  final List<TransactionEntity> transactions;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(child: Text(isFiltered ? 'No transactions match.' : 'No transactions yet.'));
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
