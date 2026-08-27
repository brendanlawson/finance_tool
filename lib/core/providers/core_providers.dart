import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_settings_store.dart';
import '../database/database.dart';
import '../security/app_lock_service.dart';
import '../security/key_manager.dart';

final keyManagerProvider = Provider<KeyManager>((ref) => KeyManager());

final appLockServiceProvider = Provider<AppLockService>((ref) => AppLockService());

/// Overridden with the real, already-opened [AppDatabase] in `main()`
/// before `runApp` — see lib/main.dart. Opening the database requires
/// first awaiting the encryption key from secure storage
/// (KeyManager.databasePassphraseHex), which is done once at startup
/// rather than threading a loading state through every screen that reads
/// from the database. Test setups override this the same way, with an
/// in-memory [AppDatabase.forTesting] instance — see test/test_utils.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'appDatabaseProvider must be overridden with a real AppDatabase before runApp()',
  );
});

final appSettingsStoreProvider = Provider<AppSettingsStore>((ref) {
  return AppSettingsStore(ref.watch(appDatabaseProvider));
});
