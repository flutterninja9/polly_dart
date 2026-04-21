import 'cancellation_token.dart';

export 'cancellation_token.dart';

class ResilienceContext {
  final Map<String, Object?> _properties = {};
  final CancellationToken _token = CancellationToken();
  int _attemptNumber = 0;

  String? operationKey;

  ResilienceContext({this.operationKey});

  CancellationToken get cancellationToken => _token;

  ResilienceContext copy() {
    final child = ResilienceContext(operationKey: operationKey);
    child._properties.addAll(_properties);
    child._attemptNumber = _attemptNumber;
    if (_token.isCancelled) {
      child._token.cancel();
    } else {
      _token.whenCancelled.then((_) => child._token.cancel());
    }
    return child;
  }

  int get attemptNumber => _attemptNumber;

  void incrementAttemptNumber() => _attemptNumber++;

  void setAttemptNumber(int value) => _attemptNumber = value;

  bool get isCancellationRequested => _token.isCancelled;

  Future<void> get cancellationFuture => _token.whenCancelled;

  void cancel() => _token.cancel();

  void throwIfCancellationRequested() => _token.throwIfCancelled();

  void setProperty<T>(String key, T value) => _properties[key] = value;

  T? getProperty<T>(String key) {
    final value = _properties[key];
    return value is T ? value : null;
  }

  bool hasProperty(String key) => _properties.containsKey(key);

  void removeProperty(String key) => _properties.remove(key);

  Iterable<String> get propertyKeys => _properties.keys;

  void clearProperties() => _properties.clear();

  @override
  String toString() {
    return 'ResilienceContext(operationKey: $operationKey, attemptNumber: $_attemptNumber, '
        'isCancelled: ${_token.isCancelled}, properties: ${_properties.length})';
  }
}
