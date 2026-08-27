import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../wallets/application/wallet_providers.dart';
import '../data/drift_backup_repository.dart';
import '../data/local_file_backup_transport.dart';
import '../domain/backup_repository.dart';
import '../domain/backup_transport.dart';

final backupTransportProvider = Provider<BackupTransport>((ref) => LocalFileBackupTransport());

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return DriftBackupRepository(ref.watch(appDatabaseProvider), ref.watch(walletRepositoryProvider));
});
