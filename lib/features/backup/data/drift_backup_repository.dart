import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as raw_sqlite3;

import '../../../core/constants.dart';
import '../../../core/database/database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/local_date.dart';
import '../../wallets/domain/wallet_repository.dart';
import '../domain/backup_models.dart';
import '../domain/backup_repository.dart';

const _tableNames = [
  'profiles',
  'wallets',
  'categories',
  'transactions',
  'tags',
  'transactionTags',
  'debts',
  'debtPayments',
  'appSettings',
];

/// Drift-backed [BackupRepository].
///
/// **Why the encrypted backup container is itself a tiny SQLite database**
/// (see [exportEncryptedBackup]/[_decryptContainer]) rather than a
/// hand-rolled AES scheme: this app already links an
/// encryption-capable SQLite build for the main database (SQLite3MC, see
/// pubspec.yaml `hooks:`). Reusing it for the backup file means zero new
/// cryptographic code to get right, at the cost of the backup file being
/// a valid (if minimal) SQLite file rather than a purpose-built format —
/// an acceptable trade for a personal finance app. The backup passphrase
/// is intentionally independent of the on-device database key (see
/// KeyManager's doc comment) — it goes through SQLCipher/SQLite3MC's own
/// PBKDF2 key derivation from the plain string, unlike the device key,
/// which is already 256 random bits and uses the raw-hex-key form.
class DriftBackupRepository implements BackupRepository {
  DriftBackupRepository(this._db, this._walletRepository);

  final AppDatabase _db;
  final WalletRepository _walletRepository;

  @override
  Future<BackupExportResult> exportEncryptedBackup(String passphrase) async {
    if (passphrase.trim().isEmpty) {
      throw const ValidationFailure('A backup passphrase is required.');
    }
    final envelope = await _buildEnvelope();
    final jsonBytes = utf8.encode(jsonEncode(envelope));
    final containerBytes = await _encryptContainer(jsonBytes, passphrase);
    final date = LocalDate.today().value;
    return BackupExportResult(
      bytes: containerBytes,
      suggestedFileName: 'finance_backup_$date.financebackup',
    );
  }

  @override
  Future<RestorePreview> validateBackupFile(List<int> bytes, String passphrase) async {
    final jsonBytes = await _decryptContainer(bytes, passphrase);
    Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw const ImportFailure('This file is not a recognizable backup.');
    }

    final formatVersion = envelope['formatVersion'] as int?;
    if (formatVersion == null || formatVersion > backupFormatVersion) {
      throw ImportFailure(
        'This backup was made by a newer version of the app '
        '(format v$formatVersion) and cannot be read here.',
      );
    }

    final data = envelope['data'] as Map<String, dynamic>?;
    final claimedChecksum = envelope['checksumSha256'] as String?;
    if (data == null || claimedChecksum == null) {
      throw const ImportFailure('This backup file is missing required sections.');
    }
    final actualChecksum = sha256.convert(utf8.encode(jsonEncode(data))).toString();
    if (actualChecksum != claimedChecksum) {
      throw const ImportFailure('This backup file appears to be corrupted (checksum mismatch).');
    }

