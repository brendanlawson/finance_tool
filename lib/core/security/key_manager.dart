import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../errors/app_failure.dart';

/// Owns the database encryption key's entire lifecycle. This is the only
/// class in the app that touches the raw key material.
///
/// # Lifecycle
///
/// **First launch**: [databasePassphraseHex] finds nothing under
/// [_dbKeyStorageKey], generates 32 bytes from a CSPRNG
/// (`Random.secure()`, which on every platform Flutter supports is backed
/// by the OS entropy source — `/dev/urandom` on Linux/Android/macOS/iOS,
/// `BCryptGenRandom` on Windows), hex-encodes them, and writes that string
/// to platform secure storage before returning it.
///
/// **Every subsequent launch**: the same key is read back from secure
/// storage and handed to [AppDatabase] before the database file is opened,
/// via `PRAGMA key = "x'<hex>'"` (a raw 256-bit key literal — see
/// lib/core/database/database.dart — this skips PBKDF2 passphrase
/// derivation entirely, which is unnecessary when the "passphrase" is
/// already 256 random bits generated on-device rather than something a
/// human chose).
///
/// **Storage backend**: `flutter_secure_storage`, which is Android
/// Keystore-backed (EncryptedSharedPreferences) on Android, Keychain on
/// iOS/macOS, Credential Manager (DPAPI) on Windows, and libsecret on
/// Linux. The key material never touches app preferences, the database
/// file itself, or any log.
///
/// **Key rotation**: [rotateDatabaseKey] generates a new key and returns
/// both old and new so the caller (a maintenance flow in Settings) can run
/// `PRAGMA rekey = "x'<new hex>'"` against the *already-open* database —
/// SQLCipher/SQLite3MC re-encrypt the file in place under the existing
/// connection. This class never performs that SQL itself, because it has
/// no database connection; it only manages the key value.
///
/// **If the secure-storage key is lost** (OS keystore reset, app data
/// wiped by the OS, device factory-reset without a restore): the database
/// file is permanently unreadable. There is no recovery path and no
/// backdoor — that is what "encrypted at rest" means. This is exactly why
/// encrypted backups (lib/features/backup) exist as a separate mechanism:
/// they carry their own independent passphrase (one the user chose and
/// can re-enter), so losing the on-device key does not mean losing the
/// user's financial history, only the current unrestored copy of it.
class KeyManager {
  KeyManager({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _dbKeyStorageKey = 'finance_tool.db_key_hex_v1';

  Future<String> databasePassphraseHex() async {
    try {
      final existing = await _storage.read(key: _dbKeyStorageKey);
      if (existing != null && existing.isNotEmpty) {
        return existing;
      }
      final generated = _generateKeyHex();
      await _storage.write(key: _dbKeyStorageKey, value: generated);
      return generated;
    } catch (e) {
      throw EncryptionFailure(
        'Could not access this device\'s secure storage, so the local '
        'database cannot be unlocked. ($e)',
      );
    }
  }

  /// Generates a brand new key without touching the one currently stored.
  /// Callers are responsible for running `PRAGMA rekey` against the open
  /// database and only then calling [commitRotatedKey] — if the app is
  /// killed between generating and committing, the old key (still in
  /// storage) remains valid because the database was never rekeyed.
  String generateCandidateKeyHex() => _generateKeyHex();

  Future<void> commitRotatedKey(String newKeyHex) async {
    await _storage.write(key: _dbKeyStorageKey, value: newKeyHex);
  }

  String _generateKeyHex() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
