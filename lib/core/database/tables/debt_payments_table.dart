import 'package:drift/drift.dart';

import 'debts_table.dart';
// Imported so drift_dev can resolve the raw "REFERENCES transactions(id)"
// constraint text below against the real table; there is no direct Dart
// symbol reference to Transactions in this file otherwise.
// ignore: unused_import
import 'transactions_table.dart';

/// Annotates a ledger entry (`transactionId`, unique — exactly one payment
/// row per transaction) as a payment against `debtId`, split into the
/// principal and interest portions it covers. The [Transactions] row is
/// what actually moved wallet money and is what wallet-balance/cash-flow
/// math reads; this table exists so debt progress (principal paid,
/// remaining balance, payment history) can be queried without re-deriving
/// it from free-text transaction notes.
@TableIndex(name: 'idx_debt_payments_debt', columns: {#debtId})
@DataClassName('DebtPaymentRow')
class DebtPayments extends Table {
  TextColumn get id => text()();
  TextColumn get debtId =>
      text().references(Debts, #id, onDelete: KeyAction.restrict)();
  /// Exactly one payment row per ledger transaction (UNIQUE), so a
  /// transaction's debt-payment annotation can never drift out of sync
  /// with itself by having two competing rows.
  TextColumn get transactionId => text().customConstraint(
        'NOT NULL UNIQUE REFERENCES transactions(id) ON DELETE RESTRICT',
      )();

  IntColumn get amountMinor =>
      integer().customConstraint('NOT NULL CHECK (amount_minor > 0)')();
  IntColumn get principalPortionMinor => integer()
      .customConstraint('NOT NULL CHECK (principal_portion_minor >= 0)')();
  IntColumn get interestPortionMinor => integer().withDefault(const Constant(0))();

  TextColumn get paidAtLocalDate => text()();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (principal_portion_minor + interest_portion_minor = amount_minor)',
      ];
}
