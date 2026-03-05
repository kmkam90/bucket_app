import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/utils/date_utils.dart' as app_dates;
import 'package:bucket_app/models/goal_log.dart';
import 'package:bucket_app/models/goal_progress.dart';
import 'package:bucket_app/models/goal_target.dart';
import 'package:bucket_app/models/enums.dart';

void main() {
  // ─── Core Helpers ───────────────────────────────────────────

  group('dateOnly', () {
    test('strips time from local DateTime', () {
      final dt = DateTime(2026, 3, 5, 14, 30, 45, 123);
      final result = app_dates.dateOnly(dt);
      expect(result, DateTime(2026, 3, 5));
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
      expect(result.millisecond, 0);
    });

    test('converts UTC to local before stripping', () {
      // UTC midnight Mar 5 → should become local date (not shifted)
      final utc = DateTime.utc(2026, 3, 5, 0, 0, 0);
      final result = app_dates.dateOnly(utc);
      final local = utc.toLocal();
      expect(result, DateTime(local.year, local.month, local.day));
      expect(result.isUtc, false);
    });
  });

  group('sameDate', () {
    test('returns true for same calendar day, different times', () {
      final a = DateTime(2026, 3, 5, 8, 0);
      final b = DateTime(2026, 3, 5, 23, 59);
      expect(app_dates.sameDate(a, b), true);
    });

    test('returns false for different days', () {
      final a = DateTime(2026, 3, 5);
      final b = DateTime(2026, 3, 6);
      expect(app_dates.sameDate(a, b), false);
    });
  });

  group('isNextCalendarDay', () {
    test('works across month boundary (Jan 31 → Feb 1)', () {
      final jan31 = DateTime(2026, 1, 31);
      final feb1 = DateTime(2026, 2, 1);
      expect(app_dates.isNextCalendarDay(jan31, feb1), true);
    });

    test('returns false for same day', () {
      final day = DateTime(2026, 3, 5);
      expect(app_dates.isNextCalendarDay(day, day), false);
    });

    test('returns false for 2 days apart', () {
      final a = DateTime(2026, 3, 5);
      final b = DateTime(2026, 3, 7);
      expect(app_dates.isNextCalendarDay(a, b), false);
    });
  });

  // ─── Streak Edge Cases ──────────────────────────────────────

  group('streak calculations', () {
    GoalProgress makeHabitProgress(List<DateTime> dates) {
      final logs = dates.asMap().entries.map((e) =>
        GoalLog.habit(id: 'log_${e.key}', date: e.value),
      ).toList();
      return GoalProgress(
        target: GoalTarget(mode: GoalTargetMode.frequency, timesPerWeek: 3),
        logs: logs,
      );
    }

    test('streak across midnight: logs at 23:59 and 00:01 next day → 2-day streak', () {
      // GoalLog normalizes dates, so 23:59 and 00:01 become two different days
      final p = makeHabitProgress([
        DateTime(2026, 3, 4, 23, 59),
        DateTime(2026, 3, 5, 0, 1),
      ]);
      expect(p.bestStreak, 2);
    });

    test('streak at year boundary: Dec 31 → Jan 1 → 2-day streak', () {
      final p = makeHabitProgress([
        DateTime(2025, 12, 31),
        DateTime(2026, 1, 1),
      ]);
      expect(p.bestStreak, 2);
    });

    test('best streak with month-end gap: Jan 30, Jan 31, Feb 2 → best streak = 2', () {
      final p = makeHabitProgress([
        DateTime(2026, 1, 30),
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 2),
      ]);
      expect(p.bestStreak, 2);
    });

    test('streak across Feb 28 → Mar 1 (non-leap year 2025)', () {
      final p = makeHabitProgress([
        DateTime(2025, 2, 28),
        DateTime(2025, 3, 1),
      ]);
      expect(p.bestStreak, 2);
    });
  });

  // ─── Week Boundaries ───────────────────────────────────────

  group('ISO week helpers', () {
    test('startOfIsoWeek for a Wednesday → correct Monday', () {
      final wed = DateTime(2026, 3, 4); // Wednesday
      final monday = app_dates.startOfIsoWeek(wed);
      expect(monday, DateTime(2026, 3, 2)); // Monday
      expect(monday.weekday, DateTime.monday);
    });

    test('endOfIsoWeek for Monday → correct Sunday', () {
      final mon = DateTime(2026, 3, 2); // Monday
      final sunday = app_dates.endOfIsoWeek(mon);
      expect(sunday, DateTime(2026, 3, 8)); // Sunday
      expect(sunday.weekday, DateTime.sunday);
    });

    test('startOfIsoWeek for a Monday returns same day', () {
      final mon = DateTime(2026, 3, 2);
      expect(app_dates.startOfIsoWeek(mon), DateTime(2026, 3, 2));
    });

    test('currentWeekCompletions when week spans month boundary', () {
      // Mar 30 is Monday, Apr 5 is Sunday (ISO week)
      final target = GoalTarget(mode: GoalTargetMode.frequency, timesPerWeek: 5);
      final logs = [
        GoalLog.habit(id: 'a', date: DateTime(2026, 3, 30)),
        GoalLog.habit(id: 'b', date: DateTime(2026, 3, 31)),
        GoalLog.habit(id: 'c', date: DateTime(2026, 4, 1)),
      ];
      final p = GoalProgress(target: target, logs: logs);

      // We can't directly test currentWeekCompletions (depends on DateTime.now()),
      // but we can verify the logs are properly normalized
      expect(logs[0].date, DateTime(2026, 3, 30));
      expect(logs[2].date, DateTime(2026, 4, 1));

      // Verify hasLogOnDate works across month boundary
      expect(p.hasLogOnDate(DateTime(2026, 3, 30)), true);
      expect(p.hasLogOnDate(DateTime(2026, 4, 1)), true);
      expect(p.hasLogOnDate(DateTime(2026, 4, 2)), false);
    });
  });

  // ─── Normalization Safety ──────────────────────────────────

  group('GoalLog normalization', () {
    test('constructor normalizes DateTime.now() (time stripped)', () {
      final log = GoalLog(
        id: 'test_1',
        date: DateTime(2026, 3, 5, 14, 30, 45),
        value: 1.0,
      );
      expect(log.date, DateTime(2026, 3, 5));
      expect(log.date.hour, 0);
      expect(log.date.minute, 0);
    });

    test('fromJson normalizes UTC-suffixed date string', () {
      final log = GoalLog.fromJson({
        'id': 'test_2',
        'date': '2026-03-05T14:30:00.000Z',
        'value': 1.0,
      });
      // Should be local date, not shifted by UTC conversion
      final expected = DateTime.utc(2026, 3, 5, 14, 30).toLocal();
      expect(log.date, DateTime(expected.year, expected.month, expected.day));
      expect(log.date.hour, 0);
    });

    test('toJson round-trip preserves date-only (no time in output)', () {
      final log = GoalLog(
        id: 'test_3',
        date: DateTime(2026, 3, 5, 23, 59, 59),
        value: 2.5,
      );
      final json = log.toJson();
      expect(json['date'], '2026-03-05');
      // No time component in the string
      expect((json['date'] as String).contains('T'), false);
    });

    test('hasLogOnDate matches after normalization', () {
      final target = GoalTarget(mode: GoalTargetMode.total, targetTotalValue: 100);
      final logs = [
        GoalLog(id: 'a', date: DateTime(2026, 3, 5, 18, 30), value: 10),
      ];
      final p = GoalProgress(target: target, logs: logs);

      // Should match regardless of the time queried
      expect(p.hasLogOnDate(DateTime(2026, 3, 5, 0, 0)), true);
      expect(p.hasLogOnDate(DateTime(2026, 3, 5, 23, 59)), true);
      expect(p.hasLogOnDate(DateTime(2026, 3, 6)), false);
    });
  });
}
