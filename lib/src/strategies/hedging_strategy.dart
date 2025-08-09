import 'dart:async';

import '../outcome.dart';
import '../resilience_context.dart';
import '../strategy.dart';

/// Configuration options for the hedging strategy.
class HedgingStrategyOptions<T> {
  /// Maximum number of hedged attempts (default: 1).
  final int maxHedgedAttempts;

  /// Delay before starting hedged attempts (default: 1 second).
  final Duration delay;

  /// Generator for custom delay logic.
  final HedgingDelayGenerator<T>? delayGenerator;

  /// Predicate to determine which outcomes should trigger hedging.
  final ShouldHandlePredicate<T>? shouldHandle;

  /// Generator for creating hedged actions.
  final HedgingActionGenerator<T>? actionGenerator;

  /// Callback invoked when hedging is triggered.
  final OnHedgingCallback<T>? onHedging;

  /// Creates hedging strategy options.
  const HedgingStrategyOptions({
    this.maxHedgedAttempts = 1,
    this.delay = const Duration(seconds: 1),
    this.delayGenerator,
    this.shouldHandle,
    this.actionGenerator,
    this.onHedging,
  });
}

/// Signature for hedging delay generator functions.
typedef HedgingDelayGenerator<T> = Future<Duration> Function(
    HedgingDelayGeneratorArguments<T> args);

/// Signature for hedging action generator functions.
typedef HedgingActionGenerator<T> = Future<T> Function(
    HedgingActionGeneratorArguments<T> args);

/// Signature for hedging callback functions.
typedef OnHedgingCallback<T> = Future<void> Function(
    OnHedgingArguments<T> args);

/// Arguments passed to hedging delay generator functions.
class HedgingDelayGeneratorArguments<T> {
  /// The current hedged attempt number (zero-based).
  final int attemptNumber;

  /// The resilience context.
  final ResilienceContext context;

  const HedgingDelayGeneratorArguments({
    required this.attemptNumber,
    required this.context,
  });
}

/// Arguments passed to hedging action generator functions.
class HedgingActionGeneratorArguments<T> {
  /// The original callback to execute.
  final ResilienceCallback<T> callback;

  /// The action context for this hedged attempt.
  final ResilienceContext actionContext;

  /// The current hedged attempt number (zero-based).
  final int attemptNumber;

  const HedgingActionGeneratorArguments({
    required this.callback,
    required this.actionContext,
    required this.attemptNumber,
  });
}

/// Arguments passed to hedging callback functions.
class OnHedgingArguments<T> {
  /// The current hedged attempt number (zero-based).
  final int attemptNumber;

  /// The resilience context.
  final ResilienceContext context;

  const OnHedgingArguments({
    required this.attemptNumber,
    required this.context,
  });
}

/// Hedging resilience strategy implementation.
class HedgingStrategy extends ResilienceStrategy {
  final dynamic _options;

  /// Creates a hedging strategy with the specified options.
  HedgingStrategy(this._options);

  @override
  Future<Outcome<T>> executeCore<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
  ) async {
    final shouldHandle = _options.shouldHandle as ShouldHandlePredicate<T>? ??
        PredicateHelper.handleAllExceptions<T>();

    // Create a list to track all running attempts
    final List<Future<Outcome<T>>> attempts = [];
    final List<ResilienceContext> attemptContexts = [];
    final List<Completer<void>> cancellers = [];

    try {
      // Start the primary attempt
      final primaryContext = context.copy();
      attemptContexts.add(primaryContext);
      cancellers.add(Completer<void>());

      attempts.add(
          _executeAttempt(callback, primaryContext, cancellers.last.future));

      // Start hedged attempts
      for (int i = 0; i < _options.maxHedgedAttempts; i++) {
        // Calculate delay for this hedged attempt
        final delay = await _calculateDelay(i, context);

        // Wait for the delay
        if (delay > Duration.zero) {
          await _delay(delay, context);
        }

        // Invoke onHedging callback
        if (_options.onHedging != null) {
          try {
            await (_options.onHedging! as dynamic)(OnHedgingArguments<T>(
              attemptNumber: i,
              context: context,
            ));
          } catch (e) {
            // Ignore callback execution errors
          }
        }

        // Create a new context for this hedged attempt
        final hedgedContext = context.copy();
        hedgedContext.setAttemptNumber(i + 1);
        attemptContexts.add(hedgedContext);
        cancellers.add(Completer<void>());

        // Start the hedged attempt
        final hedgedAttempt = _executeHedgedAttempt(
            callback, hedgedContext, i, cancellers.last.future);
        attempts.add(hedgedAttempt);
      }

      // Wait for the first successful result
      while (attempts.isNotEmpty) {
        final completedIndex = await _waitForAnyCompletion(attempts);
        final outcome = await attempts[completedIndex];

        // If this outcome should not be handled (i.e., it's successful), return it
        if (!shouldHandle(outcome)) {
          _cancelRemainingAttempts(cancellers, completedIndex);
          return outcome;
        }

        // Remove the failed attempt and continue with remaining ones
        attempts.removeAt(completedIndex);
        attemptContexts.removeAt(completedIndex);
        cancellers.removeAt(completedIndex);
      }

      // If we get here, all attempts failed - return the primary outcome
      return shouldHandle as Outcome<T>;
    } finally {
      // Cancel any remaining attempts
      _cancelRemainingAttempts(cancellers, -1);
    }
  }

  /// Executes a single attempt with cancellation support.
  Future<Outcome<T>> _executeAttempt<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
    Future<void> cancellationFuture,
  ) async {
    try {
      final result = await Future.any([
        callback(context),
        cancellationFuture.then<T>((_) => throw OperationCancelledException()),
      ]);
      return Outcome.fromResult(result);
    } catch (exception, stackTrace) {
      if (exception is OperationCancelledException) {
        context.cancel();
      }
      return Outcome.fromException(exception, stackTrace);
    }
  }

  /// Executes a hedged attempt using the action generator if available.
  Future<Outcome<T>> _executeHedgedAttempt<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
    int attemptNumber,
    Future<void> cancellationFuture,
  ) async {
    ResilienceCallback<T> actualCallback = callback;

    // Use action generator if provided
    if (_options.actionGenerator != null) {
      actualCallback = (ctx) async {
        return await _options
            .actionGenerator!(HedgingActionGeneratorArguments<T>(
          callback: callback,
          actionContext: ctx,
          attemptNumber: attemptNumber,
        )) as T;
      };
    }

    return await _executeAttempt(actualCallback, context, cancellationFuture);
  }

  /// Calculates the delay for a hedged attempt.
  Future<Duration> _calculateDelay<T>(
      int attemptNumber, ResilienceContext context) async {
    if (_options.delayGenerator != null) {
      return await _options.delayGenerator!(HedgingDelayGeneratorArguments<T>(
        attemptNumber: attemptNumber,
        context: context,
      ));
    }
    return _options.delay;
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

  /// Waits for any of the attempts to complete and returns the index.
  Future<int> _waitForAnyCompletion<T>(
      List<Future<Outcome<T>>> attempts) async {
    final completers = attempts.asMap().entries.map((entry) {
      final index = entry.key;
      final future = entry.value;
      return future.then((outcome) => index);
    }).toList();

    return await Future.any(completers);
  }

  /// Cancels all remaining attempts except the specified one.
  void _cancelRemainingAttempts(
      List<Completer<void>> cancellers, int excludeIndex) {
    for (int i = 0; i < cancellers.length; i++) {
      if (i != excludeIndex && !cancellers[i].isCompleted) {
        cancellers[i].complete();
      }
    }
  }
}
