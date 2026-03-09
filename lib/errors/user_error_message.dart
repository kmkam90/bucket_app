import '../core/app_error.dart';

/// Maps error codes to clean, user-facing Korean messages.
///
/// Technical details stay in [AppError.message] for debug logs;
/// the UI always shows these friendly strings via [userMessageFor].
const Map<AppErrorCode, String> _userMessages = {
  AppErrorCode.writeFailed: '저장에 실패했습니다. 잠시 후 다시 시도해주세요.',
  AppErrorCode.writeVerifyFailed: '저장 확인 과정에서 문제가 발생했습니다.',
  AppErrorCode.loadFailed: '데이터를 불러오는 중 문제가 발생했습니다.',
  AppErrorCode.importFailed: '파일을 불러오지 못했습니다.',
  AppErrorCode.importTooLarge: '파일 크기가 너무 큽니다.',
  AppErrorCode.importParseFailed: '파일 형식이 올바르지 않습니다.',
  AppErrorCode.migrationFailed: '데이터 업데이트 중 오류가 발생했습니다.',
  AppErrorCode.unknown: '알 수 없는 오류가 발생했습니다.',
};

/// Returns a user-friendly message for the given error.
String userMessageFor(AppError error) =>
    _userMessages[error.code] ?? _userMessages[AppErrorCode.unknown]!;

/// Whether the error represents a transient failure worth retrying.
///
/// Retryable: write/load failures (disk, network, timing).
/// Non-retryable: import format/size issues (re-running won't help).
bool isRetryable(AppErrorCode code) {
  switch (code) {
    case AppErrorCode.writeFailed:
    case AppErrorCode.writeVerifyFailed:
    case AppErrorCode.loadFailed:
      return true;
    case AppErrorCode.importFailed:
    case AppErrorCode.importTooLarge:
    case AppErrorCode.importParseFailed:
    case AppErrorCode.migrationFailed:
    case AppErrorCode.unknown:
      return false;
  }
}
