import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/database/database.dart';
import 'core/providers/core_providers.dart';
import 'core/security/key_manager.dart';
import 'core/utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // The database is opened once, here, before the widget tree exists —
    // not behind a FutureProvider every screen has to unwrap — because
    // getting the encryption key from secure storage is the one piece of
    // startup that must complete before *anything* touching the database
    // can run. See core_providers.dart for the override this feeds.
    final keyManager = KeyManager();
    final passphraseHex = await keyManager.databasePassphraseHex();
    final database = AppDatabase.open(passphraseHex: passphraseHex);

    runApp(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const FinanceApp(),
      ),
    );
  } catch (error, stackTrace) {
    AppLogger.error('Failed to start app', error: error, stackTrace: stackTrace);
    runApp(_StartupErrorApp(error: error));
  }
}

/// If the database can't be opened at all (secure storage unavailable,
/// disk full, a corrupted file) the app must not crash to a blank screen —
/// this is the one path where there is genuinely nothing else useful to
/// show, but the user still deserves to know why, not just a hang.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'This device\'s local data could not be unlocked.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
