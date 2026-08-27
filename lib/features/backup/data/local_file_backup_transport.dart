import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../domain/backup_transport.dart';

class LocalFileBackupTransport implements BackupTransport {
  @override
  Future<String?> save({required List<int> bytes, required String suggestedFileName}) async {
    final location = await FilePicker.saveFile(
      dialogTitle: 'Save backup',
      fileName: suggestedFileName,
      bytes: Uint8List.fromList(bytes),
    );
    return location?.toString();
  }

  @override
  Future<List<int>?> pick({required List<String> allowedExtensions}) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }
}
