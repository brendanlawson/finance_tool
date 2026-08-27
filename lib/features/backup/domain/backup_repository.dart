import 'backup_models.dart';

abstract interface class BackupRepository {
  /// Encrypts the entire application's data (every table needed to fully
  /// reconstruct it — see the class doc on DriftBackupRepository) with
  /// [passphrase] and returns the file bytes to hand to a
  /// [BackupTransport]. This is the only backup type §13 allows calling a
  /// complete backup; CSV/JSON exports below are explicitly not that.
  Future<BackupExportResult> exportEncryptedBackup(String passphrase);

  /// Decrypts and validates [bytes] with [passphrase] without writing
  /// anything to the live database — format version, checksum, and
  /// manifest are all checked here so the caller can show the user what
  /// they are about to restore (§14) before [restoreFromBackup] commits
  /// to it.
  Future<RestorePreview> validateBackupFile(List<int> bytes, String passphrase);

  /// Commits a previously-[validateBackupFile]d restore: snapshots the
  /// current database, replaces its contents, recomputes every derived
  /// balance from the restored ledger, and only then considers the
  /// restore successful. See DriftBackupRepository.restoreFromBackup for
  /// the exact commit/rollback mechanics.
  Future<void> restoreFromBackup(RestorePreview preview);

  /// A flat CSV of transactions with wallet/category names resolved, for
  /// spreadsheet analysis. Not a substitute for [exportEncryptedBackup] —
  /// debts, wallets-without-transactions, and settings are all absent
  /// from a CSV by construction (§13).
  Future<List<int>> exportCsv();

  /// The same data as [exportEncryptedBackup], as plaintext JSON, for
  /// interoperability/migration/debugging (§13) — not encrypted, so
  /// callers must treat the resulting bytes as sensitive.
  Future<List<int>> exportJson();
}
