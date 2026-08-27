import 'package:drift/drift.dart';

/// Plain key-value store for local app configuration (theme mode, default
/// wallet for Fast Add, biometric-lock toggle, ...). Never used for
/// financial data and never used to store secrets — the database
/// passphrase and PIN salt live in platform secure storage
/// (lib/core/security/key_manager.dart), not here, because this table is
/// inside the (admittedly encrypted) database file itself.
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
