import 'dart:async';

import '../outcome.dart';
import '../resilience_context.dart';
import '../strategy.dart';

/// Configuration options for the timeout strategy.
class TimeoutStrategyOptions {
  /// The timeout duration.
  final Duration timeout;

  /// Generator for dynamic timeout values.
  final TimeoutGenerator? timeoutGenerator;

  /// Callback invoked when a timeout occurs.
  final OnTimeoutCallback? onTimeout;

  /// Creates timeout strategy options with a fixed timeout.
  const TimeoutStrategyOptions({
    required this.timeout,
    this.timeoutGenerator,
    this.onTimeout,
  });

  /// Creates timeout strategy options with a timeout generator.
  const TimeoutStrategyOptions.withGenerator({
    required this.timeoutGenerator,
    this.onTimeout,
  }) : timeout = Duration.zero;
}

/// Signature for timeout generator functions.
typedef TimeoutGenerator = Future<Duration> Function(
    TimeoutGeneratorArguments args);

/// Signature for timeout callback functions.
typedef OnTimeoutCallback = Future<void> Function(OnTimeoutArguments args);

/// Arguments passed to timeout generator functions.
class TimeoutGeneratorArguments {
  /// The resilience context.
  final ResilienceContext context;

  const TimeoutGeneratorArguments({
    required this.context,
  });
}

/// Arguments passed to timeout callback functions.
class OnTimeoutArguments {
  /// The resilience context.
  final ResilienceContext context;

  /// The timeout duration that was exceeded.
  final Duration timeout;

  const OnTimeoutArguments({
    required this.context,
    required this.timeout,
  });
}

/// Exception thrown when an operation times out.
class TimeoutRejectedException implements Exception {
  final String message;
  final Duration timeout;

  const TimeoutRejectedException(this.timeout,
      [this.message = 'The operation timed out']);

  @override
  String toString() => 'TimeoutRejectedException: $message (timeout: $timeout)';
}

/// Timeout resilience strategy implementation.
class TimeoutStrategy extends ResilienceStrategy {
  final TimeoutStrategyOptions _options;

  /// Creates a timeout strategy with the specified options.
  TimeoutStrategy(this._options);

  @override
  Future<Outcome<T>> executeCore<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
  ) async {
    // Determine the timeout duration
    Duration timeout;
    if (_options.timeoutGenerator != null) {
      timeout = await _options.timeoutGenerator!(TimeoutGeneratorArguments(
        context: context,
      ));
    } else {
      timeout = _options.timeout;
    }

    // If timeout is zero or negative, execute without timeout
    if (timeout <= Duration.zero) {
      try {
        final result = await callback(context);
        return Outcome.fromResult(result);
      } catch (exception, stackTrace) {
        return Outcome.fromException(exception, stackTrace);
      }
    }

    // Create a completer for the timeout
    final timeoutCompleter = Completer<void>();
    final timer = Timer(timeout, () {
      if (!timeoutCompleter.isCompleted) {
        timeoutCompleter.complete();
      }
    });

    try {
      // Race between the callback and the timeout
      final List<Future<Outcome<T>>> futures = [
        _executeCallback(callback, context),
        _createTimeoutFuture<T>(timeoutCompleter.future, timeout, context),
      ];

      final result = await Future.any(futures);
      return result;
    } finally {
      timer.cancel();
    }
  }

  /// Executes the callback and wraps the result in an Outcome.
  Future<Outcome<T>> _executeCallback<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
  ) async {
    try {
      final result = await callback(context);
      return Outcome.fromResult(result);
    } catch (exception, stackTrace) {
      return Outcome.fromException(exception, stackTrace);
    }
  }

  /// Creates a future that throws a timeout exception when the timeout completes.
  Future<Outcome<T>> _createTimeoutFuture<T>(
    Future<void> timeoutFuture,
    Duration timeout,
    ResilienceContext context,
  ) async {
    await timeoutFuture;

    // Invoke onTimeout callback
    if (_options.onTimeout != null) {
      try {
        await _options.onTimeout!(OnTimeoutArguments(
          context: context,
          timeout: timeout,
        ));
      } catch (_) {
        // Ignore exceptions from the callback
      }
    }

    // Cancel the context to signal timeout to the callback
    context.cancel();

    return Outcome<T>.fromException(
      TimeoutRejectedException(timeout),
      StackTrace.current,
    );
  }
}
