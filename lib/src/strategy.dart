import 'dart:async';

import 'outcome.dart';
import 'resilience_context.dart';

/// Represents a callback that can be executed by a resilience strategy.
typedef ResilienceCallback<T> = Future<T> Function(ResilienceContext context);

/// Represents a predicate that determines whether a strategy should handle a specific outcome.
typedef ShouldHandlePredicate<T> = bool Function(Outcome<T> outcome);

/// Base interface for all resilience strategies.
abstract class ResilienceStrategy {
  /// Executes the provided callback with resilience handling.
  Future<Outcome<T>> executeCore<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
  );
}

/// A helper class for building predicates that determine whether a strategy should handle specific outcomes.
class PredicateBuilder<T> {
  final List<ShouldHandlePredicate<T>> _predicates = [];

  /// Creates a new predicate builder.
  PredicateBuilder();

  /// Adds a predicate that handles specific exception types.
  PredicateBuilder<T> handle<TException extends Object>() {
    _predicates.add((outcome) {
      return outcome.hasException && outcome.exception is TException;
    });
    return this;
  }

  /// Adds a predicate that handles specific exception instances.
  PredicateBuilder<T> handleException(Object exception) {
    _predicates.add((outcome) {
      return outcome.hasException && outcome.exception == exception;
    });
    return this;
  }

  /// Adds a predicate that handles results matching a condition.
  PredicateBuilder<T> handleResult(bool Function(T result) predicate) {
    _predicates.add((outcome) {
      return outcome.hasResult && predicate(outcome.result);
    });
    return this;
  }

  /// Adds a custom predicate.
  PredicateBuilder<T> handleOutcome(ShouldHandlePredicate<T> predicate) {
    _predicates.add(predicate);
    return this;
  }

  /// Builds the final predicate that returns true if any of the added predicates match.
  ShouldHandlePredicate<T> build() {
    if (_predicates.isEmpty) {
      // Default: handle all exceptions
      return (outcome) => outcome.hasException;
    }

    return (outcome) {
      for (final predicate in _predicates) {
        if (predicate(outcome)) {
          return true;
        }
      }
      return false;
    };
  }
}

/// Helper methods for creating common predicates.
class PredicateHelper {
  /// Creates a predicate that handles all exceptions.
  static ShouldHandlePredicate<T> handleAllExceptions<T>() {
    return (outcome) => outcome.hasException;
  }

  /// Creates a predicate that handles specific exception types.
  static ShouldHandlePredicate<T>
      handleException<T, TException extends Object>() {
    return (outcome) => outcome.hasException && outcome.exception is TException;
  }

  /// Creates a predicate that never handles any outcome.
  static ShouldHandlePredicate<T> handleNothing<T>() {
    return (outcome) => false;
  }

  /// Creates a predicate that handles all outcomes (both exceptions and results).
  static ShouldHandlePredicate<T> handleEverything<T>() {
    return (outcome) => true;
  }
}