    final manifest = BackupManifest(
      formatVersion: formatVersion,
      createdAt: DateTime.parse(envelope['createdAt'] as String),
      appVersion: envelope['appVersion'] as String? ?? 'unknown',
      checksumSha256: claimedChecksum,
      rowCounts: {
        for (final name in _tableNames) name: (data[name] as List?)?.length ?? 0,
      },
    );
    return RestorePreview(manifest: manifest, data: data);
  }

  @override
  Future<void> restoreFromBackup(RestorePreview preview) async {
    final dbFile = await resolveDatabaseFile();
    if (dbFile.existsSync()) {
      final backupPath =
          '${dbFile.path}.pre-restore-${utcNowMillis()}.bak';
      try {
        await dbFile.copy(backupPath);
        AppLogger.warning('Pre-restore safety backup written to $backupPath');
      } catch (e) {
        throw BackupFailure('Could not create a safety copy before restoring, so the '
            'restore was not attempted. ($e)');
      }
    }

    try {
      await _db.transaction(() async {
        // Defers every foreign-key check to the end of this transaction
        // instead of immediately per-statement — automatically reset when
        // the transaction ends, per SQLite's own semantics for this
        // pragma. Without it, re-inserting rows in *any* fixed table
        // order breaks: e.g. a debt_borrowing transaction references a
        // debt that (in insertion order below) doesn't exist yet, and a
        // child category can equally reference a parent_id that hasn't
        // been inserted yet. Deferring means insertion order only needs
        // to be reasonable, not a perfect topological sort.
        await _db.customStatement('PRAGMA defer_foreign_keys = ON;');

        // Children before parents so foreign-key RESTRICT constraints
        // don't block the wipe; children re-inserted after parents below.
        await _db.delete(_db.transactionTags).go();
        await _db.delete(_db.debtPayments).go();
        await _db.delete(_db.transactions).go();
        await _db.delete(_db.debts).go();
        await _db.delete(_db.categories).go();
        await _db.delete(_db.wallets).go();
        await _db.delete(_db.tags).go();
        await _db.delete(_db.appSettings).go();
        await _db.delete(_db.profiles).go();

        await _insertAll(_db.profiles, preview.data['profiles'], ProfileRow.fromJson);
        await _insertAll(_db.wallets, preview.data['wallets'], WalletRow.fromJson);
        await _insertAll(_db.categories, preview.data['categories'], CategoryRow.fromJson);
        await _insertAll(_db.transactions, preview.data['transactions'], TransactionRow.fromJson);
        await _insertAll(_db.tags, preview.data['tags'], TagRow.fromJson);
        await _insertAll(
            _db.transactionTags, preview.data['transactionTags'], TransactionTagRow.fromJson);
        await _insertAll(_db.debts, preview.data['debts'], DebtRow.fromJson);
        await _insertAll(_db.debtPayments, preview.data['debtPayments'], DebtPaymentRow.fromJson);
        await _insertAll(_db.appSettings, preview.data['appSettings'], AppSettingRow.fromJson);

        // The backup's cached wallet balances are trusted nowhere near as
        // much as the ledger rows that just got restored — recompute every
        // wallet from scratch so a restore can never leave a stale/wrong
        // cached balance on screen (mirrors WalletRepository's own
        // cache-vs-ledger design).
        final restoredWallets = await _db.select(_db.wallets).get();
        for (final wallet in restoredWallets) {
          await _walletRepository.recomputeBalance(wallet.id);
        }
      });
    } catch (e) {
      if (e is AppFailure) rethrow;
      throw ImportFailure('The restore failed and no changes were made. ($e)');
    }
  }

  Future<void> _insertAll<T extends Insertable<Object?>>(
    TableInfo table,
    Object? rawList,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final list = (rawList as List?) ?? const [];
    for (final entry in list) {
      await _db.into(table).insert(fromJson(entry as Map<String, dynamic>));
    }
  }

  @override
  Future<List<int>> exportJson() async {
    final envelope = await _buildEnvelope();
    return utf8.encode(jsonEncode(envelope));
  }

  @override
  Future<List<int>> exportCsv() async {
    final wallets = {for (final w in await _db.select(_db.wallets).get()) w.id: w.name};
    final categories = {for (final c in await _db.select(_db.categories).get()) c.id: c.name};
    final transactions = await (_db.select(_db.transactions)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAtLocalDate)]))
        .get();

    final buffer = StringBuffer();
    buffer.writeln('date,type,wallet,destination_wallet,category,amount,currency,note');
    for (final t in transactions) {
      buffer.writeln([
        t.occurredAtLocalDate,
        t.transactionType,
        _csvField(wallets[t.walletId] ?? t.walletId),
        _csvField(t.destinationWalletId == null ? '' : (wallets[t.destinationWalletId] ?? '')),
        _csvField(t.categoryId == null ? '' : (categories[t.categoryId] ?? '')),
        (t.amountMinor / _minorUnitDivisor(t.currencyCode)).toString(),
        t.currencyCode,
        _csvField(t.note ?? ''),
      ].join(','));
    }
    return utf8.encode(buffer.toString());
  }

  num _minorUnitDivisor(String currencyCode) {
    const zeroDecimal = {'VND', 'JPY', 'KRW'};
    return zeroDecimal.contains(currencyCode) ? 1 : 100;
  }

  String _csvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<Map<String, dynamic>> _buildEnvelope() async {
    final data = <String, dynamic>{
      'profiles': (await _db.select(_db.profiles).get()).map((r) => r.toJson()).toList(),
      'wallets': (await _db.select(_db.wallets).get()).map((r) => r.toJson()).toList(),
      'categories': (await _db.select(_db.categories).get()).map((r) => r.toJson()).toList(),
      'transactions': (await _db.select(_db.transactions).get()).map((r) => r.toJson()).toList(),
      'tags': (await _db.select(_db.tags).get()).map((r) => r.toJson()).toList(),
      'transactionTags':
          (await _db.select(_db.transactionTags).get()).map((r) => r.toJson()).toList(),
      'debts': (await _db.select(_db.debts).get()).map((r) => r.toJson()).toList(),
      'debtPayments': (await _db.select(_db.debtPayments).get()).map((r) => r.toJson()).toList(),
      'appSettings': (await _db.select(_db.appSettings).get()).map((r) => r.toJson()).toList(),
    };
    final checksum = sha256.convert(utf8.encode(jsonEncode(data))).toString();
    return {
      'formatVersion': backupFormatVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'appVersion': kAppVersion,
      'checksumSha256': checksum,
      'data': data,
    };
  }

  Future<List<int>> _encryptContainer(List<int> jsonBytes, String passphrase) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(p.join(tempDir.path, 'backup_${utcNowMillis()}.tmp'));
    if (tempFile.existsSync()) {
      tempFile.deleteSync();
    }
    final rawDb = raw_sqlite3.sqlite3.open(tempFile.path);
    try {
      rawDb.execute("PRAGMA key = '${passphrase.replaceAll("'", "''")}';");
      rawDb.execute('CREATE TABLE backup_blob (id INTEGER PRIMARY KEY, json_text TEXT NOT NULL);');
      final stmt = rawDb.prepare('INSERT INTO backup_blob (id, json_text) VALUES (1, ?);');
      try {
        stmt.execute([utf8.decode(jsonBytes)]);
      } finally {
        stmt.close();
      }
    } finally {
      rawDb.close();
    }
    final bytes = await tempFile.readAsBytes();
    await tempFile.delete();
    return bytes;
  }

  Future<List<int>> _decryptContainer(List<int> containerBytes, String passphrase) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(p.join(tempDir.path, 'restore_${utcNowMillis()}.tmp'));
    await tempFile.writeAsBytes(containerBytes);
    try {
      final rawDb = raw_sqlite3.sqlite3.open(tempFile.path);
      try {
        rawDb.execute("PRAGMA key = '${passphrase.replaceAll("'", "''")}';");
        final rows = rawDb.select('SELECT json_text FROM backup_blob WHERE id = 1;');
        if (rows.isEmpty) {
          throw const ImportFailure('This file is not a recognizable backup.');
        }
        return utf8.encode(rows.first['json_text'] as String);
      } on raw_sqlite3.SqliteException {
        throw const ImportFailure(
          'This backup could not be opened — check the passphrase and that '
          'the file was not corrupted or altered.',
        );
      } finally {
        rawDb.close();
      }
    } finally {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
    }
  }
}
