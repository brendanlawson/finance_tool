import '../../../core/money/money.dart';
import 'wallet_entity.dart';

class NewWalletInput {
  final String name;
  final WalletAccountType accountType;
  final Money initialBalance;

  const NewWalletInput({
    required this.name,
    required this.accountType,
    required this.initialBalance,
  });
}

abstract interface class WalletRepository {
  Future<Wallet> createWallet(NewWalletInput input);

  Future<Wallet> renameWallet(String id, String name);

  /// Archiving is the only supported way to "remove" a wallet that has
  /// transactions — see §26 ("wallet deletion with existing transactions")
  /// and the RESTRICT foreign key on transactions.wallet_id, which makes a
  /// true hard delete impossible once any transaction references it. A
  /// wallet with zero transactions could in principle be hard-deleted, but
  /// this interface does not expose that operation at all: archiving is
  /// reversible (see [unarchiveWallet]) and hard deletion is not, so there
  /// is no version of "delete" here that could surprise a user.
  Future<void> archiveWallet(String id);

  Future<void> unarchiveWallet(String id);

  Stream<List<Wallet>> watchWallets({bool includeArchived = false});

  Stream<Wallet?> watchWallet(String id);

  /// Rebuilds `current_balance_minor` from `initial_balance_minor` plus
  /// every non-deleted ledger transaction, bypassing the cache entirely.
  /// Exists as an explicit maintenance/repair operation and as the
  /// ground-truth oracle backup/restore tests check the cache against —
  /// not something the app calls on a normal read path (see the Wallets
  /// table doc comment for why the cache exists at all).
  Future<Money> recomputeBalance(String walletId);
}
