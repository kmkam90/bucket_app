import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/core/result.dart';

void main() {
  group('Result', () {
    test('Ok holds data', () {
      const result = Ok(42);
      expect(result.data, 42);
      expect(result.warnings, isEmpty);
    });

    test('Ok holds warnings', () {
      const result = Ok('data', warnings: ['warn1', 'warn2']);
      expect(result.data, 'data');
      expect(result.warnings, hasLength(2));
    });

    test('Err holds message and error', () {
      final result = Err<int>('failed', error: Exception('boom'));
      expect(result.message, 'failed');
      expect(result.error, isA<Exception>());
    });

    test('pattern matching works', () {
      Result<int> result = const Ok(10);
      String output;
      switch (result) {
        case Ok(:final data):
          output = 'ok:$data';
        case Err(:final message):
          output = 'err:$message';
      }
      expect(output, 'ok:10');

      result = const Err('nope');
      switch (result) {
        case Ok(:final data):
          output = 'ok:$data';
        case Err(:final message):
          output = 'err:$message';
      }
      expect(output, 'err:nope');
    });
  });
}
