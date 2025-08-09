import 'dart:async';

import '../outcome.dart';
import '../resilience_context.dart';
import '../strategy.dart';

/// Configuration options for the circuit breaker strategy.
class CircuitBreakerStrategyOptions<T> {
  /// The failure ratio that triggers the circuit to open (default: 0.5).
  final double failureRatio;

  /// The sampling duration for calculating failure ratio (default: 30 seconds).
  final Duration samplingDuration;

  /// The minimum number of actions that must be processed before the circuit can open (default: 10).
  final int minimumThroughput;

  /// The duration the circuit stays open before transitioning to half-open (default: 5 seconds).
  final Duration breakDuration;

  /// Generator for dynamic break duration.
  final BreakDurationGenerator<T>? breakDurationGenerator;

  /// Predicate to determine which outcomes should be considered failures.
  final ShouldHandlePredicate<T>? shouldHandle;

  /// Provider for monitoring circuit state.
  final CircuitBreakerStateProvider? stateProvider;

  /// Manual control for the circuit breaker.
  final CircuitBreakerManualControl? manualControl;

  /// Callback invoked when the circuit state changes.
  final OnCircuitOpened<T>? onOpened;
  final OnCircuitClosed<T>? onClosed;
  final OnCircuitHalfOpened<T>? onHalfOpened;

  /// Creates circuit breaker strategy options.
  const CircuitBreakerStrategyOptions({
    this.failureRatio = 0.5,
    this.samplingDuration = const Duration(seconds: 30),
    this.minimumThroughput = 10,
    this.breakDuration = const Duration(seconds: 5),
    this.breakDurationGenerator,
    this.shouldHandle,
    this.stateProvider,
    this.manualControl,
    this.onOpened,
    this.onClosed,
    this.onHalfOpened,
  });
}

/// Signature for break duration generator functions.
typedef BreakDurationGenerator<T> = Future<Duration> Function(
    BreakDurationGeneratorArguments<T> args);

/// Arguments passed to break duration generator functions.
class BreakDurationGeneratorArguments<T> {
  /// The current failure count.
  final int failureCount;

  /// The resilience context.
  final ResilienceContext context;

  const BreakDurationGeneratorArguments({
    required this.failureCount,
    required this.context,
  });
}

/// Callback signatures for circuit state changes.
typedef OnCircuitOpened<T> = Future<void> Function(
    OnCircuitOpenedArguments<T> args);
typedef OnCircuitClosed<T> = Future<void> Function(
    OnCircuitClosedArguments<T> args);
typedef OnCircuitHalfOpened<T> = Future<void> Function(
    OnCircuitHalfOpenedArguments<T> args);

/// Arguments for circuit state change callbacks.
class OnCircuitOpenedArguments<T> {
  final CircuitState previousState;
  final ResilienceContext context;
  final Duration breakDuration;

  const OnCircuitOpenedArguments({
    required this.previousState,
    required this.context,
    required this.breakDuration,
  });
}

class OnCircuitClosedArguments<T> {
  final CircuitState previousState;
  final ResilienceContext context;

  const OnCircuitClosedArguments({
    required this.previousState,
    required this.context,
  });
}

class OnCircuitHalfOpenedArguments<T> {
  final CircuitState previousState;
  final ResilienceContext context;

  const OnCircuitHalfOpenedArguments({
    required this.previousState,
    required this.context,
  });
}

/// Possible states of the circuit breaker.
enum CircuitState {
  /// Normal operation; actions are executed.
  closed,

  /// Circuit is open; actions are blocked.
  open,

  /// Recovery state after break duration expires; actions are permitted.
  halfOpen,

  /// Circuit is manually held open; actions are blocked.
  isolated,
}

/// Provides access to the current circuit breaker state.
class CircuitBreakerStateProvider {
  CircuitState _state = CircuitState.closed;

  /// Gets the current circuit state.
  CircuitState get circuitState => _state;

  void _setState(CircuitState newState) {
    _state = newState;
  }
}

/// Provides manual control over the circuit breaker.
class CircuitBreakerManualControl {
  final Completer<void> _isolateCompleter = Completer<void>();
  final Completer<void> _closeCompleter = Completer<void>();
  bool _isIsolated = false;
  bool _isManuallyClosing = false;

  /// Manually isolates the circuit, preventing all executions.
  Future<void> isolateAsync() async {
    _isIsolated = true;
    if (!_isolateCompleter.isCompleted) {
      _isolateCompleter.complete();
    }
  }

  /// Manually closes the circuit, allowing executions to resume.
  Future<void> closeAsync() async {
    _isIsolated = false;
    _isManuallyClosing = true;
    if (!_closeCompleter.isCompleted) {
      _closeCompleter.complete();
    }
  }

  bool get isIsolated => _isIsolated;
  bool get isManuallyClosing => _isManuallyClosing;

  void _resetManualClose() {
    _isManuallyClosing = false;
  }
}

/// Exception thrown when the circuit breaker is open.
class CircuitBreakerRejectedException implements Exception {
  final String message;
  final CircuitState circuitState;

  const CircuitBreakerRejectedException(this.circuitState,
      [this.message = 'The circuit breaker is open']);

  @override
  String toString() =>
      'CircuitBreakerRejectedException: $message (state: $circuitState)';
}

/// Tracks execution statistics for the circuit breaker.
class _ExecutionStats {
  final List<_ExecutionRecord> _records = [];

