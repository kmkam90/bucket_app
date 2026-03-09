/// Typed application error with codes for programmatic handling.
///
/// Replaces raw `String? lastError` with structured errors that support:
/// - Error code matching (retry logic, UI branching)
/// - Deduplication (same code within cooldown window → suppressed)
/// - Debug history (ring buffer of recent errors)
enum AppErrorCode {
  writeFailed,
  writeVerifyFailed,
  loadFailed,
  importFailed,
  importTooLarge,
  importParseFailed,
  migrationFailed,
  unknown,
}

class AppError {
  final AppErrorCode code;
  final String message;
  final DateTime timestamp;
  final Object? cause;

  AppError({
    required this.code,
    required this.message,
    this.cause,
  }) : timestamp = DateTime.now();

  /// Whether this error has the same code as another (for deduplication).
  bool sameCodeAs(AppError other) => code == other.code;

  @override
  String toString() {
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
    final causePart = cause != null ? ', cause: $cause' : '';
    return 'AppError(${code.name}, message: "$message", time: $time$causePart)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppError && code == other.code && message == other.message;

  @override
  int get hashCode => Object.hash(code, message);
}

/// Fixed-size ring buffer that keeps the N most recent errors.
class ErrorHistory {
  final int maxSize;
  final List<AppError> _buffer = [];

  ErrorHistory({this.maxSize = 20});

  void add(AppError error) {
    _buffer.add(error);
    if (_buffer.length > maxSize) {
      _buffer.removeAt(0);
    }
  }

  List<AppError> get all => List.unmodifiable(_buffer);

  int get length => _buffer.length;

  bool get isEmpty => _buffer.isEmpty;

  void clear() => _buffer.clear();

  /// Most recent error, or null.
  AppError? get latest => _buffer.isEmpty ? null : _buffer.last;

  @override
  String toString() =>
      'ErrorHistory(${_buffer.length}/$maxSize: ${_buffer.map((e) => e.code.name).join(', ')})';
}
