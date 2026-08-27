import 'package:drift/drift.dart';

import 'categories_table.dart';
import 'debts_table.dart';
import 'wallets_table.dart';

/// The financial ledger. Every wallet balance and every dashboard figure is
/// derived from this table — see WalletRepository/DashboardRepository for
/// the aggregation rules. Key modeling decisions, in one place:
///
/// * `amountMinor` is always a positive magnitude, never signed. Direction
///   (does this increase or decrease `walletId`'s balance?) is determined
///   by `transactionType`, *except* for `adjustment`, which is the one type
///   that has no natural direction of its own and is allowed to be
///   negative — see the CHECK constraint below and
///   `WalletBalanceRules.deltaFor` in
///   lib/features/wallets/domain/wallet_balance_rules.dart, which is the
///   single place that formula is allowed to live.
/// * `occurredAtLocalDate` (not a timezone conversion of `occurredAtUtc` at
///   query time) is what monthly reports group by — see
///   lib/core/utils/local_date.dart for why.
/// * Soft delete (`deletedAt`) rather than hard delete preserves ledger
///   history/auditability and leaves room for future sync tombstones.
@TableIndex(name: 'idx_tx_wallet_date', columns: {#walletId, #occurredAtLocalDate})
@TableIndex(name: 'idx_tx_category', columns: {#categoryId})
@TableIndex(name: 'idx_tx_debt', columns: {#debtId})
@TableIndex.sql(
  'CREATE INDEX idx_tx_month ON transactions(occurred_at_local_date) '
  'WHERE deleted_at IS NULL',
)
@DataClassName('TransactionRow')
class Transactions extends Table {
  TextColumn get id => text()();

  /// One of: income, expense, transfer, debt_payment, debt_borrowing,
  /// adjustment.
  TextColumn get transactionType => text().customConstraint(
        "NOT NULL CHECK (transaction_type IN "
        "('income', 'expense', 'transfer', 'debt_payment', "
        "'debt_borrowing', 'adjustment'))",
      )();

  // Both columns reference Wallets; @ReferenceName disambiguates the two
  // reverse-reference sets drift_dev's Manager API would otherwise both
  // try to name `transactionsRefs`.
  @ReferenceName('outgoingTransactions')
  TextColumn get walletId =>
      text().references(Wallets, #id, onDelete: KeyAction.restrict)();

  /// Only set (and only meaningful) when `transactionType = 'transfer'`.
  @ReferenceName('incomingTransferTransactions')
  TextColumn get destinationWalletId => text().nullable().references(
        Wallets,
        #id,
        onDelete: KeyAction.restrict,
      )();

  TextColumn get categoryId => text().nullable().references(
        Categories,
        #id,
        onDelete: KeyAction.restrict,
      )();

  /// Positive magnitude. See class doc for the sign/direction rule.
  IntColumn get amountMinor => integer()();

  TextColumn get currencyCode =>
      text().customConstraint('NOT NULL CHECK (length(currency_code) = 3)')();

  IntColumn get occurredAtUtc => integer()();
  TextColumn get occurredAtLocalDate => text()();

  TextColumn get note => text().nullable()();

  /// Set iff `transactionType` is `debt_payment` or `debt_borrowing`; see
  /// the CHECK constraint below.
  TextColumn get debtId =>
      text().nullable().references(Debts, #id, onDelete: KeyAction.restrict)();

  IntColumn get revision => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        // Every type carries a positive magnitude except 'adjustment',
        // which has no type-implied direction and may be negative (to
        // correct a balance downward) but never zero.
        "CHECK ("
            "(transaction_type = 'adjustment' AND amount_minor <> 0) OR "
            "(transaction_type <> 'adjustment' AND amount_minor > 0)"
            ")",
        // A transfer must name a different wallet to move money into;
        // every other type must not set one. This is the DB-level backstop
        // for the "same-wallet transfer" and "transfer miscategorized as
        // income/expense" edge cases (§26/§7).
        "CHECK ("
            "(transaction_type = 'transfer' AND destination_wallet_id IS NOT NULL "
            "AND destination_wallet_id <> wallet_id) OR "
            "(transaction_type <> 'transfer' AND destination_wallet_id IS NULL)"
            ")",
        // debt_id is set exactly when the row represents a debt movement.
        "CHECK ("
            "(transaction_type IN ('debt_payment', 'debt_borrowing')) = "
            "(debt_id IS NOT NULL)"
            ")",
      ];
}
