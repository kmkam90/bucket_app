import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/core/app_error.dart';

void main() {
  group('AppError', () {
    test('sameCodeAs returns true for matching codes', () {
      final a = AppError(code: AppErrorCode.writeFailed, message: 'fail 1');
      final b = AppError(code: AppErrorCode.writeFailed, message: 'fail 2');
      expect(a.sameCodeAs(b), true);
    });

    test('sameCodeAs returns false for different codes', () {
      final a = AppError(code: AppErrorCode.writeFailed, message: 'fail');
      final b = AppError(code: AppErrorCode.loadFailed, message: 'fail');
      expect(a.sameCodeAs(b), false);
    });

    test('equality based on code + message', () {
      final a = AppError(code: AppErrorCode.writeFailed, message: 'x');
      final b = AppError(code: AppErrorCode.writeFailed, message: 'x');
      expect(a, equals(b));
    });

    test('toString includes code and message', () {
      final e = AppError(code: AppErrorCode.importTooLarge, message: '10MB');
      expect(e.toString(), contains('importTooLarge'));
      expect(e.toString(), contains('10MB'));
    });
  });

  group('ErrorHistory', () {
    test('adds errors and retrieves them', () {
      final history = ErrorHistory();
      final e = AppError(code: AppErrorCode.writeFailed, message: 'a');
      history.add(e);
      expect(history.length, 1);
      expect(history.latest, e);
    });

    test('respects maxSize (ring buffer eviction)', () {
      final history = ErrorHistory(maxSize: 3);
      for (int i = 0; i < 5; i++) {
        history.add(AppError(code: AppErrorCode.writeFailed, message: 'err_$i'));
      }
      expect(history.length, 3);
      // Should keep the 3 most recent
      expect(history.all[0].message, 'err_2');
      expect(history.all[1].message, 'err_3');
      expect(history.all[2].message, 'err_4');
    });

    test('latest returns null when empty', () {
      final history = ErrorHistory();
      expect(history.latest, isNull);
      expect(history.isEmpty, true);
    });

    test('clear empties the buffer', () {
      final history = ErrorHistory();
      history.add(AppError(code: AppErrorCode.unknown, message: 'x'));
      history.clear();
      expect(history.isEmpty, true);
      expect(history.length, 0);
    });

    test('all returns unmodifiable list', () {
      final history = ErrorHistory();
      history.add(AppError(code: AppErrorCode.unknown, message: 'x'));
      expect(() => history.all.add(AppError(code: AppErrorCode.unknown, message: 'y')),
          throwsA(isA<UnsupportedError>()));
    });
  });

  group('AppState errorHistory integration', () {
    // Note: Full AppState integration is covered in error_resilience_test.dart.
    // These tests focus on the ErrorHistory data structure itself.

    test('ErrorHistory toString shows codes', () {
      final history = ErrorHistory(maxSize: 5);
      history.add(AppError(code: AppErrorCode.writeFailed, message: 'a'));
      history.add(AppError(code: AppErrorCode.loadFailed, message: 'b'));
      final str = history.toString();
      expect(str, contains('2/5'));
      expect(str, contains('writeFailed'));
      expect(str, contains('loadFailed'));
    });
  });
}