  void recordExecution(bool isSuccess, DateTime timestamp) {
    _records.add(_ExecutionRecord(isSuccess, timestamp));
  }

  void cleanOldRecords(DateTime cutoff) {
    _records.removeWhere((record) => record.timestamp.isBefore(cutoff));
  }

  int get totalCount => _records.length;
  int get failureCount => _records.where((r) => !r.isSuccess).length;
  int get successCount => _records.where((r) => r.isSuccess).length;

  double get failureRatio => totalCount == 0 ? 0.0 : failureCount / totalCount;
}

class _ExecutionRecord {
  final bool isSuccess;
  final DateTime timestamp;

  _ExecutionRecord(this.isSuccess, this.timestamp);
}

/// Circuit breaker resilience strategy implementation.
class CircuitBreakerStrategy extends ResilienceStrategy {
  final CircuitBreakerStrategyOptions _options;
  final _ExecutionStats _stats = _ExecutionStats();
  CircuitState _state = CircuitState.closed;
  DateTime? _breakEndTime;
  int _failureCount = 0;

  /// Creates a circuit breaker strategy with the specified options.
  CircuitBreakerStrategy(this._options) {
    _options.stateProvider?._setState(_state);
  }

  @override
  Future<Outcome<T>> executeCore<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
  ) async {
    final shouldHandle = _options.shouldHandle as ShouldHandlePredicate<T>? ??
        PredicateHelper.handleAllExceptions<T>();

    // Handle manual control
    if (_options.manualControl?.isIsolated == true) {
      _setState(CircuitState.isolated);
      return Outcome<T>.fromException(
        CircuitBreakerRejectedException(_state),
        StackTrace.current,
      );
    }

    if (_options.manualControl?.isManuallyClosing == true) {
      _setState(CircuitState.closed);
      _options.manualControl!._resetManualClose();
      _resetStats();
    }

    // Clean old records
    final cutoff = DateTime.now().subtract(_options.samplingDuration);
    _stats.cleanOldRecords(cutoff);

    // Check circuit state
    await _updateCircuitState();

    if (_state == CircuitState.open || _state == CircuitState.isolated) {
      return Outcome<T>.fromException(
        CircuitBreakerRejectedException(_state),
        StackTrace.current,
      );
    }

    // Execute the callback
    Outcome<T> outcome;
    try {
      final result = await callback(context);
      outcome = Outcome.fromResult(result);
    } catch (exception, stackTrace) {
      outcome = Outcome.fromException(exception, stackTrace);
    }

    // Record the execution
    final isSuccess = !shouldHandle(outcome);
    _stats.recordExecution(isSuccess, DateTime.now());

    if (!isSuccess) {
      _failureCount++;
    }

    // Update circuit state based on the result
    await _updateCircuitStateAfterExecution(context, isSuccess);

    return outcome;
  }

  Future<void> _updateCircuitState() async {
    if (_state == CircuitState.open && _breakEndTime != null) {
      if (DateTime.now().isAfter(_breakEndTime!)) {
        await _transitionToHalfOpen();
      }
    }
  }

  Future<void> _updateCircuitStateAfterExecution(
      ResilienceContext context, bool isSuccess) async {
    if (_state == CircuitState.halfOpen) {
      if (isSuccess) {
        await _transitionToClosed(context);
      } else {
        await _transitionToOpen(context);
      }
    } else if (_state == CircuitState.closed) {
      if (_shouldOpen()) {
        await _transitionToOpen(context);
      }
    }
  }

  bool _shouldOpen() {
    return _stats.totalCount >= _options.minimumThroughput &&
        _stats.failureRatio >= _options.failureRatio;
  }

  Future<void> _transitionToOpen(ResilienceContext context) async {
    final previousState = _state;
    _setState(CircuitState.open);

    // Calculate break duration
    Duration breakDuration;
    if (_options.breakDurationGenerator != null) {
      breakDuration = await (_options.breakDurationGenerator!)(
        BreakDurationGeneratorArguments(
          failureCount: _failureCount,
          context: context,
        ),
      );
    } else {
      breakDuration = _options.breakDuration;
    }

    _breakEndTime = DateTime.now().add(breakDuration);

    // Invoke callback
    if (_options.onOpened != null) {
      await (_options.onOpened!)(OnCircuitOpenedArguments(
        previousState: previousState,
        context: context,
        breakDuration: breakDuration,
      ));
    }
  }

  Future<void> _transitionToClosed(ResilienceContext context) async {
    final previousState = _state;
    _setState(CircuitState.closed);
    _resetStats();

    // Invoke callback
    if (_options.onClosed != null) {
      await (_options.onClosed!)(OnCircuitClosedArguments(
        previousState: previousState,
        context: context,
      ));
    }
  }

  Future<void> _transitionToHalfOpen() async {
    _setState(CircuitState.halfOpen);

    // Note: We don't have a context here, so we pass a new one
    if (_options.onHalfOpened != null) {
      await (_options.onHalfOpened!)(OnCircuitHalfOpenedArguments(
        previousState: CircuitState.open,
        context: ResilienceContext(),
      ));
    }
  }

  void _setState(CircuitState newState) {
    _state = newState;
    _options.stateProvider?._setState(newState);
  }

  void _resetStats() {
    _stats._records.clear();
    _failureCount = 0;
    _breakEndTime = null;
  }
}
