import 'category_entity.dart';

class NewCategoryInput {
  final String name;
  final CategoryType type;
  final String? parentId;
  final String? icon;

  const NewCategoryInput({
    required this.name,
    required this.type,
    this.parentId,
    this.icon,
  });
}

abstract interface class CategoryRepository {
  Future<Category> createCategory(NewCategoryInput input);

  Future<Category> renameCategory(String id, String name, {String? icon});

  /// Like wallets, categories are RESTRICTed by any transaction that
  /// references them (§26 "category deletion with existing transactions")
  /// and by any child category, so only archiving is exposed here.
  Future<void> archiveCategory(String id);

  Future<void> unarchiveCategory(String id);

  Stream<List<Category>> watchCategories({CategoryType? type, bool includeArchived = false});
}
