import 'package:drift/drift.dart';

/// `currentPrincipalMinor` is, like `wallets.currentBalanceMinor`, a
/// materialized cache — the authoritative history is the append-only
/// [DebtPayments] table (each row FK'd 1:1 to the [Transactions] row that
/// actually moved money). It is only ever written inside the same DB
/// transaction as a debt_payment/debt_borrowing ledger entry — see
/// lib/features/debts/data/drift_debt_repository.dart.
///
/// Overpayment (§26): a payment that would drive the remaining balance
/// below zero is accepted (the money really did leave the wallet — the
/// ledger must reflect that), but `currentPrincipalMinor` floors at 0 and
/// `status` flips to 'paid_off'. The surplus is not tracked as a negative
/// principal/"they owe you" balance; that is a deliberate V1 scope
/// decision, documented on [DebtRepository.recordPayment].
@TableIndex(name: 'idx_debts_status', columns: {#status})
@DataClassName('DebtRow')
class Debts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// personal_loan, online_loan, credit_loan, borrowed_from_person,
  /// lent_to_person.
  TextColumn get debtType => text().customConstraint(
        "NOT NULL CHECK (debt_type IN ('personal_loan', 'online_loan', "
        "'credit_loan', 'borrowed_from_person', 'lent_to_person'))",
      )();

  /// Free-text name of the counterparty (bank, app, or person).
  TextColumn get lenderOrBorrower => text().nullable()();

  IntColumn get originalPrincipalMinor =>
      integer().customConstraint('NOT NULL CHECK (original_principal_minor > 0)')();
  IntColumn get currentPrincipalMinor =>
      integer().customConstraint('NOT NULL CHECK (current_principal_minor >= 0)')();

  TextColumn get currencyCode =>
      text().customConstraint('NOT NULL CHECK (length(currency_code) = 3)')();

  /// Basis points (150 = 1.50%). Reference/informational only in V1 — the
  /// app does not auto-accrue interest; see the roadmap for that as a
  /// later phase.
  IntColumn get interestRateBps => integer().nullable()();
  TextColumn get interestPeriod => text().nullable().customConstraint(
        "CHECK (interest_period IS NULL OR interest_period IN ('monthly', 'yearly'))",
      )();

  TextColumn get startDate => text()();
  TextColumn get dueDate => text().nullable()();

  IntColumn get installmentAmountMinor => integer().nullable().customConstraint(
        'CHECK (installment_amount_minor IS NULL OR installment_amount_minor > 0)',
      )();
  TextColumn get installmentFrequency => text().nullable().customConstraint(
        "CHECK (installment_frequency IS NULL OR installment_frequency IN "
        "('weekly', 'biweekly', 'monthly', 'custom'))",
      )();

  TextColumn get status => text().customConstraint(
        "NOT NULL CHECK (status IN ('active', 'paid_off', 'defaulted', 'archived')) "
        "DEFAULT 'active'",
      )();

  TextColumn get notes => text().nullable()();

  IntColumn get revision => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
