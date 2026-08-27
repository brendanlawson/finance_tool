/// Where backup bytes go to and come from. The domain/application layers
/// only ever see this interface — never a concrete file-picker, WebDAV
/// client, or cloud-drive SDK call — so that adding a sync destination
/// later (§15: "manual file transfer, local network, WebDAV,
/// Syncthing-managed directory, user-controlled cloud drive,
/// device-to-device transfer") means writing one new adapter class in
/// lib/features/backup/data, not touching BackupRepository or any UI.
///
/// V1 ships exactly one implementation, [LocalFileBackupTransport], which
/// hands off to the OS's native save/open dialogs — there is no bundled
/// network transport, on purpose (§2.2/§30: no cloud dependency by
/// default).
abstract interface class BackupTransport {
  /// Presents a save dialog (or, on mobile, a share sheet) for [bytes]
  /// named [suggestedFileName]. Returns the final location description if
  /// known, or null if the user cancelled.
  Future<String?> save({required List<int> bytes, required String suggestedFileName});

  /// Presents an open dialog restricted to [allowedExtensions] (without
  /// the leading dot) and returns the picked file's bytes, or null if the
  /// user cancelled.
  Future<List<int>?> pick({required List<String> allowedExtensions});
}
