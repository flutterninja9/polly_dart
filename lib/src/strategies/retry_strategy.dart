import 'dart:async';
import 'dart:math' as math;

import '../outcome.dart';
import '../resilience_context.dart';
import '../strategy.dart';

/// Configuration options for the retry strategy.
class RetryStrategyOptions<T> {
  /// Maximum number of retry attempts (default: 3).
  final int maxRetryAttempts;

  /// Base delay between retry attempts (default: 1 second).
  final Duration delay;

  /// The type of backoff to use between retries (default: exponential).
  final DelayBackoffType backoffType;

  /// Whether to add jitter to the delay (default: false).
  final bool useJitter;

  /// Maximum delay between retries (default: 30 seconds).
  final Duration maxDelay;

  /// Predicate to determine which outcomes should be retried.
  final ShouldHandlePredicate<T>? shouldHandle;

  /// Generator for custom delay logic.
  final DelayGenerator<T>? delayGenerator;

  /// Callback invoked when a retry is about to be performed.
  final OnRetryCallback<T>? onRetry;

  /// Creates retry strategy options.
  const RetryStrategyOptions({
    this.maxRetryAttempts = 3,
    this.delay = const Duration(seconds: 1),
    this.backoffType = DelayBackoffType.exponential,
    this.useJitter = false,
    this.maxDelay = const Duration(seconds: 30),
    this.shouldHandle,
    this.delayGenerator,
    this.onRetry,
  });

  /// Creates retry options with no delay.
  const RetryStrategyOptions.noDelay({
    this.maxRetryAttempts = 3,
    this.backoffType = DelayBackoffType.constant,
    this.useJitter = false,
    this.maxDelay = Duration.zero,
    this.shouldHandle,
    this.delayGenerator,
    this.onRetry,
  }) : delay = Duration.zero;

  /// Creates retry options for immediate retries.
  const RetryStrategyOptions.immediate({
    this.maxRetryAttempts = 3,
    this.shouldHandle,
    this.onRetry,
  })  : delay = Duration.zero,
        backoffType = DelayBackoffType.constant,
        useJitter = false,
        maxDelay = Duration.zero,
        delayGenerator = null;

  /// Creates retry options with infinite retries.
  const RetryStrategyOptions.infinite({
    this.delay = const Duration(seconds: 1),
    this.backoffType = DelayBackoffType.exponential,
    this.useJitter = false,
    this.maxDelay = const Duration(seconds: 30),
    this.shouldHandle,
    this.delayGenerator,
    this.onRetry,
  }) : maxRetryAttempts = 0x7FFFFFFF; // int.maxValue equivalent
}

/// Types of delay backoff strategies.
enum DelayBackoffType {
  /// Constant delay between retries.
  constant,

  /// Linear increase in delay between retries.
  linear,

  /// Exponential increase in delay between retries.
  exponential,
}

/// Signature for delay generator functions.
typedef DelayGenerator<T> = Future<Duration?> Function(
    DelayGeneratorArguments<T> args);

/// Signature for retry callback functions.
typedef OnRetryCallback<T> = Future<void> Function(OnRetryArguments<T> args);

/// Arguments passed to delay generator functions.
class DelayGeneratorArguments<T> {
  /// The current attempt number (zero-based).
  final int attemptNumber;

  /// The outcome of the failed attempt.
  final Outcome<T> outcome;

  /// The resilience context.
  final ResilienceContext context;

  const DelayGeneratorArguments({
    required this.attemptNumber,
    required this.outcome,
    required this.context,
  });
}

/// Arguments passed to retry callback functions.
class OnRetryArguments<T> {
  /// The current attempt number (zero-based).
  final int attemptNumber;

  /// The outcome of the failed attempt.
  final Outcome<T> outcome;

  /// The delay before the next retry.
  final Duration delay;

  /// The resilience context.
  final ResilienceContext context;

  const OnRetryArguments({
    required this.attemptNumber,
    required this.outcome,
    required this.delay,
    required this.context,
  });
}

/// Retry resilience strategy implementation.
class RetryStrategy extends ResilienceStrategy {
  final RetryStrategyOptions _options;
  final math.Random _random = math.Random();

  /// Creates a retry strategy with the specified options.
  RetryStrategy(this._options);

  @override
  Future<Outcome<T>> executeCore<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
  ) async {
    final shouldHandle = _options.shouldHandle as ShouldHandlePredicate<T>? ??
        PredicateHelper.handleAllExceptions<T>();

    var attemptNumber = 0;
    context.setAttemptNumber(attemptNumber);

    while (true) {
      context.throwIfCancellationRequested();

      try {
        final result = await callback(context);
        return Outcome.fromResult(result);
      } catch (exception, stackTrace) {
        final outcome = Outcome<T>.fromException(exception, stackTrace);

        // Check if we should retry
        if (!shouldHandle(outcome)) {
          return outcome;
        }

        // Check if we've exceeded the maximum attempts
        if (attemptNumber >= _options.maxRetryAttempts) {
          return outcome;
        }

        // Calculate delay
        final delay = await _calculateDelay(attemptNumber, outcome, context);
        if (delay == null) {
          return outcome;
        }

        // Invoke onRetry callback
        if (_options.onRetry != null) {
          await (_options.onRetry! as OnRetryCallback<T>)(OnRetryArguments<T>(
            attemptNumber: attemptNumber,
            outcome: outcome,
            delay: delay,
            context: context,
          ));
        }

        // Wait for the delay
        if (delay > Duration.zero) {
          await _delay(delay, context);
        }

        // Increment attempt number for next iteration
        attemptNumber++;
        context.setAttemptNumber(attemptNumber);
      }
    }
  }

  /// Calculates the delay for the given attempt.
  Future<Duration?> _calculateDelay<T>(
    int attemptNumber,
    Outcome<T> outcome,
    ResilienceContext context,
  ) async {
    // Use custom delay generator if provided
    if (_options.delayGenerator != null) {
      return await (_options.delayGenerator!
          as DelayGenerator<T>)(DelayGeneratorArguments<T>(
        attemptNumber: attemptNumber,
        outcome: outcome,
        context: context,
      ));
    }

    // Calculate standard delay
    Duration baseDelay = _options.delay;

    switch (_options.backoffType) {
      case DelayBackoffType.constant:
        // No change to base delay
        break;

      case DelayBackoffType.linear:
        baseDelay = Duration(
          milliseconds: _options.delay.inMilliseconds * (attemptNumber + 1),
        );
        break;

      case DelayBackoffType.exponential:
        final multiplier = math.pow(2, attemptNumber).toInt();
        baseDelay = Duration(
          milliseconds: _options.delay.inMilliseconds * multiplier,
        );
        break;
    }

    // Apply maximum delay limit
    if (baseDelay > _options.maxDelay) {
      baseDelay = _options.maxDelay;
    }

    // Add jitter if enabled
    if (_options.useJitter && baseDelay > Duration.zero) {
      final jitterMs = _random.nextInt(baseDelay.inMilliseconds);
      baseDelay = Duration(milliseconds: jitterMs);
    }

    return baseDelay;
  }

  /// Waits for the specified delay, respecting cancellation.
  Future<void> _delay(Duration delay, ResilienceContext context) async {
    if (delay <= Duration.zero) return;

    final delayCompleter = Completer<void>();
    final timer = Timer(delay, () {
      if (!delayCompleter.isCompleted) {
        delayCompleter.complete();
      }
    });

    // Race between delay and cancellation
    try {
      await Future.any([
        delayCompleter.future,
        context.cancellationFuture,
      ]);
    } finally {
      timer.cancel();
    }

    context.throwIfCancellationRequested();
  }
}
