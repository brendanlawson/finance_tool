import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/local_date.dart';
import '../../transactions/data/transaction_mappers.dart';
import '../../transactions/domain/transaction_type.dart';
import '../../wallets/domain/wallet_balance_rules.dart';
import '../domain/debt_entity.dart';
import '../domain/debt_payment_entity.dart';
import '../domain/debt_repository.dart';
import 'debt_mappers.dart';

/// Drift-backed [DebtRepository]. As with transactions/wallets, every
/// write that touches more than one table (debt + linked transaction +
/// wallet balance, or debt-payment annotation + debt + wallet balance)
/// happens inside a single [AppDatabase.transaction] so those facts can
/// never be observed half-updated.
class DriftDebtRepository implements DebtRepository {
  DriftDebtRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Debt> createDebt(NewDebtInput input) {
    if (input.name.trim().isEmpty) {
      throw const ValidationFailure('Debt name cannot be empty.', field: 'name');
    }
    if (!input.originalPrincipal.isPositive) {
      throw const ValidationFailure('Principal must be greater than zero.', field: 'originalPrincipal');
    }

    return _db.transaction(() async {
      final now = utcNowMillis();
      final debtId = IdGenerator.generate();

      await _db.into(_db.debts).insert(
            DebtsCompanion.insert(
              id: debtId,
              name: input.name.trim(),
              debtType: input.type.storageValue,
              lenderOrBorrower: Value(input.counterpartyName),
              originalPrincipalMinor: input.originalPrincipal.minorUnits,
              currentPrincipalMinor: input.originalPrincipal.minorUnits,
              currencyCode: input.originalPrincipal.currencyCode,
              interestRateBps: Value(input.interestRateBps),
              interestPeriod: Value(input.interestPeriod),
              startDate: input.startDate.value,
              dueDate: Value(input.dueDate?.value),
              installmentAmountMinor: Value(input.installmentAmount?.minorUnits),
              installmentFrequency: Value(input.installmentFrequency?.storageValue),
              status: Value(DebtStatus.active.storageValue),
              notes: Value(input.notes),
              createdAt: now,
              updatedAt: now,
            ),
          );

      if (input.disbursementWalletId != null) {
        final wallet = await _requireWallet(input.disbursementWalletId!);
        if (wallet.currencyCode != input.originalPrincipal.currencyCode) {
          throw const ValidationFailure(
            'The disbursement wallet must be in the same currency as the debt.',
          );
        }
        final occurredAt = input.disbursementOccurredAt ?? fromUtcMillis(now);
        final txId = IdGenerator.generate();
        final entity = TransactionRow(
          id: txId,
          transactionType: TransactionType.debtBorrowing.storageValue,
          walletId: input.disbursementWalletId!,
          destinationWalletId: null,
          categoryId: null,
          amountMinor: input.originalPrincipal.minorUnits,
          currencyCode: input.originalPrincipal.currencyCode,
          occurredAtUtc: toUtcMillis(occurredAt),
          occurredAtLocalDate: LocalDate.fromDateTime(occurredAt).value,
          note: null,
          debtId: debtId,
          revision: 0,
          createdAt: now,
          updatedAt: now,
          deletedAt: null,
        ).toDomain(tagIds: const {});

        await _db.into(_db.transactions).insert(
              transactionInsertCompanion(
                id: txId,
                type: TransactionType.debtBorrowing,
                walletId: input.disbursementWalletId!,
                destinationWalletId: null,
                categoryId: null,
                amount: input.originalPrincipal,
                occurredAtUtc: occurredAt,
                occurredAtLocalDate: LocalDate.fromDateTime(occurredAt),
                note: null,
                debtId: debtId,
                nowMillis: now,
              ),
            );

        await _applyWalletEffect(
          WalletBalanceRules.deltaFor(entity, isAssetDebt: input.type.isAssetNotLiability),
          now,
        );
      }

      final row = await (_db.select(_db.debts)..where((d) => d.id.equals(debtId))).getSingle();
      return row.toDomain();
    }).catchError(_wrap);
  }

