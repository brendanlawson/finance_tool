import 'package:drift/drift.dart';

/// `currentBalanceMinor` is a materialized cache of the ledger, not an
/// independent source of truth: it is only ever written by
/// [WalletRepository]/[TransactionRepository] inside the same database
/// transaction that inserts, edits, or deletes the ledger row that changes
/// it (see lib/features/wallets/data/drift_wallet_repository.dart). The
/// ledger (the transactions table) is what [WalletRepository.recomputeBalance]
/// re-derives from if the cache ever needs to be rebuilt. This
/// cache-plus-authoritative-recompute design is chosen over "always SUM the
/// ledger" because dashboards and wallet lists read balances far more often
/// than transactions are written, and a full-table SUM on every render does
/// not scale to a multi-year transaction history (§19 of the design brief).
@TableIndex(name: 'idx_wallets_archived', columns: {#archived})
@DataClassName('WalletRow')
class Wallets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// One of [WalletAccountType.name] — stored as text rather than an
  /// integer enum index so the raw database file stays self-describing.
  TextColumn get accountType => text().customConstraint(
        "NOT NULL CHECK (account_type IN "
        "('cash', 'bank', 'eWallet', 'savings', 'credit', 'other'))",
      )();

  TextColumn get currencyCode =>
      text().customConstraint('NOT NULL CHECK (length(currency_code) = 3)')();

  IntColumn get initialBalanceMinor => integer().withDefault(const Constant(0))();
  IntColumn get currentBalanceMinor => integer().withDefault(const Constant(0))();

  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// Incremented on every update. Not consulted by any conflict-resolution
  /// logic yet (there is no sync in V1) but present now so that a future
  /// last-writer-wins or vector-clock sync layer does not require an
  /// additive-then-backfilled migration on a table that may already hold
  /// years of user data.
  IntColumn get revision => integer().withDefault(const Constant(0))();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
