import 'dart:developer' as developer;

/// Local-only diagnostic logging (§29 of the design brief).
///
/// This never leaves the device — there is no crash-reporting or analytics
/// SDK wired up, by design (privacy-first, no telemetry by default). Even
/// so, callers must not pass transaction notes, amounts, account names, or
/// any other financial detail as [message] or [error]; log the *kind* of
/// operation ("transaction insert failed"), not its content. Encryption
/// keys and backup passphrases must never be logged under any
/// circumstance.
abstract final class AppLogger {
  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message, name: 'finance_tool', level: 900, error: error, stackTrace: stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message, name: 'finance_tool', level: 1000, error: error, stackTrace: stackTrace);
  }
}
