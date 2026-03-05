import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/models/goal_log.dart';

void main() {
  group('GoalLog constructor', () {
    test('empty id throws assert', () {
      expect(
        () => GoalLog(id: '', date: DateTime(2026, 1, 1), value: 1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('createdAt defaults to now', () {
      final before = DateTime.now();
      final log = GoalLog(id: 'a', date: DateTime(2026, 1, 1), value: 1);
      expect(log.createdAt.isAfter(before) || log.createdAt.isAtSameMomentAs(before), isTrue);
    });
  });

  group('GoalLog.habit()', () {
    test('creates log with value 1.0', () {
      final log = GoalLog.habit(id: 'h1', date: DateTime(2026, 3, 1));
      expect(log.value, 1.0);
      expect(log.note, isNull);
    });

    test('accepts optional note', () {
      final log = GoalLog.habit(id: 'h1', date: DateTime(2026, 3, 1), note: 'done');
      expect(log.note, 'done');
    });
  });

  group('GoalLog.increment()', () {
    test('creates log with given amount', () {
      final log = GoalLog.increment(id: 'i1', date: DateTime(2026, 3, 1), amount: 5.5);
      expect(log.value, 5.5);
    });

    test('rejects zero amount', () {
      expect(
        () => GoalLog.increment(id: 'i1', date: DateTime(2026, 3, 1), amount: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects negative amount', () {
      expect(
        () => GoalLog.increment(id: 'i1', date: DateTime(2026, 3, 1), amount: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('GoalLog date normalization', () {
    test('constructor normalizes date to local midnight', () {
      final log = GoalLog(id: 'a', date: DateTime(2026, 3, 5, 14, 30, 45), value: 1);
      expect(log.date, DateTime(2026, 3, 5));
      expect(log.date.hour, 0);
    });

    test('date is always local midnight regardless of input time', () {
      final log = GoalLog(id: 'a', date: DateTime(2026, 3, 5, 23, 59), value: 1);
      expect(log.date, DateTime(2026, 3, 5));
    });
  });

  group('GoalLog JSON', () {
    test('round-trips correctly', () {
      final original = GoalLog(
        id: 'test1',
        date: DateTime(2026, 3, 5),
        value: 3.5,
        note: 'ran 3.5 km',
        createdAt: DateTime(2026, 3, 5, 10, 0),
      );
      final restored = GoalLog.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.value, original.value);
      expect(restored.note, original.note);
    });

    test('fromJson with empty map throws assert (empty id)', () {
      expect(() => GoalLog.fromJson({}), throwsA(isA<AssertionError>()));
    });

    test('fromJson with valid fields works', () {
      final log = GoalLog.fromJson({
        'id': 'test',
        'date': '2026-01-01T00:00:00.000',
        'value': 5.0,
      });
      expect(log.id, 'test');
      expect(log.value, 5.0);
      expect(log.note, isNull);
    });

    test('toJson omits null note', () {
      final log = GoalLog(id: 'a', date: DateTime(2026, 1, 1), value: 1);
      expect(log.toJson().containsKey('note'), isFalse);
    });

    test('toJson includes note when present', () {
      final log = GoalLog(id: 'a', date: DateTime(2026, 1, 1), value: 1, note: 'hi');
      expect(log.toJson()['note'], 'hi');
    });
  });

  group('GoalLog.fromLegacyJson()', () {
    test('converts old LogEntry format', () {
      final log = GoalLog.fromLegacyJson({
        'date': '2026-03-05T00:00:00.000',
        'value': 1,
      });
      expect(log.id, startsWith('legacy_'));
      expect(log.value, 1.0);
      expect(log.date, DateTime(2026, 3, 5));
    });

    test('handles missing date', () {
      final log = GoalLog.fromLegacyJson({'value': 1});
      expect(log.id, startsWith('legacy_'));
      // date falls back to now — just verify no crash
      expect(log.value, 1.0);
    });

    test('handles missing value', () {
      final log = GoalLog.fromLegacyJson({'date': '2026-01-01T00:00:00.000'});
      expect(log.value, 0.0);
    });
  });

  group('GoalLog equality', () {
    test('same fields are equal', () {
      final date = DateTime(2026, 3, 5);
      final a = GoalLog(id: 'x', date: date, value: 1.0, createdAt: date);
      final b = GoalLog(id: 'x', date: date, value: 1.0, createdAt: date);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different id means not equal', () {
      final date = DateTime(2026, 3, 5);
      final a = GoalLog(id: 'x', date: date, value: 1.0);
      final b = GoalLog(id: 'y', date: date, value: 1.0);
      expect(a, isNot(b));
    });
  });

  group('GoalLog.copyWith()', () {
    test('creates modified copy', () {
      final original = GoalLog(id: 'a', date: DateTime(2026, 1, 1), value: 1);
      final copy = original.copyWith(value: 5.0, note: 'updated');
      expect(copy.value, 5.0);
      expect(copy.note, 'updated');
      expect(copy.id, 'a'); // unchanged
      expect(original.value, 1.0); // original unchanged
    });
  });
}
