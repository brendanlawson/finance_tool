import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/drift_category_repository.dart';
import '../domain/category_entity.dart';
import '../domain/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return DriftCategoryRepository(ref.watch(appDatabaseProvider));
});

final categoriesProvider =
    StreamProvider.family<List<Category>, CategoryType?>((ref, type) {
  return ref.watch(categoryRepositoryProvider).watchCategories(type: type);
});
