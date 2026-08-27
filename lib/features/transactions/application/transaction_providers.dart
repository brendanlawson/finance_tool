import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/utils/local_date.dart';
import '../data/drift_tag_repository.dart';
import '../data/drift_transaction_repository.dart';
import '../domain/tag_entity.dart';
import '../domain/tag_repository.dart';
import '../domain/transaction_entity.dart';
import '../domain/transaction_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return DriftTransactionRepository(ref.watch(appDatabaseProvider));
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return DriftTagRepository(ref.watch(appDatabaseProvider));
});

final tagsProvider = StreamProvider<List<Tag>>((ref) {
  return ref.watch(tagRepositoryProvider).watchTags();
});

class TransactionQuery {
  final String? walletId;
  final LocalDateRange? range;
  final int limit;
  final int offset;

  const TransactionQuery({this.walletId, this.range, this.limit = 50, this.offset = 0});

  @override
  bool operator ==(Object other) =>
      other is TransactionQuery &&
      other.walletId == walletId &&
      other.range?.start.value == range?.start.value &&
      other.range?.end.value == range?.end.value &&
      other.limit == limit &&
      other.offset == offset;

  @override
  int get hashCode =>
      Object.hash(walletId, range?.start.value, range?.end.value, limit, offset);
}

/// Recomputes (re-runs its SQL query) whenever any write touches the
/// `transactions` table — a create/update/delete anywhere in the app, not
/// just from whatever screen is showing this particular list. See §20:
/// this is the whole reason repositories return `Stream`s instead of
/// one-shot `Future`s for anything the UI displays live.
final transactionsProvider =
    StreamProvider.family<List<TransactionEntity>, TransactionQuery>((ref, query) {
  return ref.watch(transactionRepositoryProvider).watchTransactions(
        walletId: query.walletId,
        range: query.range,
        limit: query.limit,
        offset: query.offset,
      );
});
