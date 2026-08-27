import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/local_date.dart';
import '../domain/category_entity.dart';
import '../domain/category_repository.dart';
import 'category_mappers.dart';

class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Category> createCategory(NewCategoryInput input) async {
    if (input.name.trim().isEmpty) {
      throw const ValidationFailure('Category name cannot be empty.', field: 'name');
    }
    if (input.parentId != null) {
      final parent = await (_db.select(_db.categories)..where((c) => c.id.equals(input.parentId!)))
          .getSingleOrNull();
      if (parent == null) {
        throw NotFoundFailure('Parent category ${input.parentId} does not exist.');
      }
      if (parent.type != input.type.name) {
        throw const ValidationFailure(
          'A subcategory must have the same income/expense type as its parent.',
        );
      }
    }
    final now = utcNowMillis();
    final id = IdGenerator.generate();
    try {
      await _db.into(_db.categories).insert(
            CategoriesCompanion.insert(
              id: id,
              name: input.name.trim(),
              type: input.type.name,
              parentId: Value(input.parentId),
              icon: Value(input.icon),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } catch (e) {
      throw wrapUnexpectedDatabaseError(e);
    }
    final row = await (_db.select(_db.categories)..where((c) => c.id.equals(id))).getSingle();
    return row.toDomain();
  }

  @override
  Future<Category> renameCategory(String id, String name, {String? icon}) async {
    if (name.trim().isEmpty) {
      throw const ValidationFailure('Category name cannot be empty.', field: 'name');
    }
    final now = utcNowMillis();
    final updated = await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
        .writeReturning(CategoriesCompanion(
      name: Value(name.trim()),
      icon: icon != null ? Value(icon) : const Value.absent(),
      updatedAt: Value(now),
    ));
    if (updated.isEmpty) {
      throw NotFoundFailure('Category $id does not exist.');
    }
    return updated.first.toDomain();
  }

  @override
  Future<void> archiveCategory(String id) => _setArchived(id, true);

  @override
  Future<void> unarchiveCategory(String id) => _setArchived(id, false);

  Future<void> _setArchived(String id, bool archived) async {
    final now = utcNowMillis();
    final count = await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(archived: Value(archived), updatedAt: Value(now)),
    );
    if (count == 0) {
      throw NotFoundFailure('Category $id does not exist.');
    }
  }

  @override
  Stream<List<Category>> watchCategories({CategoryType? type, bool includeArchived = false}) {
    final query = _db.select(_db.categories)..orderBy([(c) => OrderingTerm.asc(c.name)]);
    if (type != null) {
      query.where((c) => c.type.equals(type.name));
    }
    if (!includeArchived) {
      query.where((c) => c.archived.equals(false));
    }
    return query.watch().map((rows) => rows.map((r) => r.toDomain()).toList(growable: false));
  }
}
