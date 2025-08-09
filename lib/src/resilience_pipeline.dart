import 'dart:async';

import 'outcome.dart';
import 'resilience_context.dart';
import 'strategy.dart';

/// A resilience pipeline that combines multiple resilience strategies.
///
/// The pipeline executes strategies in the order they were added, with each
/// strategy wrapping the next one in the chain.
class ResiliencePipeline {
  final List<ResilienceStrategy> _strategies;

  /// Creates a resilience pipeline with the given strategies.
  const ResiliencePipeline(this._strategies);

  /// Executes a callback through the resilience pipeline.
  ///
  /// The callback will be executed with resilience handling applied according
  /// to the configured strategies.
  Future<T> execute<T>(
    ResilienceCallback<T> callback, {
    ResilienceContext? context,
  }) async {
    final ctx = context ?? ResilienceContext();
    final outcome = await _executeCore(callback, ctx);
    outcome.throwIfException();
    return outcome.result;
  }

  /// Executes a callback and returns the outcome without throwing exceptions.
  Future<Outcome<T>> executeAndCapture<T>(
    ResilienceCallback<T> callback, {
    ResilienceContext? context,
  }) async {
    final ctx = context ?? ResilienceContext();
    return await _executeCore(callback, ctx);
  }

  /// Internal method that executes the callback through all strategies.
  Future<Outcome<T>> _executeCore<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
  ) async {
    if (_strategies.isEmpty) {
      // No strategies, execute callback directly
      try {
        final result = await callback(context);
        return Outcome.fromResult(result);
      } catch (exception, stackTrace) {
        return Outcome.fromException(exception, stackTrace);
      }
    }

    // Execute through the strategy chain
    return await _executeWithStrategies(callback, context, 0);
  }

  /// Recursively executes the callback through the strategy chain.
  Future<Outcome<T>> _executeWithStrategies<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
    int strategyIndex,
  ) async {
    if (strategyIndex >= _strategies.length) {
      // No more strategies, execute the original callback
      try {
        final result = await callback(context);
        return Outcome.fromResult(result);
      } catch (exception, stackTrace) {
        return Outcome.fromException(exception, stackTrace);
      }
    }

    final strategy = _strategies[strategyIndex];

    // Create a callback that continues to the next strategy
    Future<T> nextCallback(ResilienceContext ctx) async {
      final outcome =
          await _executeWithStrategies(callback, ctx, strategyIndex + 1);
      outcome.throwIfException();
      return outcome.result;
    }

    return await strategy.executeCore(nextCallback, context);
  }

  /// Gets the number of strategies in this pipeline.
  int get strategyCount => _strategies.length;

  /// Checks if the pipeline is empty (has no strategies).
  bool get isEmpty => _strategies.isEmpty;

  /// Checks if the pipeline has any strategies.
  bool get isNotEmpty => _strategies.isNotEmpty;

  @override
  String toString() {
    return 'ResiliencePipeline(strategies: ${_strategies.length})';
  }
}

/// A generic resilience pipeline that is typed for a specific result type.
///
/// This provides additional type safety when working with specific result types.
class TypedResiliencePipeline<T> {
  final ResiliencePipeline _pipeline;

  /// Creates a typed resilience pipeline wrapping an untyped pipeline.
  const TypedResiliencePipeline(this._pipeline);

  /// Executes a callback through the resilience pipeline.
  Future<T> execute(
    ResilienceCallback<T> callback, {
    ResilienceContext? context,
  }) {
    return _pipeline.execute<T>(callback, context: context);
  }

  /// Executes a callback and returns the outcome without throwing exceptions.
  Future<Outcome<T>> executeAndCapture(
    ResilienceCallback<T> callback, {
    ResilienceContext? context,
  }) {
    return _pipeline.executeAndCapture<T>(callback, context: context);
  }

  /// Gets the underlying untyped pipeline.
  ResiliencePipeline get pipeline => _pipeline;

  /// Gets the number of strategies in this pipeline.
  int get strategyCount => _pipeline.strategyCount;

  /// Checks if the pipeline is empty (has no strategies).
  bool get isEmpty => _pipeline.isEmpty;

  /// Checks if the pipeline has any strategies.
  bool get isNotEmpty => _pipeline.isNotEmpty;

  @override
  String toString() {
    return 'TypedResiliencePipeline<$T>(strategies: ${_pipeline.strategyCount})';
  }
}
