import '../../../core/money/money.dart';
import '../../../core/utils/local_date.dart';
import 'transaction_entity.dart';
import 'transaction_type.dart';

/// Everything needed to create a new ledger entry. Deliberately has no
/// `id`/`createdAt`/`revision` — those are the repository's responsibility
/// to assign, not the caller's.
class NewTransactionInput {
  final TransactionType type;
  final String walletId;
  final String? destinationWalletId;
  final String? categoryId;
  final Money amount;
  final DateTime? occurredAt;
  final String? note;
  final String? debtId;
  final Set<String> tagIds;

  const NewTransactionInput({
    required this.type,
    required this.walletId,
    this.destinationWalletId,
    this.categoryId,
    required this.amount,
    this.occurredAt,
    this.note,
    this.debtId,
    this.tagIds = const {},
  });
}

/// Fields a user is allowed to edit after the fact. `type`, `walletId`,
/// `destinationWalletId`, and `debtId` are intentionally absent: changing
/// which wallet(s)/debt a ledger entry belongs to is modeled as delete +
/// recreate (via [TransactionRepository.deleteTransaction] followed by
/// [TransactionRepository.createTransaction]) rather than an in-place
/// move, so the balance-adjustment logic never has to reason about a
/// transaction "half migrating" between wallets.
class TransactionUpdateInput {
  final String? categoryId;
  final bool clearCategory;
  final Money? amount;
  final DateTime? occurredAt;
  final String? note;
  final bool clearNote;
  final Set<String>? tagIds;

  const TransactionUpdateInput({
    this.categoryId,
    this.clearCategory = false,
    this.amount,
    this.occurredAt,
    this.note,
    this.clearNote = false,
    this.tagIds,
  });
}

abstract interface class TransactionRepository {
  Future<TransactionEntity> createTransaction(NewTransactionInput input);

  Future<TransactionEntity> updateTransaction(String id, TransactionUpdateInput update);

  /// Soft-deletes (sets `deleted_at`) and reverses its wallet-balance
  /// effect. The row itself is retained for audit/history and future sync
  /// tombstoning.
  Future<void> deleteTransaction(String id);

  Stream<List<TransactionEntity>> watchTransactions({
    String? walletId,
    LocalDateRange? range,
    int limit = 50,
    int offset = 0,
  });

  Future<List<TransactionEntity>> getTransactionsByDateRange(
    LocalDateRange range, {
    String? walletId,
  });

  Future<Money> getMonthlyIncome(String monthKey, String currencyCode);

  Future<Money> getMonthlyExpenses(String monthKey, String currencyCode);
}
