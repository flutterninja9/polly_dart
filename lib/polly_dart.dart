/// A Dart port of Polly (.NET resilience library) providing strategies like
/// Retry, Circuit Breaker, Timeout, Rate Limiter, Hedging, and Fallback.
///
/// This library provides resilience and transient-fault-handling capabilities
/// for Dart applications, allowing developers to express policies such as Retry,
/// Circuit Breaker, Timeout, Bulkhead Isolation, and Fallback in a fluent manner.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:polly_dart/polly_dart.dart';
///
/// // Create a resilience pipeline
/// final pipeline = ResiliencePipelineBuilder()
///     .addRetry(RetryStrategyOptions(maxRetryAttempts: 3))
///     .addTimeout(Duration(seconds: 10))
///     .build();
///
/// // Execute with resilience
/// final result = await pipeline.execute((context) async {
///   // Your code here
///   return await someAsyncOperation();
/// });
/// ```
library polly_dart;

// Core types
export 'src/outcome.dart';
export 'src/resilience_context.dart';
export 'src/resilience_pipeline.dart';
export 'src/resilience_pipeline_builder.dart';
export 'src/strategies/circuit_breaker_strategy.dart';
export 'src/strategies/fallback_strategy.dart';
export 'src/strategies/hedging_strategy.dart';
export 'src/strategies/rate_limiter_strategy.dart';
// Strategies
export 'src/strategies/retry_strategy.dart';
export 'src/strategies/timeout_strategy.dart';
export 'src/strategy.dart';
