import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/local_date.dart';
import '../domain/tag_entity.dart';
import '../domain/tag_repository.dart';

class DriftTagRepository implements TagRepository {
  DriftTagRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Tag>> watchTags() {
    return (_db.select(_db.tags)..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  @override
  Future<Tag> getOrCreateTag(String name) async {
    final trimmed = name.trim();
    // Tags are a small, personal-scale dataset — matching case-insensitive
    // duplicates in Dart avoids depending on SQLite collation specifics.
    final existing = await (_db.select(_db.tags)).get();
    final match = existing.where((t) => t.name.toLowerCase() == trimmed.toLowerCase()).firstOrNull;
    if (match != null) return _toDomain(match);

    final now = utcNowMillis();
    final id = IdGenerator.generate();
    await _db.into(_db.tags).insert(TagsCompanion.insert(id: id, name: trimmed, createdAt: now));
    return Tag(id: id, name: trimmed, createdAt: fromUtcMillis(now));
  }

  Tag _toDomain(TagRow row) => Tag(id: row.id, name: row.name, createdAt: fromUtcMillis(row.createdAt));
}
