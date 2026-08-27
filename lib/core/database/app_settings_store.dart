import '../database/database.dart';
import '../utils/local_date.dart';

/// Plain key-value access to the `app_settings` table — local UI/UX
/// preferences (last-used wallet, recently-used category, theme mode),
/// never financial data or secrets. See the AppSettings table doc for why
/// secrets specifically must never live here.
class AppSettingsStore {
  AppSettingsStore(this._db);

  final AppDatabase _db;

  Future<String?> getString(String key) async {
    final row =
        await (_db.select(_db.appSettings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setString(String key, String value) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value, updatedAt: utcNowMillis()),
        );
  }
}

abstract final class SettingsKeys {
  static const lastUsedWalletId = 'fast_add.last_used_wallet_id';
  static const lastUsedCategoryId = 'fast_add.last_used_category_id';
}
