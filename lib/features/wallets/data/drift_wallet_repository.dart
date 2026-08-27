import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/local_date.dart';
import '../../debts/domain/debt_entity.dart';
import '../../transactions/data/transaction_mappers.dart';
import '../domain/wallet_balance_rules.dart';
import '../domain/wallet_entity.dart';
import '../domain/wallet_repository.dart';
import 'wallet_mappers.dart';

class DriftWalletRepository implements WalletRepository {
  DriftWalletRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Wallet> createWallet(NewWalletInput input) async {
    if (input.name.trim().isEmpty) {
      throw const ValidationFailure('Wallet name cannot be empty.', field: 'name');
    }
    final now = utcNowMillis();
    final id = IdGenerator.generate();
    try {
      await _db.into(_db.wallets).insert(
            WalletsCompanion.insert(
              id: id,
              name: input.name.trim(),
              accountType: input.accountType.name,
              currencyCode: input.initialBalance.currencyCode,
              initialBalanceMinor: Value(input.initialBalance.minorUnits),
              currentBalanceMinor: Value(input.initialBalance.minorUnits),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } catch (e) {
      throw wrapUnexpectedDatabaseError(e);
    }
    final row = await (_db.select(_db.wallets)..where((w) => w.id.equals(id))).getSingle();
    return row.toDomain();
  }

  @override
  Future<Wallet> renameWallet(String id, String name) async {
    if (name.trim().isEmpty) {
      throw const ValidationFailure('Wallet name cannot be empty.', field: 'name');
    }
    final existing =
        await (_db.select(_db.wallets)..where((w) => w.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw NotFoundFailure('Wallet $id does not exist.');
    }
    final now = utcNowMillis();
    final updated = await (_db.update(_db.wallets)..where((w) => w.id.equals(id))).writeReturning(
      WalletsCompanion(
        name: Value(name.trim()),
        revision: Value(existing.revision + 1),
        updatedAt: Value(now),
      ),
    );
    return updated.first.toDomain();
  }

  @override
  Future<void> archiveWallet(String id) => _setArchived(id, true);

  @override
  Future<void> unarchiveWallet(String id) => _setArchived(id, false);

  Future<void> _setArchived(String id, bool archived) async {
    final now = utcNowMillis();
    final count = await (_db.update(_db.wallets)..where((w) => w.id.equals(id))).write(
      WalletsCompanion(archived: Value(archived), updatedAt: Value(now)),
    );
    if (count == 0) {
      throw NotFoundFailure('Wallet $id does not exist.');
    }
  }

  @override
  Stream<List<Wallet>> watchWallets({bool includeArchived = false}) {
    final query = _db.select(_db.wallets)..orderBy([(w) => OrderingTerm.asc(w.createdAt)]);
    if (!includeArchived) {
      query.where((w) => w.archived.equals(false));
    }
    return query.watch().map((rows) => rows.map((r) => r.toDomain()).toList(growable: false));
  }

  @override
  Stream<Wallet?> watchWallet(String id) {
    return (_db.select(_db.wallets)..where((w) => w.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row?.toDomain());
  }

  @override
  Future<Money> recomputeBalance(String walletId) async {
    return _db.transaction(() async {
      final wallet =
          await (_db.select(_db.wallets)..where((w) => w.id.equals(walletId))).getSingleOrNull();
      if (wallet == null) {
        throw NotFoundFailure('Wallet $walletId does not exist.');
      }

      // Every row that touches this wallet either as its primary
      // `wallet_id` or (for a transfer) as `destination_wallet_id`.
      final rows = await (_db.select(_db.transactions)
            ..where((t) =>
                t.deletedAt.isNull() &
                (t.walletId.equals(walletId) | t.destinationWalletId.equals(walletId))))
          .get();

      // Debt type determines the sign for debt_borrowing/debt_payment
      // (see WalletBalanceRules.deltaFor) — fetch once for whichever
      // debts these rows reference.
      final debtIds = rows.map((r) => r.debtId).whereType<String>().toSet();
      final assetDebtIds = <String>{};
      if (debtIds.isNotEmpty) {
        final debtRows =
            await (_db.select(_db.debts)..where((d) => d.id.isIn(debtIds))).get();
        for (final d in debtRows) {
          if (DebtTypeStorage.fromStorage(d.debtType).isAssetNotLiability) {
            assetDebtIds.add(d.id);
          }
        }
      }

      // Reuses the exact same rule the write path uses (WalletBalanceRules)
      // rather than re-deriving "which types increase vs. decrease a
      // balance" here — that duplication is exactly how a recompute tool
      // and the live ledger could quietly disagree.
      var totalMinor = wallet.initialBalanceMinor;
      for (final row in rows) {
        final entity = row.toDomain(tagIds: const {});
        final effect = WalletBalanceRules.deltaFor(
          entity,
          isAssetDebt: entity.debtId != null && assetDebtIds.contains(entity.debtId),
        );
        final delta = effect.walletDeltas[walletId];
        if (delta != null) totalMinor += delta.minorUnits;
      }

      await (_db.update(_db.wallets)..where((w) => w.id.equals(walletId))).write(
        WalletsCompanion(currentBalanceMinor: Value(totalMinor)),
      );

      return Money(minorUnits: totalMinor, currencyCode: wallet.currencyCode);
    }).catchError((Object e, StackTrace st) {
      if (e is AppFailure) throw e;
      throw wrapUnexpectedDatabaseError(e, st);
    });
  }
}
