import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Application PIN lock: an in-app screen gate, unrelated to database
/// encryption (see lib/core/security/key_manager.dart for that).
///
/// The distinction matters because the two mechanisms fail differently:
/// * If the *database key* is lost, the data is unreadable, full stop.
/// * If the PIN is forgotten, the data is still sitting in the (still
///   readable-by-the-app) encrypted database; [resetPin] just replaces the
///   gate without touching the database key or its contents.
///
/// The PIN itself is never stored — only a salted SHA-256 hash of it, so a
/// leak of secure storage contents does not directly hand over the PIN.
/// This is a UI gate, not a cryptographic key derivation: it does not
/// protect the database file (an attacker with filesystem access bypasses
/// it entirely, which is exactly why database encryption is the mechanism
/// that matters against "device stolen" / "database copied" threats — see
/// the security threat model).
///
/// Biometric unlock (Face ID / fingerprint / Windows Hello) is a natural
/// extension point here via the `local_auth` package, deliberately not
/// wired up in this foundation — it would sit in front of this same
/// `unlock()` gate as an alternative, OS-verified way to pass it, not a
/// replacement for the PIN hash below.
class AppLockService {
  AppLockService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _pinHashKey = 'finance_tool.pin_hash_v1';
  static const _pinSaltKey = 'finance_tool.pin_salt_v1';

  Future<bool> isPinSet() async {
    final hash = await _storage.read(key: _pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: hash);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _pinSaltKey);
    final storedHash = await _storage.read(key: _pinHashKey);
    if (salt == null || storedHash == null) return false;
    return _hashPin(pin, salt) == storedHash;
  }

  /// Clears the PIN gate entirely (e.g. "forgot PIN" after re-proving
  /// identity some other way the calling flow decides on). Never touches
  /// the database key.
  Future<void> resetPin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final digest = sha256.convert(utf8.encode('$salt:$pin'));
    return digest.toString();
  }
}
