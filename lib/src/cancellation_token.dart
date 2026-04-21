import 'dart:async';

class CancellationToken {
  bool _cancelled = false;
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _cancelled;

  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_cancelled) {
      _cancelled = true;
      _completer.complete();
    }
  }

  void throwIfCancelled() {
    if (_cancelled) throw const OperationCancelledException();
  }
}

class OperationCancelledException implements Exception {
  final String message;

  const OperationCancelledException(
      [this.message = 'The operation was cancelled']);

  @override
  String toString() => 'OperationCancelledException: $message';
}
