import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/local_date.dart';
import '../../wallets/domain/wallet_balance_rules.dart';
import '../domain/transaction_entity.dart';
import '../domain/transaction_repository.dart';
import '../domain/transaction_type.dart';
import 'transaction_mappers.dart';

/// Drift-backed [TransactionRepository]. This is the only place that
/// writes to `transactions.amount_minor`/`wallets.current_balance_minor`
/// together — every write here happens inside [AppDatabase.transaction],
/// so a crash or thrown error midway leaves the ledger and the cached
/// wallet balance either both-old or both-new, never split.
///
/// Debt-linked rows (`debt_payment`/`debt_borrowing`) are out of scope for
/// [createTransaction]/[deleteTransaction] on purpose — see the
/// [ValidationFailure] thrown below. Creating one of those without also
/// updating the linked Debt's cached principal is exactly the kind of
/// "two sources of truth that can diverge" §6 warns against, so that path
/// only exists on DebtRepository, which updates both in one transaction.
class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository(this._db);

  final AppDatabase _db;

  @override
  Future<TransactionEntity> createTransaction(NewTransactionInput input) async {
    _rejectDebtLinkedType(input.type);
    if (input.type == TransactionType.transfer) {
      if (input.destinationWalletId == null) {
        throw const ValidationFailure(
          'A transfer needs a destination wallet.',
          field: 'destinationWalletId',
        );
      }
      if (input.destinationWalletId == input.walletId) {
        throw const ValidationFailure(
          'Transferring to the same wallet is not allowed — pick two different wallets.',
          field: 'destinationWalletId',
        );
      }
    } else if (input.destinationWalletId != null) {
      throw const ValidationFailure(
        'Only a transfer can have a destination wallet.',
        field: 'destinationWalletId',
      );
    }
    _validateAmountSign(input.type, input.amount);

    return _db.transaction(() async {
      final sourceWallet = await _requireWallet(input.walletId);
      _requireMatchingCurrency(sourceWallet, input.amount);

      WalletRow? destinationWallet;
      if (input.destinationWalletId != null) {
        destinationWallet = await _requireWallet(input.destinationWalletId!);
        if (destinationWallet.currencyCode != input.amount.currencyCode) {
          throw const ValidationFailure(
            'Transferring between wallets with different currencies needs an '
            'exchange rate, which this app does not perform automatically.',
          );
        }
      }

      final now = utcNowMillis();
      final id = IdGenerator.generate();
      final occurredAt = input.occurredAt ?? fromUtcMillis(now);

      final entity = TransactionEntity(
        id: id,
        type: input.type,
        walletId: input.walletId,
        destinationWalletId: input.destinationWalletId,
        categoryId: input.categoryId,
        amount: input.amount,
        occurredAtUtc: occurredAt,
        occurredAtLocalDate: LocalDate.fromDateTime(occurredAt),
        note: input.note,
        debtId: null,
        tagIds: input.tagIds,
        revision: 0,
        createdAt: fromUtcMillis(now),
        updatedAt: fromUtcMillis(now),
        deletedAt: null,
      );

      await _db.into(_db.transactions).insert(
            transactionInsertCompanion(
              id: id,
              type: input.type,
              walletId: input.walletId,
              destinationWalletId: input.destinationWalletId,
              categoryId: input.categoryId,
              amount: input.amount,
              occurredAtUtc: occurredAt,
              occurredAtLocalDate: entity.occurredAtLocalDate,
              note: input.note,
              debtId: null,
              nowMillis: now,
            ),
          );

      await _replaceTags(id, input.tagIds);
      await _applyWalletEffect(WalletBalanceRules.deltaFor(entity), now);

      return entity;
    }).catchError(_wrapDatabaseError);
  }

  @override
  Future<TransactionEntity> updateTransaction(String id, TransactionUpdateInput update) {
    return _db.transaction(() async {
      final existing = await _requireTransactionRow(id);
      if (existing.transactionType == TransactionType.debtPayment.storageValue ||
          existing.transactionType == TransactionType.debtBorrowing.storageValue) {
        throw const ValidationFailure(
          'Debt-linked transactions are edited from the debt they belong to.',
        );
      }

      final type = TransactionTypeStorage.fromStorage(existing.transactionType);
      final newAmount = update.amount ?? Money(
            minorUnits: existing.amountMinor,
            currencyCode: existing.currencyCode,
          );
      if (update.amount != null) {
        _validateAmountSign(type, newAmount);
        final wallet = await _requireWallet(existing.walletId);
        _requireMatchingCurrency(wallet, newAmount);
      }

      final now = utcNowMillis();
      final oldEntity = existing.toDomain(tagIds: const {});
      final newOccurredAtUtc = update.occurredAt ?? oldEntity.occurredAtUtc;

      final categoryValue = update.clearCategory
          ? const Value<String?>(null)
          : (update.categoryId != null
              ? Value<String?>(update.categoryId)
              : const Value<String?>.absent());
      final noteValue = update.clearNote
          ? const Value<String?>(null)
          : (update.note != null
              ? Value<String?>(update.note)
              : const Value<String?>.absent());

      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          categoryId: categoryValue,
          amountMinor: Value(newAmount.minorUnits),
          occurredAtUtc: Value(toUtcMillis(newOccurredAtUtc)),
          occurredAtLocalDate: Value(LocalDate.fromDateTime(newOccurredAtUtc).value),
          note: noteValue,
          revision: Value(existing.revision + 1),
          updatedAt: Value(now),
        ),
      );

      if (update.tagIds != null) {
        await _replaceTags(id, update.tagIds!);
      }

      if (update.amount != null) {
        final reversal = WalletBalanceRules.reversalFor(oldEntity);
        final newEntity = oldEntity.copyWith(amount: newAmount);
        final forward = WalletBalanceRules.deltaFor(newEntity);
        await _applyWalletEffect(_combine(reversal, forward), now);
      }

      final refreshed = await _requireTransactionRow(id);
      final tagIds = await _tagIdsFor(id);
      return refreshed.toDomain(tagIds: tagIds);
    }).catchError(_wrapDatabaseError);
  }

  @override
  Future<void> deleteTransaction(String id) {
    return _db.transaction(() async {
      final existing = await _requireTransactionRow(id);
      if (existing.transactionType == TransactionType.debtPayment.storageValue ||
          existing.transactionType == TransactionType.debtBorrowing.storageValue) {
        throw const ValidationFailure(
          'Debt-linked transactions are deleted from the debt they belong to.',
        );
      }

      final now = utcNowMillis();
      final entity = existing.toDomain(tagIds: const {});

      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          deletedAt: Value(now),
          revision: Value(existing.revision + 1),
          updatedAt: Value(now),
        ),
      );

      await _applyWalletEffect(WalletBalanceRules.reversalFor(entity), now);
    }).catchError(_wrapDatabaseError);
  }

  @override
  Stream<List<TransactionEntity>> watchTransactions({
    String? walletId,
    LocalDateRange? range,
    String? searchText,
    int limit = 50,
    int offset = 0,
  }) {
    final query = _db.select(_db.transactions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.desc(t.occurredAtLocalDate),
        (t) => OrderingTerm.desc(t.occurredAtUtc),
      ])
      ..limit(limit, offset: offset);
    if (walletId != null) {
      query.where((t) => t.walletId.equals(walletId));
    }
    if (range != null) {
      query.where((t) =>
          t.occurredAtLocalDate.isBiggerOrEqualValue(range.start.value) &
          t.occurredAtLocalDate.isSmallerOrEqualValue(range.end.value));
    }
    final trimmedSearch = searchText?.trim();
    if (trimmedSearch != null && trimmedSearch.isNotEmpty) {
      // SQLite's LIKE is case-insensitive for ASCII by default, which is
      // enough for a simple note search — no need for a separate
      // lower()/collate dance.
      query.where((t) => t.note.like('%$trimmedSearch%'));
    }
    return query.watch().asyncMap(_withTags);
  }

  @override
  Future<List<TransactionEntity>> getTransactionsByDateRange(
    LocalDateRange range, {
    String? walletId,
  }) async {
    final query = _db.select(_db.transactions)
      ..where((t) =>
          t.deletedAt.isNull() &
          t.occurredAtLocalDate.isBiggerOrEqualValue(range.start.value) &
          t.occurredAtLocalDate.isSmallerOrEqualValue(range.end.value))
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAtLocalDate)]);
    if (walletId != null) {
      query.where((t) => t.walletId.equals(walletId));
    }
    final rows = await query.get();
    return _withTags(rows);
  }

  @override
  Future<Money> getMonthlyIncome(String monthKey, String currencyCode) =>
      _monthlyTotal(monthKey, currencyCode, TransactionType.income);

  @override
  Future<Money> getMonthlyExpenses(String monthKey, String currencyCode) =>
      _monthlyTotal(monthKey, currencyCode, TransactionType.expense);

  Future<Money> _monthlyTotal(String monthKey, String currencyCode, TransactionType type) async {
    final range = LocalDateRange.forMonthKey(monthKey);
    final sumExpr = _db.transactions.amountMinor.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([sumExpr])
      ..where(_db.transactions.deletedAt.isNull() &
          _db.transactions.transactionType.equals(type.storageValue) &
          _db.transactions.currencyCode.equals(currencyCode) &
          _db.transactions.occurredAtLocalDate.isBiggerOrEqualValue(range.start.value) &
          _db.transactions.occurredAtLocalDate.isSmallerOrEqualValue(range.end.value));
    final row = await query.getSingle();
    final total = row.read(sumExpr) ?? 0;
    return Money(minorUnits: total, currencyCode: currencyCode);
  }

  // -- helpers --------------------------------------------------------

  void _rejectDebtLinkedType(TransactionType type) {
    if (type == TransactionType.debtPayment || type == TransactionType.debtBorrowing) {
      throw const ValidationFailure(
        'Debt-linked transactions must be created through the Debts feature '
        'so the debt\'s remaining balance stays in sync.',
      );
    }
  }

  void _validateAmountSign(TransactionType type, Money amount) {
    if (type == TransactionType.adjustment) {
      if (amount.isZero) {
        throw const ValidationFailure('An adjustment cannot be zero.', field: 'amount');
      }
    } else if (!amount.isPositive) {
      throw const ValidationFailure('Amount must be greater than zero.', field: 'amount');
    }
  }

  Future<WalletRow> _requireWallet(String id) async {
    final wallet =
        await (_db.select(_db.wallets)..where((w) => w.id.equals(id))).getSingleOrNull();
    if (wallet == null) {
      throw NotFoundFailure('Wallet $id does not exist.');
    }
    return wallet;
  }

  void _requireMatchingCurrency(WalletRow wallet, Money amount) {
    if (wallet.currencyCode != amount.currencyCode) {
      throw ValidationFailure(
        'This wallet is in ${wallet.currencyCode}, not ${amount.currencyCode}.',
        field: 'amount',
      );
    }
  }

  Future<TransactionRow> _requireTransactionRow(String id) async {
    final row = await (_db.select(_db.transactions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null || row.deletedAt != null) {
      throw NotFoundFailure('Transaction $id does not exist.');
    }
    return row;
  }

  Future<void> _replaceTags(String transactionId, Set<String> tagIds) async {
    await (_db.delete(_db.transactionTags)
          ..where((t) => t.transactionId.equals(transactionId)))
        .go();
    for (final tagId in tagIds) {
      await _db.into(_db.transactionTags).insert(
            TransactionTagsCompanion.insert(transactionId: transactionId, tagId: tagId),
          );
    }
  }

  Future<Set<String>> _tagIdsFor(String transactionId) async {
    final rows = await (_db.select(_db.transactionTags)
          ..where((t) => t.transactionId.equals(transactionId)))
        .get();
    return rows.map((r) => r.tagId).toSet();
  }

  Future<List<TransactionEntity>> _withTags(List<TransactionRow> rows) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r.id).toList();
    final joinRows = await (_db.select(_db.transactionTags)
          ..where((t) => t.transactionId.isIn(ids)))
        .get();
    final tagsByTransaction = <String, Set<String>>{};
    for (final join in joinRows) {
      (tagsByTransaction[join.transactionId] ??= {}).add(join.tagId);
    }
    return rows
        .map((r) => r.toDomain(tagIds: tagsByTransaction[r.id] ?? const {}))
        .toList(growable: false);
  }

  /// Applies a wallet-balance effect (possibly touching several wallets,
  /// e.g. both legs of a transfer) as read-modify-write updates within the
  /// caller's already-open [AppDatabase.transaction].
  Future<void> _applyWalletEffect(WalletBalanceEffect effect, int nowMillis) async {
    for (final entry in effect.walletDeltas.entries) {
      final wallet = await _requireWallet(entry.key);
      final newBalance = wallet.currentBalanceMinor + entry.value.minorUnits;
      await (_db.update(_db.wallets)..where((w) => w.id.equals(wallet.id))).write(
        WalletsCompanion(
          currentBalanceMinor: Value(newBalance),
          revision: Value(wallet.revision + 1),
          updatedAt: Value(nowMillis),
        ),
      );
    }
  }

  WalletBalanceEffect _combine(WalletBalanceEffect a, WalletBalanceEffect b) {
    final combined = <String, Money>{...a.walletDeltas};
    for (final entry in b.walletDeltas.entries) {
      final existing = combined[entry.key];
      combined[entry.key] = existing == null ? entry.value : existing + entry.value;
    }
    return WalletBalanceEffect(combined);
  }

  Never _wrapDatabaseError(Object error, StackTrace stackTrace) {
    if (error is AppFailure) throw error;
    throw wrapUnexpectedDatabaseError(error, stackTrace);
  }
}
