import 'package:uuid/uuid.dart';

/// Generates primary keys.
///
/// UUIDv7 is used instead of an autoincrement integer or UUIDv4:
/// - Autoincrement integers collide the moment two devices create rows
///   offline and later need to sync — the whole point of §16 is to not
///   paint that corner in. UUIDs are globally unique without coordination.
/// - v7 (RFC 9562) embeds a millisecond timestamp in its high bits, so IDs
///   generated later sort after IDs generated earlier. That keeps SQLite's
///   primary-key B-tree insertion-ordered (good locality, no random-write
///   fragmentation) whereas plain random v4 UUIDs would scatter inserts
///   across the index.
abstract final class IdGenerator {
  static const Uuid _uuid = Uuid();

  static String generate() => _uuid.v7();
}
