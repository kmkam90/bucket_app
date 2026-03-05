import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/models/enums.dart';
import 'package:bucket_app/models/goal_target.dart';

void main() {
  group('GoalTarget constructor', () {
    test('frequency mode requires timesPerWeek', () {
      expect(
        () => GoalTarget(mode: GoalTargetMode.frequency),
        throwsA(isA<AssertionError>()),
      );
    });

    test('frequency mode rejects timesPerWeek = 0', () {
      expect(
        () => GoalTarget(mode: GoalTargetMode.frequency, timesPerWeek: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('frequency mode accepts timesPerWeek > 0', () {
      final t = GoalTarget(mode: GoalTargetMode.frequency, timesPerWeek: 3);
      expect(t.timesPerWeek, 3);
    });

    test('total mode requires targetTotalValue', () {
      expect(
        () => GoalTarget(mode: GoalTargetMode.total),
        throwsA(isA<AssertionError>()),
      );
    });

    test('total mode rejects targetTotalValue = 0', () {
      expect(
        () => GoalTarget(mode: GoalTargetMode.total, targetTotalValue: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('total mode accepts targetTotalValue > 0', () {
      final t = GoalTarget(
          mode: GoalTargetMode.total, targetTotalValue: 100, unit: GoalUnit.books);
      expect(t.targetTotalValue, 100);
    });

    test('recommendedDays rejects out-of-range values', () {
      expect(
        () => GoalTarget(
            mode: GoalTargetMode.frequency,
            timesPerWeek: 1,
            recommendedDays: [0, 7]),
        throwsA(isA<AssertionError>()),
      );
    });

    test('recommendedDays are unmodifiable', () {
      final t = GoalTarget(
          mode: GoalTargetMode.frequency,
          timesPerWeek: 1,
          recommendedDays: [0, 1, 2]);
      expect(() => (t.recommendedDays as List).add(3), throwsA(anything));
    });

    test('endDate before startDate throws', () {
      expect(
        () => GoalTarget(
          mode: GoalTargetMode.frequency,
          timesPerWeek: 1,
          startDate: DateTime(2026, 3, 10),
          endDate: DateTime(2026, 3, 1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('GoalTarget.validate()', () {
    test('valid frequency returns empty', () {
      final t = GoalTarget(mode: GoalTargetMode.frequency, timesPerWeek: 3);
      expect(t.validate(), isEmpty);
      expect(t.isValid, isTrue);
    });

    test('valid total returns empty', () {
      final t = GoalTarget(
          mode: GoalTargetMode.total, targetTotalValue: 50, unit: GoalUnit.books);
      expect(t.validate(), isEmpty);
    });
  });

  group('GoalTarget.fromJson() safety', () {
    test('missing mode defaults to frequency', () {
      final t = GoalTarget.fromJson({});
      expect(t.mode, GoalTargetMode.frequency);
      expect(t.timesPerWeek, 1); // safe default
    });

    test('frequency with missing timesPerWeek gets default 1', () {
      final t = GoalTarget.fromJson({'mode': 'frequency'});
      expect(t.timesPerWeek, 1);
    });

    test('total with missing targetTotalValue gets default 1.0', () {
      final t = GoalTarget.fromJson({'mode': 'total'});
      expect(t.targetTotalValue, 1.0);
    });

    test('unknown mode falls back to frequency', () {
      final t = GoalTarget.fromJson({'mode': 'unknown_mode'});
      expect(t.mode, GoalTargetMode.frequency);
    });

    test('out-of-range recommendedDays are filtered', () {
      final t = GoalTarget.fromJson({
        'mode': 'frequency',
        'timesPerWeek': 2,
        'recommendedDays': [0, 3, 7, -1, 6],
      });
      expect(t.recommendedDays, [0, 3, 6]);
    });

    test('endDate before startDate is clamped', () {
      final t = GoalTarget.fromJson({
        'mode': 'frequency',
        'timesPerWeek': 1,
        'startDate': '2026-03-10T00:00:00.000',
        'endDate': '2026-03-01T00:00:00.000',
      });
      expect(t.endDate, t.startDate);
    });

    test('invalid date string is null', () {
      final t = GoalTarget.fromJson({
        'mode': 'frequency',
        'timesPerWeek': 1,
        'startDate': 'not-a-date',
      });
      expect(t.startDate, isNull);
    });
  });

  group('GoalTarget JSON round-trip', () {
    test('frequency round-trips', () {
      final original = GoalTarget(
        mode: GoalTargetMode.frequency,
        timesPerWeek: 5,
        recommendedDays: [0, 2, 4],
      );
      final restored = GoalTarget.fromJson(original.toJson());
      expect(restored, original);
    });

    test('total round-trips', () {
      final original = GoalTarget(
        mode: GoalTargetMode.total,
        targetTotalValue: 42.5,
        unit: GoalUnit.hours,
      );
      final restored = GoalTarget.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  group('GoalTarget.copyWith()', () {
    test('creates modified copy', () {
      final original = GoalTarget(mode: GoalTargetMode.frequency, timesPerWeek: 3);
      final copy = original.copyWith(timesPerWeek: 5);
      expect(copy.timesPerWeek, 5);
      expect(original.timesPerWeek, 3); // original unchanged
    });
  });

  group('GoalTarget equality', () {
    test('same values are equal', () {
      final a = GoalTarget(mode: GoalTargetMode.frequency, timesPerWeek: 3);
      final b = GoalTarget(mode: GoalTargetMode.frequency, timesPerWeek: 3);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different values are not equal', () {
      final a = GoalTarget(mode: GoalTargetMode.frequency, timesPerWeek: 3);
      final b = GoalTarget(mode: GoalTargetMode.frequency, timesPerWeek: 5);
      expect(a, isNot(b));
    });
  });
}
