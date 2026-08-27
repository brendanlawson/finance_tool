import 'package:drift/drift.dart';

/// Two-level category tree (parent/child, e.g. Food -> Groceries). Deeper
/// nesting is not prevented at the schema level, but the presentation
/// layer only ever renders two levels — that's a UI decision, not a data
/// integrity one, so it is not enforced here.
@TableIndex(name: 'idx_categories_parent', columns: {#parentId})
@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// 'income' or 'expense'. A category cannot serve both — the same
  /// category id is never reused across the income/expense split, which
  /// keeps monthly income-vs-expense aggregation a plain GROUP BY on
  /// category without also branching on transaction_type.
  TextColumn get type =>
      text().customConstraint("NOT NULL CHECK (type IN ('income', 'expense'))")();

  TextColumn get parentId => text().nullable().references(
        Categories,
        #id,
        onDelete: KeyAction.restrict,
      )();

  /// Opaque icon identifier (e.g. a Material icon name); interpreted only
  /// by the presentation layer.
  TextColumn get icon => text().nullable()();

  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        // A parent category cannot be its own child, and cannot belong to
        // the other income/expense side of the tree.
        'CHECK (parent_id IS NULL OR parent_id <> id)',
      ];
}
