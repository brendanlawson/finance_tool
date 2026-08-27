import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/drift_profile_repository.dart';
import '../domain/profile_entity.dart';
import '../domain/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return DriftProfileRepository(ref.watch(appDatabaseProvider));
});

final profileProvider = StreamProvider<Profile>((ref) {
  return ref.watch(profileRepositoryProvider).watchProfile();
});
