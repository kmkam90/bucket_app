import '../utils/date_utils.dart' as app_dates;

/// A single progress entry for a goal.
///
/// Replaces the old [LogEntry] with richer data:
/// - [double] value for precision (supports 5.3 km, 1.5 hours, etc.)
/// - optional [note] for user context
/// - unique [id] for reliable deletion/editing
/// - [createdAt] timestamp separate from the logical [date]
///
/// [date] is always normalized to local midnight via [app_dates.dateOnly].
class GoalLog {
  final String id;
  final DateTime date;
  final double value;
  final String? note;
  final DateTime createdAt;

  GoalLog({
    required this.id,
    required DateTime date,
    required this.value,
    this.note,
    DateTime? createdAt,
  })  : assert(id.isNotEmpty, 'id must not be empty'),
        date = app_dates.dateOnly(date),
        createdAt = createdAt ?? DateTime.now();

  /// Convenience: habit completion log (value = 1.0).
  factory GoalLog.habit({
    required String id,
    required DateTime date,
    String? note,
  }) =>
      GoalLog(id: id, date: date, value: 1.0, note: note);

  /// Convenience: incremental progress log (e.g., +5 km, +30 min).
  factory GoalLog.increment({
    required String id,
    required DateTime date,
    required double amount,
    String? note,
  }) {
    assert(amount > 0, 'increment amount must be positive');
    return GoalLog(id: id, date: date, value: amount, note: note);
  }

  GoalLog copyWith({
    String? id,
    DateTime? date,
    double? value,
    String? note,
    DateTime? createdAt,
  }) {
    return GoalLog(
      id: id ?? this.id,
      date: date ?? this.date,
      value: value ?? this.value,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────────

  factory GoalLog.fromJson(Map<String, dynamic> json) {
    final parsed = DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now();
    return GoalLog(
      id: (json['id'] as String?) ?? '',
      date: parsed, // constructor normalizes via dateOnly
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      note: json['note'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  /// Backward-compatible: reads old LogEntry JSON (date + int value).
  factory GoalLog.fromLegacyJson(Map<String, dynamic> json) {
    final parsed = DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now();
    return GoalLog(
      id: 'legacy_${parsed.millisecondsSinceEpoch}',
      date: parsed, // constructor normalizes via dateOnly
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Serializes date as date-only ISO string (no time component).
  Map<String, dynamic> toJson() => {
        'id': id,
        'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'value': value,
        if (note != null) 'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  // ─── Equality ───────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalLog &&
          id == other.id &&
          date == other.date &&
          value == other.value &&
          note == other.note;

  @override
  int get hashCode => Object.hash(id, date, value, note);

  @override
  String toString() => 'GoalLog(id: $id, date: $date, value: $value)';
}
