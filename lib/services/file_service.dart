import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional imports for web file operations
import 'file_service_stub.dart'
    if (dart.library.html) 'file_service_web.dart' as impl;

/// Platform-agnostic file service for backup export/import.
class FileService {
  /// Downloads a JSON string as a file. Returns true if successful.
  static Future<bool> downloadJson(String jsonString, String filename) async {
    if (kIsWeb) {
      return impl.downloadJson(jsonString, filename);
    }
    // Mobile/desktop: not yet implemented
    return false;
  }

  /// Opens a file picker and returns the file contents as a string.
  /// Returns null if cancelled.
  static Future<String?> pickJsonFile() async {
    if (kIsWeb) {
      return impl.pickJsonFile();
    }
    return null;
  }
}
