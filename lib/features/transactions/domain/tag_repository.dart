import 'tag_entity.dart';

abstract interface class TagRepository {
  Stream<List<Tag>> watchTags();

  /// Returns the existing tag with this name (case-insensitive), or
  /// creates one. Tag creation is implicit like this — via typing a name
  /// wherever tags are picked — rather than a separate "manage tags"
  /// screen, since tags are lightweight, user-invented labels.
  Future<Tag> getOrCreateTag(String name);
}
