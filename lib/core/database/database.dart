import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as raw_sqlite3;

import '../errors/app_failure.dart';
import '../utils/app_logger.dart';
import 'tables/app_settings_table.dart';
import 'tables/categories_table.dart';
import 'tables/debt_payments_table.dart';
import 'tables/debts_table.dart';
import 'tables/profiles_table.dart';
import 'tables/tags_table.dart';
import 'tables/transaction_tags_table.dart';
import 'tables/transactions_table.dart';
import 'tables/wallets_table.dart';

part 'database.g.dart';

const String _dbFileName = 'finance_tool.sqlite';

/// The live database's on-disk location — shared with the backup feature
/// (which needs to make a safety copy of this exact file before a
/// restore, see lib/features/backup/data/drift_backup_repository.dart)
/// so the path logic exists in exactly one place.
Future<File> resolveDatabaseFile({Directory? directoryOverride}) async {
  final dir = directoryOverride ?? await getApplicationSupportDirectory();
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  return File(p.join(dir.path, _dbFileName));
}

/// The encrypted, local-first source of truth for every financial fact in
/// the app. Nothing in this app talks to a remote database — this file
/// (or its restored copy) is the whole store.
@DriftDatabase(tables: [
  Profiles,
  Wallets,
  Categories,
  Transactions,
  Tags,
  TransactionTags,
  Debts,
  DebtPayments,
  AppSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase._(super.executor);

  /// Opens (creating on first launch) the encrypted database file in the
  /// platform's application-support directory.
  ///
  /// [passphraseHex] must be the 32-byte, hex-encoded key from
  /// [KeyManager.databasePassphraseHex] — this class never generates or
  /// stores that key itself, so encryption key lifecycle stays in exactly
  /// one place.
  factory AppDatabase.open({required String passphraseHex, Directory? directoryOverride}) {
    return AppDatabase._(_openConnection(passphraseHex, directoryOverride));
  }

  /// For tests: a real (temp-file-backed) database with the same
  /// schema/migrations and encryption setup as production, so migration
  /// and repository tests exercise the real code path.
  ///
  /// This deliberately does not use `NativeDatabase.memory()`: SQLite3MC
  /// refuses `PRAGMA key` outright on in-memory/temporary databases
  /// ("Setting key not supported for in-memory or temporary databases"),
  /// since there is no file for the key to protect. A throwaway file is
  /// the only way to test the encrypted code path at all, and it costs
  /// nothing extra to delete when [file] is provided by a test's own
  /// temp-directory fixture.
  ///
  /// [useBackgroundIsolate] defaults to true to match production
  /// (`AppDatabase.open` always runs on a background isolate so real disk
  /// I/O never blocks the UI thread). Widget tests must pass `false`:
  /// `flutter_test` runs `testWidgets` bodies inside a `FakeAsync` zone
  /// that only fast-forwards *this* isolate's timers — a background
  /// isolate's genuine cross-isolate message passing never gets real
  /// wall-clock time inside that zone, so `tester.pump()` would never
  /// observe the query finishing. Plain repository/unit tests (using
  /// real `test()`, not `testWidgets()`) run outside FakeAsync and are
  /// unaffected either way.
  factory AppDatabase.forTesting(
    String passphraseHex, {
    File? file,
    bool useBackgroundIsolate = true,
  }) {
    final dbFile = file ??
        File(p.join(
          Directory.systemTemp.createTempSync('finance_tool_test_').path,
          'test.sqlite',
        ));
    void setup(raw_sqlite3.Database db) => _applyConnectionSetup(db, passphraseHex);
    return AppDatabase._(
      useBackgroundIsolate
          ? NativeDatabase.createInBackground(dbFile, setup: setup)
          : NativeDatabase(dbFile, setup: setup),
    );
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      // v1 has no predecessors yet. Future schema changes must use
      // stepByStep migrations here (drift.simonbinder.eu/migrations) rather
      // than bumping schemaVersion and relying on onCreate — onCreate only
      // ever runs against a brand-new, empty database file. A real
      // migration step must never be destructive (no "drop and recreate a
      // table to add a column"): a bug in a migration is the one class of
      // bug in this app that can destroy years of a user's financial
      // history, which is exactly why _openConnection snapshots the
      // database file before invoking any upgrade — see below.
      onUpgrade: (Migrator m, int from, int to) async {
        AppLogger.warning('Database migration requested: v$from -> v$to');
      },
    );
  }

  static QueryExecutor _openConnection(String passphraseHex, Directory? directoryOverride) {
    return LazyDatabase(() async {
      final file = await resolveDatabaseFile(directoryOverride: directoryOverride);

      await _backupBeforeMigrationIfNeeded(file, passphraseHex);

      return NativeDatabase.createInBackground(
        file,
        setup: (db) => _applyConnectionSetup(db, passphraseHex),
      );
    });
  }

  /// §11/§14: never let a schema migration run against the only copy of
  /// the user's data. If the on-disk file's stored schema version is
  /// older than what this build expects — i.e. a migration is about to
  /// run — copy the file aside first. The copy is a plain encrypted
  /// SQLite file (same key), so it is restorable the same way any backup
  /// is, and is safe to leave on disk indefinitely; it is not
  /// auto-deleted so a failed migration always leaves a way back.
  static Future<void> _backupBeforeMigrationIfNeeded(File file, String passphraseHex) async {
    if (!file.existsSync()) return;

    late final int onDiskVersion;
    try {
      final db = raw_sqlite3.sqlite3.open(file.path);
      try {
        db.execute("PRAGMA key = \"x'$passphraseHex'\";");
        onDiskVersion = db.select('PRAGMA user_version;').first.values.first as int;
      } finally {
        db.close();
      }
    } catch (e) {
      // If we can't even read the version, do not block app startup on a
      // best-effort safety copy — the migration step itself will surface
      // a MigrationFailure if the database truly can't be opened.
      AppLogger.warning('Could not inspect schema version before migration check', error: e);
      return;
    }

    const targetVersion = 1; // keep in sync with AppDatabase.schemaVersion
    if (onDiskVersion >= targetVersion) return;

    final backupPath =
        '${file.path}.pre-migration-v$onDiskVersion-to-v$targetVersion.bak';
    try {
      await file.copy(backupPath);
      AppLogger.warning('Pre-migration safety backup written to $backupPath');
    } catch (e) {
      throw MigrationFailure(
        'Could not create a safety backup before upgrading the database, '
        'so the upgrade was not attempted. ($e)',
      );
    }
  }

  static void _applyConnectionSetup(raw_sqlite3.Database db, String passphraseHex) {
    db.execute("PRAGMA key = \"x'$passphraseHex'\";");
    _assertCipherActive(db);
    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('PRAGMA journal_mode = WAL;');
  }

  /// Fails fast, on every connection open, if the sqlite3mc hook (see
  /// pubspec.yaml `hooks:`) is somehow not active and the app is silently
  /// running against a plain, unencrypted SQLite build — the one failure
  /// mode that must never pass unnoticed. `PRAGMA cipher;` (queried, not
  /// assigned) only returns a non-empty cipher name when built against
  /// SQLite3MultipleCiphers/SQLCipher; this is the check Drift's own
  /// encryption docs recommend.
  static void _assertCipherActive(raw_sqlite3.Database db) {
    final rows = db.select('PRAGMA cipher;');
    if (rows.isEmpty) {
      throw const EncryptionFailure(
        'This build of the app is not linked against an encryption-capable '
        'SQLite, so the local database cannot be opened securely.',
      );
    }
  }
}
