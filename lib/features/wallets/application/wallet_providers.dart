import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/drift_wallet_repository.dart';
import '../domain/wallet_entity.dart';
import '../domain/wallet_repository.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return DriftWalletRepository(ref.watch(appDatabaseProvider));
});

/// Live wallet list. Automatically re-emits after any create/rename/
/// archive/balance-changing operation — Drift tracks that those all touch
/// the `wallets` table and re-runs this query itself; nothing here (or in
/// any UI that watches it) needs to call `ref.invalidate` (§20).
final walletsProvider = StreamProvider<List<Wallet>>((ref) {
  return ref.watch(walletRepositoryProvider).watchWallets();
});

/// All wallets, active and archived — for a "manage wallets" screen where
/// archived ones still need to be visible (to unarchive) even though they
/// are hidden from [walletsProvider] and dashboard aggregates.
final allWalletsIncludingArchivedProvider = StreamProvider<List<Wallet>>((ref) {
  return ref.watch(walletRepositoryProvider).watchWallets(includeArchived: true);
});

final walletByIdProvider = StreamProvider.family<Wallet?, String>((ref, id) {
  return ref.watch(walletRepositoryProvider).watchWallet(id);
});
