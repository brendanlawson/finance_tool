import '../utils/app_logger.dart';

/// Typed application errors shown to the UI.
///
/// Repositories and services must catch raw exceptions (SqliteException,
/// DriftRuntimeException, FileSystemException, FormatException, ...) at
/// their boundary and rethrow one of these instead. The UI layer never
/// pattern-matches on a raw SQLite/IO exception, and app_failure messages
/// never interpolate raw exception text that could contain a file path,
/// stack frame, or (in principle) fragments of a SQL statement — see the
/// threat model note on crash-report/log hygiene in the security docs.
sealed class AppFailure implements Exception {
  final String message;
  const AppFailure(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

final class DatabaseFailure extends AppFailure {
  const DatabaseFailure([super.message = 'A database error occurred.']);
}

final class ValidationFailure extends AppFailure {
  /// Optional field name the validation error applies to, so a form can
  /// highlight the right input instead of showing a generic banner.
  final String? field;
  const ValidationFailure(super.message, {this.field});
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'The requested item was not found.']);
}

final class BackupFailure extends AppFailure {
  const BackupFailure([super.message = 'The backup could not be created.']);
}

final class ImportFailure extends AppFailure {
  const ImportFailure([super.message = 'The backup file could not be imported.']);
}

final class EncryptionFailure extends AppFailure {
  const EncryptionFailure([super.message = 'A security error occurred.']);
}

final class MigrationFailure extends AppFailure {
  const MigrationFailure([super.message = 'The database could not be upgraded.']);
}

/// Wraps an unexpected, non-actionable exception without leaking its raw
/// text to the UI. Use at repository/service boundaries as the default
/// branch of a catch clause after the specific failure types above.
DatabaseFailure wrapUnexpectedDatabaseError(Object error, [StackTrace? stackTrace]) {
  AppLogger.error('Unexpected database error', error: error, stackTrace: stackTrace);
  return const DatabaseFailure(
    'Something went wrong while reading or writing your data. '
    'Your existing data has not been changed.',
  );
}
