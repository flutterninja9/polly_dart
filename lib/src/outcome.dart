/// Represents the outcome of an operation, either a successful result or an exception.
///
/// This type is used by resilience strategies to inspect whether an operation
/// succeeded or failed, and to decide how to handle the situation.
sealed class Outcome<T> {
  const Outcome._();

  /// Creates an outcome representing a successful result.
  const factory Outcome.fromResult(T result) = _ResultOutcome<T>;

  /// Creates an outcome representing an exception.
  const factory Outcome.fromException(Object exception,
      [StackTrace? stackTrace]) = _ExceptionOutcome<T>;

  /// Returns true if this outcome represents a successful result.
  bool get hasResult;

  /// Returns true if this outcome represents an exception.
  bool get hasException => !hasResult;

  /// Gets the result value. Throws if this outcome represents an exception.
  T get result;

  /// Gets the exception. Throws if this outcome represents a successful result.
  Object get exception;

  /// Gets the stack trace. May be null.
  StackTrace? get stackTrace;

  /// Rethrows the exception if this outcome represents one.
  void throwIfException() {
    if (hasException) {
      Error.throwWithStackTrace(exception, stackTrace ?? StackTrace.current);
    }
  }

  /// Converts this outcome to a Future.
  Future<T> asFuture() {
    if (hasResult) {
      return Future.value(result);
    } else {
      return Future.error(exception, stackTrace);
    }
  }

  /// Converts this outcome to a ValueTask-like representation.
  static Future<Outcome<T>> fromFuture<T>(Future<T> future) async {
    try {
      final result = await future;
      return Outcome.fromResult(result);
    } catch (exception, stackTrace) {
      return Outcome.fromException(exception, stackTrace);
    }
  }

  @override
  String toString() {
    if (hasResult) {
      return 'Outcome.result($result)';
    } else {
      return 'Outcome.exception($exception)';
    }
  }
}

final class _ResultOutcome<T> extends Outcome<T> {
  final T _result;

  const _ResultOutcome(this._result) : super._();

  @override
  bool get hasResult => true;

  @override
  T get result => _result;

  @override
  Object get exception =>
      throw StateError('Outcome represents a result, not an exception');

  @override
  StackTrace? get stackTrace => null;

  @override
  bool operator ==(Object other) {
    return other is _ResultOutcome<T> && _result == other._result;
  }

  @override
  int get hashCode => _result.hashCode;
}

final class _ExceptionOutcome<T> extends Outcome<T> {
  final Object _exception;
  final StackTrace? _stackTrace;

  const _ExceptionOutcome(this._exception, [this._stackTrace]) : super._();

  @override
  bool get hasResult => false;

  @override
  T get result =>
      throw StateError('Outcome represents an exception, not a result');

  @override
  Object get exception => _exception;

  @override
  StackTrace? get stackTrace => _stackTrace;

  @override
  bool operator ==(Object other) {
    return other is _ExceptionOutcome<T> &&
        _exception == other._exception &&
        _stackTrace == other._stackTrace;
  }

  @override
  int get hashCode => Object.hash(_exception, _stackTrace);
}
