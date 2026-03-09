import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/core/app_error.dart';
import 'package:bucket_app/errors/user_error_message.dart';

void main() {
  group('userMessageFor', () {
    test('every AppErrorCode has a user message', () {
      for (final code in AppErrorCode.values) {
        final error = AppError(code: code, message: 'technical detail');
        final msg = userMessageFor(error);
        expect(msg, isNotEmpty, reason: '${code.name} should have a message');
        // User message should NOT be the raw technical message
        expect(msg, isNot('technical detail'),
            reason: '${code.name} should map to a user-friendly message');
      }
    });

    test('returns expected Korean strings', () {
      expect(
        userMessageFor(AppError(code: AppErrorCode.writeFailed, message: '')),
        '저장에 실패했습니다. 잠시 후 다시 시도해주세요.',
      );
      expect(
        userMessageFor(AppError(code: AppErrorCode.importTooLarge, message: '')),
        '파일 크기가 너무 큽니다.',
      );
      expect(
        userMessageFor(AppError(code: AppErrorCode.loadFailed, message: '')),
        '데이터를 불러오는 중 문제가 발생했습니다.',
      );
    });

    test('unknown error returns fallback message', () {
      final msg = userMessageFor(
        AppError(code: AppErrorCode.unknown, message: 'some internal crash'),
      );
      expect(msg, '알 수 없는 오류가 발생했습니다.');
    });
  });

  group('isRetryable', () {
    test('write and load failures are retryable', () {
      expect(isRetryable(AppErrorCode.writeFailed), true);
      expect(isRetryable(AppErrorCode.writeVerifyFailed), true);
      expect(isRetryable(AppErrorCode.loadFailed), true);
    });

    test('import and parse failures are not retryable', () {
      expect(isRetryable(AppErrorCode.importFailed), false);
      expect(isRetryable(AppErrorCode.importTooLarge), false);
      expect(isRetryable(AppErrorCode.importParseFailed), false);
    });

    test('migration and unknown are not retryable', () {
      expect(isRetryable(AppErrorCode.migrationFailed), false);
      expect(isRetryable(AppErrorCode.unknown), false);
    });
  });

  group('AppError.toString()', () {
    test('includes code, message, and time', () {
      final e = AppError(code: AppErrorCode.writeFailed, message: 'disk full');
      final str = e.toString();
      expect(str, contains('writeFailed'));
      expect(str, contains('disk full'));
      // Should have HH:MM:SS time format
      expect(RegExp(r'\d{2}:\d{2}:\d{2}').hasMatch(str), true);
    });

    test('includes cause when present', () {
      final e = AppError(
        code: AppErrorCode.loadFailed,
        message: 'read error',
        cause: Exception('io failure'),
      );
      final str = e.toString();
      expect(str, contains('cause:'));
      expect(str, contains('io failure'));
    });

    test('omits cause when null', () {
      final e = AppError(code: AppErrorCode.unknown, message: 'x');
      expect(e.toString(), isNot(contains('cause:')));
    });
  });
}
