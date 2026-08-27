import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Backs every `path_provider` query with the real OS temp directory.
/// Needed because `DriftBackupRepository` calls `getTemporaryDirectory()`
/// for its encrypted-container staging file, and plain `flutter_test`
/// (unlike `testWidgets` against a real device) has no platform behind
/// the path_provider plugin channel at all — call
/// `FakePathProviderPlatform.install()` once at the top of a test file's
/// `main()` before any code under test touches path_provider.
class FakePathProviderPlatform extends PathProviderPlatform {
  static void install() {
    PathProviderPlatform.instance = FakePathProviderPlatform();
  }

  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getApplicationSupportPath() async =>
      Directory.systemTemp.createTempSync('finance_tool_test_support_').path;

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.createTempSync('finance_tool_test_docs_').path;
}
