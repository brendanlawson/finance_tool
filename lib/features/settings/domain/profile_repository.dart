import 'profile_entity.dart';

abstract interface class ProfileRepository {
  /// Streams the single local profile, creating a default one (VND, `en`
  /// locale — both editable afterward) on first run. The app has no
  /// concept of "no profile yet" past the very first frame: nothing else
  /// has to null-check this.
  Stream<Profile> watchProfile();

  Future<Profile> updateProfile({String? displayName, String? baseCurrency, String? locale});
}
