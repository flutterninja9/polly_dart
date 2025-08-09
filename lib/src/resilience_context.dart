import 'dart:async';

/// Context that carries metadata through resilience pipeline execution.
///
/// This context is used to track information such as attempt counts,
/// cancellation state, and user-defined properties across strategy executions.
class ResilienceContext {
  final Map<String, Object?> _properties = {};
  final Completer<void> _cancellationCompleter = Completer<void>();
  bool _isCancelled = false;
  int _attemptNumber = 0;

  /// The operation key that identifies the operation being executed.
  String? operationKey;

  /// Creates a new resilience context.
  ResilienceContext({this.operationKey});

  /// Creates a copy of this context for use in parallel operations like hedging.
  ResilienceContext copy() {
    final copy = ResilienceContext(operationKey: operationKey);
    copy._properties.addAll(_properties);
    copy._attemptNumber = _attemptNumber;

    // If this context is already cancelled, cancel the copy too
    if (_isCancelled) {
      copy.cancel();
    }

    return copy;
  }

  /// Gets the current attempt number (zero-based).
  int get attemptNumber => _attemptNumber;

  /// Increments the attempt number.
  void incrementAttemptNumber() {
    _attemptNumber++;
  }

  /// Sets the attempt number to a specific value.
  void setAttemptNumber(int value) {
    _attemptNumber = value;
  }

  /// Returns true if cancellation has been requested.
  bool get isCancellationRequested => _isCancelled;

  /// A future that completes when cancellation is requested.
  Future<void> get cancellationFuture => _cancellationCompleter.future;

  /// Requests cancellation of the operation.
  void cancel() {
    if (!_isCancelled) {
      _isCancelled = true;
      if (!_cancellationCompleter.isCompleted) {
        _cancellationCompleter.complete();
      }
    }
  }

  /// Throws an exception if cancellation has been requested.
  void throwIfCancellationRequested() {
    if (_isCancelled) {
      throw OperationCancelledException();
    }
  }

  /// Sets a property in the context.
  void setProperty<T>(String key, T value) {
    _properties[key] = value;
  }

  /// Gets a property from the context.
  T? getProperty<T>(String key) {
    final value = _properties[key];
    return value is T ? value : null;
  }

  /// Checks if a property exists in the context.
  bool hasProperty(String key) {
    return _properties.containsKey(key);
  }

  /// Removes a property from the context.
  void removeProperty(String key) {
    _properties.remove(key);
  }

  /// Gets all property keys.
  Iterable<String> get propertyKeys => _properties.keys;

  /// Clears all properties.
  void clearProperties() {
    _properties.clear();
  }

  @override
  String toString() {
    return 'ResilienceContext(operationKey: $operationKey, attemptNumber: $_attemptNumber, '
        'isCancelled: $_isCancelled, properties: ${_properties.length})';
  }
}

/// Exception thrown when an operation is cancelled.
class OperationCancelledException implements Exception {
  final String message;

  const OperationCancelledException(
      [this.message = 'The operation was cancelled']);

  @override
  String toString() => 'OperationCancelledException: $message';
}
