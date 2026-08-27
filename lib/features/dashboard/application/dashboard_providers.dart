import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/local_date.dart';
import '../../debts/application/debt_providers.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../transactions/domain/transaction_type.dart';
import '../../wallets/application/wallet_providers.dart';
import '../domain/monthly_report.dart';
import '../domain/net_worth.dart';

/// Net worth, combined reactively from the wallets and debts streams that
/// already exist for their own screens — no separate database query and
/// no manual invalidation. Riverpod re-runs this provider whenever either
/// upstream stream emits, which happens whenever Drift notices a write to
/// the `wallets` or `debts` tables (§8/§20).
final netWorthProvider = Provider<AsyncValue<NetWorth>>((ref) {
  final wallets = ref.watch(walletsProvider);
  final debts = ref.watch(debtsProvider(null));

  if (wallets.hasError) return AsyncValue.error(wallets.error!, wallets.stackTrace!);
  if (debts.hasError) return AsyncValue.error(debts.error!, debts.stackTrace!);
  final walletList = wallets.value;
  final debtList = debts.value;
  if (walletList == null || debtList == null) return const AsyncValue.loading();

  return AsyncValue.data(NetWorth.compute(wallets: walletList, debts: debtList));
});

/// All (non-deleted) transactions in the current calendar month, in the
/// caller's local timezone at the moment this provider is evaluated. This
/// is the one shared reactive source both [monthlyCashFlowProvider] and
/// [monthlyCategoryBreakdownProvider] derive from, so a single new
/// transaction only triggers one underlying SQL query, not two.
final currentMonthTransactionsProvider = StreamProvider<List<TransactionEntity>>((ref) {
  final range = LocalDateRange.forMonth(DateTime.now().year, DateTime.now().month);
  return ref.watch(transactionRepositoryProvider).watchTransactions(
        range: range,
        limit: 10000,
      );
});

final monthlyCashFlowProvider =
    Provider.family<AsyncValue<MonthlyCashFlow>, String>((ref, currencyCode) {
  final transactions = ref.watch(currentMonthTransactionsProvider);
  return transactions.whenData((list) => MonthlyCashFlow.compute(list, currencyCode));
});

final monthlyCategoryBreakdownProvider =
    Provider.family<AsyncValue<List<CategoryBreakdownEntry>>, ({String currencyCode, TransactionType type})>(
        (ref, args) {
  final transactions = ref.watch(currentMonthTransactionsProvider);
  return transactions.whenData(
    (list) => computeCategoryBreakdown(list, args.currencyCode, type: args.type),
  );
});

final recentTransactionsProvider = StreamProvider<List<TransactionEntity>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchTransactions(limit: 8);
});
