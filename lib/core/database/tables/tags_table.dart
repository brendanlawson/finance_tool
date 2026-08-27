import 'package:drift/drift.dart';

@TableIndex(name: 'idx_tags_name', columns: {#name}, unique: true)
@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
