import 'package:drift/drift.dart';

/// The app is single-user, but a row-per-profile (rather than a single
/// hardcoded settings blob) costs nothing today and avoids a schema change
/// if a "family/shared device with separate profiles" feature is ever
/// requested later.
@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get baseCurrency => text()();
  TextColumn get locale => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
