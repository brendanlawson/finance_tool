/// Kept in sync with the `version:` in pubspec.yaml by hand — this app
/// deliberately has no build step (like package_info_plus) wired up yet
/// to read it automatically, since the only consumer today is the backup
/// manifest, not anything user-facing that would notice drift quickly.
const String kAppVersion = '1.0.0';
