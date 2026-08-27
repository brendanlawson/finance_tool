import 'package:finance_tool/core/database/database.dart';

/// A fresh encrypted, temp-file-backed database per test — same schema,
/// migrations, and encryption setup as production (see
/// AppDatabase.forTesting), just pointed at a throwaway file instead of
/// the app's real data directory. Not `:memory:`: SQLite3MC refuses to
/// set an encryption key on an in-memory database at all, so a real
/// (if temporary) file is the only way to exercise the encrypted code
/// path in tests.
///
/// Pass [useBackgroundIsolate]: false from a `testWidgets` body — see the
/// doc on [AppDatabase.forTesting] for why widget tests need the
/// synchronous, same-isolate variant.
AppDatabase createTestDatabase({bool useBackgroundIsolate = true}) {
  return AppDatabase.forTesting(
    '00112233445566778899aabbccddeeff00112233445566778899aabbccddee',
    useBackgroundIsolate: useBackgroundIsolate,
  );
}
