import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/models/enums.dart';
import 'package:bucket_app/models/goal_log.dart';
import 'package:bucket_app/models/goal_progress.dart';
import 'package:bucket_app/models/goal_target.dart';

GoalTarget _freqTarget(int timesPerWeek) =>
    GoalTarget(mode: GoalTargetMode.frequency, timesPerWeek: timesPerWeek);

GoalTarget _totalTarget(double total) =>
    GoalTarget(mode: GoalTargetMode.total, targetTotalValue: total, unit: GoalUnit.books);

GoalLog _log(String id, DateTime date, [double value = 1.0]) =>
    GoalLog(id: id, date: date, value: value, createdAt: date);

void main() {
  group('GoalProgress — empty logs', () {
    test('total mode: 0% completion', () {
      final p = GoalProgress(target: _totalTarget(100), logs: []);
      expect(p.completionPercent, 0.0);
      expect(p.remaining, 100.0);
      expect(p.isCompleted, isFalse);
      expect(p.totalValue, 0.0);
      expect(p.activeDays, 0);
    });

    test('frequency mode: 0% completion', () {
      final p = GoalProgress(target: _freqTarget(3), logs: []);
      expect(p.completionPercent, 0.0);
      expect(p.isCompleted, isFalse);
    });

    test('streaks are 0', () {
      final p = GoalProgress(target: _freqTarget(1), logs: []);
      expect(p.currentStreak, 0);
      expect(p.bestStreak, 0);
    });
  });

  group('GoalProgress — total mode completion', () {
    test('50% completion', () {
      final p = GoalProgress(
        target: _totalTarget(100),
        logs: [_log('a', DateTime(2026, 1, 1), 50)],
      );
      expect(p.completionPercent, 50.0);
      expect(p.remaining, 50.0);
      expect(p.isCompleted, isFalse);
    });

    test('100% completion', () {
      final p = GoalProgress(
        target: _totalTarget(10),
        logs: [
          _log('a', DateTime(2026, 1, 1), 7),
          _log('b', DateTime(2026, 1, 2), 3),
        ],
      );
      expect(p.completionPercent, 100.0);
      expect(p.remaining, 0.0);
      expect(p.isCompleted, isTrue);
    });

    test('over 100% clamps to 100', () {
      final p = GoalProgress(
        target: _totalTarget(10),
        logs: [_log('a', DateTime(2026, 1, 1), 15)],
      );
      expect(p.completionPercent, 100.0);
      expect(p.remaining, 0.0);
    });

    test('totalValue sums all logs', () {
      final p = GoalProgress(
        target: _totalTarget(100),
        logs: [
          _log('a', DateTime(2026, 1, 1), 10.5),
          _log('b', DateTime(2026, 1, 2), 20.3),
          _log('c', DateTime(2026, 1, 3), 5.0),
        ],
      );
      expect(p.totalValue, closeTo(35.8, 0.01));
    });
  });

  group('GoalProgress — remaining for non-total mode', () {
    test('frequency mode returns 0', () {
      final p = GoalProgress(target: _freqTarget(3), logs: []);
      expect(p.remaining, 0.0);
    });
  });

  group('GoalProgress — activeDays', () {
    test('counts unique days', () {
      final p = GoalProgress(
        target: _totalTarget(100),
        logs: [
          _log('a', DateTime(2026, 1, 1, 10, 0), 5),
          _log('b', DateTime(2026, 1, 1, 14, 0), 5), // same day
          _log('c', DateTime(2026, 1, 2), 5),
        ],
      );
      expect(p.activeDays, 2);
    });
  });

  group('GoalProgress — streaks', () {
    test('bestStreak with gaps', () {
      final p = GoalProgress(
        target: _freqTarget(1),
        logs: [
          _log('a', DateTime(2026, 1, 1)),
          _log('b', DateTime(2026, 1, 2)),
          _log('c', DateTime(2026, 1, 3)),
          // gap
          _log('d', DateTime(2026, 1, 10)),
          _log('e', DateTime(2026, 1, 11)),
        ],
      );
      expect(p.bestStreak, 3);
    });

    test('bestStreak single day', () {
      final p = GoalProgress(
        target: _freqTarget(1),
        logs: [_log('a', DateTime(2026, 1, 5))],
      );
      expect(p.bestStreak, 1);
    });

    test('duplicate logs on same day count as 1 day', () {
      final p = GoalProgress(
        target: _freqTarget(1),
        logs: [
          _log('a', DateTime(2026, 1, 1, 8, 0)),
          _log('b', DateTime(2026, 1, 1, 20, 0)),
          _log('c', DateTime(2026, 1, 2)),
        ],
      );
      expect(p.bestStreak, 2);
    });
  });

  group('GoalProgress — date queries', () {
    test('hasLogOnDate finds log', () {
      final p = GoalProgress(
        target: _freqTarget(1),
        logs: [_log('a', DateTime(2026, 3, 5, 14, 30))],
      );
      expect(p.hasLogOnDate(DateTime(2026, 3, 5)), isTrue);
      expect(p.hasLogOnDate(DateTime(2026, 3, 6)), isFalse);
    });

    test('logsOnDate returns matching logs', () {
      final p = GoalProgress(
        target: _freqTarget(1),
        logs: [
          _log('a', DateTime(2026, 3, 5, 10, 0)),
          _log('b', DateTime(2026, 3, 5, 20, 0)),
          _log('c', DateTime(2026, 3, 6)),
        ],
      );
      expect(p.logsOnDate(DateTime(2026, 3, 5)), hasLength(2));
    });

    test('monthlySum', () {
      final p = GoalProgress(
        target: _totalTarget(100),
        logs: [
          _log('a', DateTime(2026, 1, 15), 10),
          _log('b', DateTime(2026, 1, 20), 5),
          _log('c', DateTime(2026, 2, 1), 20),
        ],
      );
      expect(p.monthlySum(2026, 1), 15.0);
      expect(p.monthlySum(2026, 2), 20.0);
      expect(p.monthlySum(2026, 3), 0.0);
    });

    test('yearlySum', () {
      final p = GoalProgress(
        target: _totalTarget(100),
        logs: [
          _log('a', DateTime(2025, 12, 31), 5),
          _log('b', DateTime(2026, 1, 1), 10),
        ],
      );
      expect(p.yearlySum(2025), 5.0);
      expect(p.yearlySum(2026), 10.0);
    });
  });

  group('GoalProgress — immutable updates', () {
    test('addLog returns new instance with log', () {
      final p = GoalProgress(target: _freqTarget(1), logs: []);
      final updated = p.addLog(_log('a', DateTime(2026, 1, 1)));
      expect(updated.logs, hasLength(1));
      expect(p.logs, isEmpty); // original unchanged
    });

    test('removeLog removes by id', () {
      final p = GoalProgress(
        target: _freqTarget(1),
        logs: [_log('a', DateTime(2026, 1, 1)), _log('b', DateTime(2026, 1, 2))],
      );
      final updated = p.removeLog('a');
      expect(updated.logs, hasLength(1));
      expect(updated.logs.first.id, 'b');
    });

    test('updateLog replaces by id', () {
      final original = _log('a', DateTime(2026, 1, 1), 1.0);
      final p = GoalProgress(target: _freqTarget(1), logs: [original]);
      final replacement = original.copyWith(value: 5.0);
      final updated = p.updateLog('a', replacement);
      expect(updated.logs.first.value, 5.0);
    });

    test('toggleDate adds log when empty', () {
      final p = GoalProgress(target: _freqTarget(1), logs: []);
      int idCounter = 0;
      final updated = p.toggleDate(
        DateTime(2026, 3, 5),
        generateId: () => 'gen_${idCounter++}',
      );
      expect(updated.logs, hasLength(1));
      expect(updated.logs.first.value, 1.0);
    });

    test('toggleDate removes log when exists', () {
      final p = GoalProgress(
        target: _freqTarget(1),
        logs: [_log('a', DateTime(2026, 3, 5))],
      );
      final updated = p.toggleDate(
        DateTime(2026, 3, 5),
        generateId: () => 'unused',
      );
      expect(updated.logs, isEmpty);
    });

    test('toggleDate is idempotent (toggle on, toggle off)', () {
      final p = GoalProgress(target: _freqTarget(1), logs: []);
      int counter = 0;
      final date = DateTime(2026, 3, 5);

      final added = p.toggleDate(date, generateId: () => 'g${counter++}');
      expect(added.logs, hasLength(1));

      final removed = added.toggleDate(date, generateId: () => 'g${counter++}');
      expect(removed.logs, isEmpty);
    });
  });

  group('GoalProgress — logs are sorted', () {
    test('logs are sorted by date regardless of insert order', () {
      final p = GoalProgress(
        target: _freqTarget(1),
        logs: [
          _log('c', DateTime(2026, 3, 3)),
          _log('a', DateTime(2026, 3, 1)),
          _log('b', DateTime(2026, 3, 2)),
        ],
      );
      expect(p.logs[0].id, 'a');
      expect(p.logs[1].id, 'b');
      expect(p.logs[2].id, 'c');
    });
  });

  group('GoalProgress equality', () {
    test('same target and logs are equal', () {
      final logs = [_log('a', DateTime(2026, 1, 1))];
      final a = GoalProgress(target: _freqTarget(3), logs: List.from(logs));
      final b = GoalProgress(target: _freqTarget(3), logs: List.from(logs));
      expect(a, b);
    });

    test('different logs are not equal', () {
      final a = GoalProgress(target: _freqTarget(3), logs: [_log('a', DateTime(2026, 1, 1))]);
      final b = GoalProgress(target: _freqTarget(3), logs: [_log('b', DateTime(2026, 1, 2))]);
      expect(a, isNot(b));
    });
  });

  group('GoalProgress.toString()', () {
    test('includes mode, log count, and completion', () {
      final p = GoalProgress(
        target: _totalTarget(100),
        logs: [_log('a', DateTime(2026, 1, 1), 25)],
      );
      expect(p.toString(), contains('total'));
      expect(p.toString(), contains('25.0%'));
    });
  });

  group('GoalProgress — frequency score-average', () {
    GoalTarget freqWithDates(int timesPerWeek, DateTime start, DateTime end) =>
        GoalTarget(
          mode: GoalTargetMode.frequency,
          timesPerWeek: timesPerWeek,
          startDate: start,
          endDate: end,
        );

    test('timesPerWeek=2, 4 weeks, 8 checks => 100%', () {
      // 4 weeks: Mon 2026-01-05 to Sun 2026-02-01
      final start = DateTime(2026, 1, 5); // Monday
      final end = DateTime(2026, 2, 1);   // Sunday
      final logs = <GoalLog>[
        // Week 1 (Jan 5–11): 2 days
        _log('w1a', DateTime(2026, 1, 5)),
        _log('w1b', DateTime(2026, 1, 7)),
        // Week 2 (Jan 12–18): 2 days
        _log('w2a', DateTime(2026, 1, 12)),
        _log('w2b', DateTime(2026, 1, 14)),
        // Week 3 (Jan 19–25): 2 days
        _log('w3a', DateTime(2026, 1, 19)),
        _log('w3b', DateTime(2026, 1, 21)),
        // Week 4 (Jan 26–Feb 1): 2 days
        _log('w4a', DateTime(2026, 1, 26)),
        _log('w4b', DateTime(2026, 1, 28)),
      ];
      final p = GoalProgress(
        target: freqWithDates(2, start, end),
        logs: logs,
      );
      expect(p.completionPercent, closeTo(100.0, 0.01));
    });

    test('timesPerWeek=2, 4 weeks, 4 checks (1/week) => 50%', () {
      final start = DateTime(2026, 1, 5);
      final end = DateTime(2026, 2, 1);
      final logs = <GoalLog>[
        // Each week has 1 check out of 2 needed → score 0.5 each
        _log('w1', DateTime(2026, 1, 5)),
        _log('w2', DateTime(2026, 1, 12)),
        _log('w3', DateTime(2026, 1, 19)),
        _log('w4', DateTime(2026, 1, 26)),
      ];
      final p = GoalProgress(
        target: freqWithDates(2, start, end),
        logs: logs,
      );
      expect(p.completionPercent, closeTo(50.0, 0.01));
    });

    test('month boundary partial weeks scored correctly', () {
      // Jan 26 (Mon) to Feb 8 (Sun) = 2 full weeks
      // But start from Jan 29 (Thu) — still falls in week of Jan 26
      final start = DateTime(2026, 1, 29); // Thursday
      final end = DateTime(2026, 2, 8);    // Sunday
      // Week 1 (Jan 26–Feb 1): 1 check → score 0.5
      // Week 2 (Feb 2–Feb 8): 2 checks → score 1.0
      final logs = <GoalLog>[
        _log('a', DateTime(2026, 1, 30)),
        _log('b', DateTime(2026, 2, 3)),
        _log('c', DateTime(2026, 2, 5)),
      ];
      final p = GoalProgress(
        target: freqWithDates(2, start, end),
        logs: logs,
      );
      // 2 weeks: (0.5 + 1.0) / 2 = 0.75 → 75%
      expect(p.completionPercent, closeTo(75.0, 0.01));
    });
  });
}
