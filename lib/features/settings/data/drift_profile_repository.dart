import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/local_date.dart';
import '../domain/profile_entity.dart';
import '../domain/profile_repository.dart';

const _defaultProfileId = 'local-profile';

class DriftProfileRepository implements ProfileRepository {
  DriftProfileRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<Profile> watchProfile() async* {
    await _ensureProfileExists();
    yield* (_db.select(_db.profiles)..where((p) => p.id.equals(_defaultProfileId)))
        .watchSingle()
        .map(_toDomain);
  }

  @override
  Future<Profile> updateProfile({String? displayName, String? baseCurrency, String? locale}) async {
    await _ensureProfileExists();
    final now = utcNowMillis();
    final rows = await (_db.update(_db.profiles)..where((p) => p.id.equals(_defaultProfileId)))
        .writeReturning(ProfilesCompanion(
      displayName: displayName != null ? Value(displayName) : const Value.absent(),
      baseCurrency: baseCurrency != null ? Value(baseCurrency) : const Value.absent(),
      locale: locale != null ? Value(locale) : const Value.absent(),
      updatedAt: Value(now),
    ));
    if (rows.isEmpty) {
      throw const DatabaseFailure('Profile could not be updated.');
    }
    return _toDomain(rows.first);
  }

  Future<void> _ensureProfileExists() async {
    final existing = await (_db.select(_db.profiles)..where((p) => p.id.equals(_defaultProfileId)))
        .getSingleOrNull();
    if (existing != null) return;
    final now = utcNowMillis();
    await _db.into(_db.profiles).insert(
          ProfilesCompanion.insert(
            id: _defaultProfileId,
            displayName: 'Me',
            baseCurrency: 'VND',
            locale: 'en',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Profile _toDomain(ProfileRow row) {
    return Profile(
      id: row.id,
      displayName: row.displayName,
      baseCurrency: row.baseCurrency,
      locale: row.locale,
      createdAt: fromUtcMillis(row.createdAt),
      updatedAt: fromUtcMillis(row.updatedAt),
    );
  }
}
