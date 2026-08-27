/// The current backup JSON schema version this app writes and can still
/// read. Bump this, and add a migration branch in
/// JsonBackupCodec.decode, whenever the shape of the exported data
/// changes — never repurpose an old version number for a new shape.
const backupFormatVersion = 1;

/// Everything a `.financebackup` file's manifest shows the user *before*
/// they commit to restoring it (§14) — enough to sanity-check "is this
/// the backup I think it is" without having decrypted anything sensitive
/// onto screen.
class BackupManifest {
  final int formatVersion;
  final DateTime createdAt;
  final String appVersion;
  final String checksumSha256;
  final Map<String, int> rowCounts;

  const BackupManifest({
    required this.formatVersion,
    required this.createdAt,
    required this.appVersion,
    required this.checksumSha256,
    required this.rowCounts,
  });

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'appVersion': appVersion,
        'checksumSha256': checksumSha256,
        'rowCounts': rowCounts,
      };

  factory BackupManifest.fromJson(Map<String, dynamic> json) => BackupManifest(
        formatVersion: json['formatVersion'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        appVersion: json['appVersion'] as String,
        checksumSha256: json['checksumSha256'] as String,
        rowCounts: Map<String, int>.from(json['rowCounts'] as Map),
      );
}

/// The result of [BackupRepository.validateBackupFile]: the file has been
/// decrypted, parsed, and integrity-checked, but nothing has been written
/// to the live database yet. [BackupRepository.restoreFromBackup] takes
/// this back to actually commit it.
class RestorePreview {
  final BackupManifest manifest;
  final Map<String, dynamic> data;

  const RestorePreview({required this.manifest, required this.data});
}

class BackupExportResult {
  final List<int> bytes;
  final String suggestedFileName;
  const BackupExportResult({required this.bytes, required this.suggestedFileName});
}