  @override
  Future<DebtPayment> recordPayment(RecordDebtPaymentInput input) {
    if (!input.amount.isPositive) {
      throw const ValidationFailure('Payment amount must be greater than zero.', field: 'amount');
    }
    if (input.principalPortion.isNegative || input.principalPortion > input.amount) {
      throw const ValidationFailure(
        'Principal portion must be between zero and the payment amount.',
        field: 'principalPortion',
      );
    }

    return _db.transaction(() async {
      final debt = await _requireDebt(input.debtId);
      if (debt.currentPrincipalMinor <= 0) {
        throw const ValidationFailure('This debt is already fully paid off.');
      }
      final wallet = await _requireWallet(input.walletId);
      if (wallet.currencyCode != debt.currencyCode) {
        throw const ValidationFailure('The wallet must be in the same currency as the debt.');
      }

      final now = utcNowMillis();
      final occurredAt = input.paidAt ?? fromUtcMillis(now);
      final isAssetDebt =
          DebtTypeStorage.fromStorage(debt.debtType).isAssetNotLiability;
      final interestPortion = input.amount - input.principalPortion;

      final txId = IdGenerator.generate();
      await _db.into(_db.transactions).insert(
            transactionInsertCompanion(
              id: txId,
              type: TransactionType.debtPayment,
              walletId: input.walletId,
              destinationWalletId: null,
              categoryId: null,
              amount: input.amount,
              occurredAtUtc: occurredAt,
              occurredAtLocalDate: LocalDate.fromDateTime(occurredAt),
              note: input.note,
              debtId: input.debtId,
              nowMillis: now,
            ),
          );

      final txEntity = TransactionRow(
        id: txId,
        transactionType: TransactionType.debtPayment.storageValue,
        walletId: input.walletId,
        destinationWalletId: null,
        categoryId: null,
        amountMinor: input.amount.minorUnits,
        currencyCode: input.amount.currencyCode,
        occurredAtUtc: toUtcMillis(occurredAt),
        occurredAtLocalDate: LocalDate.fromDateTime(occurredAt).value,
        note: input.note,
        debtId: input.debtId,
        revision: 0,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      ).toDomain(tagIds: const {});
      await _applyWalletEffect(
        WalletBalanceRules.deltaFor(txEntity, isAssetDebt: isAssetDebt),
        now,
      );

      final paymentId = IdGenerator.generate();
      await _db.into(_db.debtPayments).insert(
            DebtPaymentsCompanion.insert(
              id: paymentId,
              debtId: input.debtId,
              transactionId: txId,
              amountMinor: input.amount.minorUnits,
              principalPortionMinor: input.principalPortion.minorUnits,
              interestPortionMinor: Value(interestPortion.minorUnits),
              paidAtLocalDate: LocalDate.fromDateTime(occurredAt).value,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Overpayment (§26): floor the cached remaining balance at zero
      // rather than letting it go negative — see the Debts table doc for
      // why the surplus is not tracked as a reverse balance.
      final rawRemaining = debt.currentPrincipalMinor - input.principalPortion.minorUnits;
      final newRemaining = rawRemaining < 0 ? 0 : rawRemaining;
      await (_db.update(_db.debts)..where((d) => d.id.equals(input.debtId))).write(
        DebtsCompanion(
          currentPrincipalMinor: Value(newRemaining),
          status: Value(newRemaining == 0 ? DebtStatus.paidOff.storageValue : debt.status),
          revision: Value(debt.revision + 1),
          updatedAt: Value(now),
        ),
      );

      return (await (_db.select(_db.debtPayments)..where((p) => p.id.equals(paymentId)))
              .getSingle())
          .toDomain(debt.currencyCode);
    }).catchError(_wrap);
  }

  @override
  Future<void> deletePayment(String paymentId) {
    return _db.transaction(() async {
      final payment = await (_db.select(_db.debtPayments)..where((p) => p.id.equals(paymentId)))
          .getSingleOrNull();
      if (payment == null) {
        throw NotFoundFailure('Debt payment $paymentId does not exist.');
      }
      final debt = await _requireDebt(payment.debtId);
      final txRow = await (_db.select(_db.transactions)
            ..where((t) => t.id.equals(payment.transactionId)))
          .getSingleOrNull();
      if (txRow == null || txRow.deletedAt != null) {
        throw const DatabaseFailure(
          'The transaction linked to this payment is missing or already removed.',
        );
      }

      final now = utcNowMillis();
      final isAssetDebt = DebtTypeStorage.fromStorage(debt.debtType).isAssetNotLiability;
      final entity = txRow.toDomain(tagIds: const {});

      await (_db.update(_db.transactions)..where((t) => t.id.equals(txRow.id))).write(
        TransactionsCompanion(
          deletedAt: Value(now),
          revision: Value(txRow.revision + 1),
          updatedAt: Value(now),
        ),
      );
      await _applyWalletEffect(
        WalletBalanceRules.reversalFor(entity, isAssetDebt: isAssetDebt),
        now,
      );
      await (_db.delete(_db.debtPayments)..where((p) => p.id.equals(paymentId))).go();

      // Recomputed from the remaining ledger rather than "add
      // principalPortion back", because if this payment had previously
      // been clamped by the overpayment rule, its principal portion
      // no longer corresponds 1:1 to how much it actually reduced the
      // cached balance — recomputing from what's left is unambiguous
      // either way (mirrors WalletRepository.recomputeBalance).
      final remainingPayments = await (_db.select(_db.debtPayments)
            ..where((p) => p.debtId.equals(debt.id)))
          .get();
      final paidSoFar = remainingPayments.fold<int>(0, (sum, p) => sum + p.principalPortionMinor);
      final rawRemaining = debt.originalPrincipalMinor - paidSoFar;
      final newRemaining = rawRemaining < 0 ? 0 : rawRemaining;
      final newStatus = newRemaining > 0 && debt.status == DebtStatus.paidOff.storageValue
          ? DebtStatus.active.storageValue
          : debt.status;

      await (_db.update(_db.debts)..where((d) => d.id.equals(debt.id))).write(
        DebtsCompanion(
          currentPrincipalMinor: Value(newRemaining),
          status: Value(newStatus),
          revision: Value(debt.revision + 1),
          updatedAt: Value(now),
        ),
      );
    }).catchError(_wrap);
  }

  @override
  Future<void> setStatus(String debtId, DebtStatus status) async {
    final debt = await _requireDebt(debtId);
    await (_db.update(_db.debts)..where((d) => d.id.equals(debtId))).write(
      DebtsCompanion(
        status: Value(status.storageValue),
        revision: Value(debt.revision + 1),
        updatedAt: Value(utcNowMillis()),
      ),
    );
  }

  @override
  Future<Money> getRemainingBalance(String debtId) async {
    final debt = await _requireDebt(debtId);
    return Money(minorUnits: debt.currentPrincipalMinor, currencyCode: debt.currencyCode);
  }

  @override
  Stream<Debt?> watchDebt(String debtId) {
    return (_db.select(_db.debts)..where((d) => d.id.equals(debtId)))
        .watchSingleOrNull()
        .map((row) => row?.toDomain());
  }

  @override
  Stream<List<Debt>> watchDebts({DebtStatus? status}) {
    final query = _db.select(_db.debts)..orderBy([(d) => OrderingTerm.asc(d.createdAt)]);
    if (status != null) {
      query.where((d) => d.status.equals(status.storageValue));
    }
    return query.watch().map((rows) => rows.map((r) => r.toDomain()).toList(growable: false));
  }

  @override
  Stream<List<DebtPayment>> watchDebtPayments(String debtId) {
    return (_db.select(_db.debtPayments)
          ..where((p) => p.debtId.equals(debtId))
          ..orderBy([(p) => OrderingTerm.desc(p.paidAtLocalDate)]))
        .watch()
        .asyncMap((rows) async {
      if (rows.isEmpty) return const <DebtPayment>[];
      final debt = await _requireDebt(debtId);
      return rows.map((r) => r.toDomain(debt.currencyCode)).toList(growable: false);
    });
  }

  // -- helpers --------------------------------------------------------

  Future<DebtRow> _requireDebt(String id) async {
    final row = await (_db.select(_db.debts)..where((d) => d.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw NotFoundFailure('Debt $id does not exist.');
    }
    return row;
  }

  Future<WalletRow> _requireWallet(String id) async {
    final row = await (_db.select(_db.wallets)..where((w) => w.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw NotFoundFailure('Wallet $id does not exist.');
    }
    return row;
  }

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

  Never _wrap(Object error, StackTrace stackTrace) {
    if (error is AppFailure) throw error;
    throw wrapUnexpectedDatabaseError(error, stackTrace);
  }
}
