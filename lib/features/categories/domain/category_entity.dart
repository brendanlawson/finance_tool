import 'package:meta/meta.dart';

enum CategoryType { income, expense }

@immutable
class Category {
  final String id;
  final String name;
  final CategoryType type;
  final String? parentId;
  final String? icon;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.parentId,
    required this.icon,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isTopLevel => parentId == null;

  Category copyWith({
    String? name,
    String? icon,
    bool? archived,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      type: type,
      parentId: parentId,
      icon: icon ?? this.icon,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Category &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.parentId == parentId &&
      other.icon == icon &&
      other.archived == archived &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, name, type, parentId, icon, archived, updatedAt);
}
