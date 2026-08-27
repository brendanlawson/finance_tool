import '../../../core/database/database.dart';
import '../../../core/utils/local_date.dart';
import '../domain/category_entity.dart';

extension CategoryRowMapper on CategoryRow {
  Category toDomain() {
    return Category(
      id: id,
      name: name,
      type: type == 'income' ? CategoryType.income : CategoryType.expense,
      parentId: parentId,
      icon: icon,
      archived: archived,
      createdAt: fromUtcMillis(createdAt),
      updatedAt: fromUtcMillis(updatedAt),
    );
  }
}
