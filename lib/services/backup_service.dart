import '../core/result.dart';
import '../storage/app_repository.dart';

/// Thin wrapper — delegates to AppRepository for import/export.
class BackupService {
  static final _repo = AppRepository();

  static Future<Result<String>> exportToJson() => _repo.exportToJson();

  static Future<Result<void>> importFromJson(String jsonString) =>
      _repo.importFromJson(jsonString);
}
