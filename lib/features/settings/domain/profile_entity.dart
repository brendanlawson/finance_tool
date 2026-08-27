import 'package:meta/meta.dart';

@immutable
class Profile {
  final String id;
  final String displayName;
  final String baseCurrency;
  final String locale;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    required this.displayName,
    required this.baseCurrency,
    required this.locale,
    required this.createdAt,
    required this.updatedAt,
  });

  Profile copyWith({String? displayName, String? baseCurrency, String? locale, DateTime? updatedAt}) {
    return Profile(
      id: id,
      displayName: displayName ?? this.displayName,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      locale: locale ?? this.locale,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.displayName == displayName &&
      other.baseCurrency == baseCurrency &&
      other.locale == locale;

  @override
  int get hashCode => Object.hash(id, displayName, baseCurrency, locale);
}
