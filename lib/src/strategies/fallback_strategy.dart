import 'dart:async';

import '../outcome.dart';
import '../resilience_context.dart';
import '../strategy.dart';

/// Configuration options for the fallback strategy.
class FallbackStrategyOptions<T> {
  /// Predicate to determine which outcomes should trigger fallback.
  final ShouldHandlePredicate<T>? shouldHandle;

  /// The fallback action to execute when the primary action fails.
  final FallbackAction<T> fallbackAction;

  /// Callback invoked when fallback is triggered.
  final OnFallbackCallback<T>? onFallback;

  /// Creates fallback strategy options.
  const FallbackStrategyOptions({
    required this.fallbackAction,
    this.shouldHandle,
    this.onFallback,
  });

  /// Creates fallback strategy options with a static fallback value.
  FallbackStrategyOptions.withValue(
    T fallbackValue, {
    this.shouldHandle,
    this.onFallback,
  }) : fallbackAction =
            ((args) => Future.value(Outcome.fromResult(fallbackValue)));
}

/// Signature for fallback action functions.
typedef FallbackAction<T> = Future<Outcome<T>> Function(
    FallbackActionArguments<T> args);

/// Signature for fallback callback functions.
typedef OnFallbackCallback<T> = Future<void> Function(
    OnFallbackArguments<T> args);

/// Arguments passed to fallback action functions.
class FallbackActionArguments<T> {
  /// The outcome that triggered the fallback.
  final Outcome<T> outcome;

  /// The resilience context.
  final ResilienceContext context;

  const FallbackActionArguments({
    required this.outcome,
    required this.context,
  });
}

/// Arguments passed to fallback callback functions.
class OnFallbackArguments<T> {
  /// The outcome that triggered the fallback.
  final Outcome<T> outcome;

  /// The resilience context.
  final ResilienceContext context;

  const OnFallbackArguments({
    required this.outcome,
    required this.context,
  });
}

/// Fallback resilience strategy implementation.
class FallbackStrategy extends ResilienceStrategy {
  final dynamic _options;

  /// Creates a fallback strategy with the specified options.
  FallbackStrategy(this._options);

  @override
  Future<Outcome<T>> executeCore<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
  ) async {
    final shouldHandle = _options.shouldHandle as ShouldHandlePredicate<T>? ??
        PredicateHelper.handleAllExceptions<T>();

    // Execute the primary callback
    Outcome<T> outcome;
    try {
      final result = await callback(context);
      outcome = Outcome.fromResult(result);
    } catch (exception, stackTrace) {
      outcome = Outcome.fromException(exception, stackTrace);
    }

    // Check if we should handle this outcome with fallback
    if (!shouldHandle(outcome)) {
      return outcome;
    }

    // Invoke onFallback callback
    if (_options.onFallback != null) {
      try {
        await (_options.onFallback! as dynamic)(OnFallbackArguments<T>(
          outcome: outcome,
          context: context,
        ));
      } catch (e) {
        // Ignore callback execution errors to prevent them from affecting strategy execution
      }
    }

    // Execute the fallback action
    try {
      final fallbackOutcome =
          await (_options.fallbackAction as dynamic)(FallbackActionArguments<T>(
        outcome: outcome,
        context: context,
      ));

      return fallbackOutcome;
    } catch (fallbackException, fallbackStackTrace) {
      // If fallback fails, return the fallback exception
      return Outcome.fromException(fallbackException, fallbackStackTrace);
    }
  }
}

/// Helper methods for creating common fallback actions.
class FallbackActionHelper {
  /// Creates a fallback action that returns a static value.
  static FallbackAction<T> fromValue<T>(T value) {
    return (args) => Future.value(Outcome.fromResult(value));
  }

  /// Creates a fallback action that executes a function.
  static FallbackAction<T> fromFunction<T>(Future<T> Function() function) {
    return (args) async {
      try {
        final result = await function();
        return Outcome.fromResult(result);
      } catch (exception, stackTrace) {
        return Outcome.fromException(exception, stackTrace);
      }
    };
  }

  /// Creates a fallback action that executes a function with context.
  static FallbackAction<T> fromFunctionWithContext<T>(
    Future<T> Function(ResilienceContext context) function,
  ) {
    return (args) async {
      try {
        final result = await function(args.context);
        return Outcome.fromResult(result);
      } catch (exception, stackTrace) {
        return Outcome.fromException(exception, stackTrace);
      }
    };
  }

  /// Creates a fallback action that returns the original exception.
  static FallbackAction<T> rethrowOriginal<T>() {
    return (args) => Future.value(args.outcome);
  }
}
