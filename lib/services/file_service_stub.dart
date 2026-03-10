// Stub implementations for non-web platforms.

Future<bool> downloadJson(String jsonString, String filename) async {
  return false;
}

Future<String?> pickJsonFile() async {
  return null;
}
