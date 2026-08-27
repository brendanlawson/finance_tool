import 'package:meta/meta.dart';

@immutable
class Tag {
  final String id;
  final String name;
  final DateTime createdAt;

  const Tag({required this.id, required this.name, required this.createdAt});

  @override
  bool operator ==(Object other) =>
      other is Tag && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
