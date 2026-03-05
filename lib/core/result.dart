/// A simple Result type for operations that can fail.
///
/// Every storage/service operation returns Result instead of throwing
/// or silently swallowing errors. UI can pattern-match to show
/// appropriate feedback.
sealed class Result<T> {
  const Result();
}

class Ok<T> extends Result<T> {
  final T data;
  final List<String> warnings;
  const Ok(this.data, {this.warnings = const []});
}

class Err<T> extends Result<T> {
  final String message;
  final Object? error;
  const Err(this.message, {this.error});
}
