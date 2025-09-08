import 'caching/cache_provider.dart';
import 'caching/memory_cache_provider.dart';
import 'resilience_context.dart';
import 'resilience_pipeline.dart';
import 'strategies/cache_strategy.dart';
import 'strategies/circuit_breaker_strategy.dart';
import 'strategies/fallback_strategy.dart';
import 'strategies/hedging_strategy.dart';
import 'strategies/rate_limiter_strategy.dart';
import 'strategies/retry_strategy.dart';
import 'strategies/timeout_strategy.dart';
import 'strategy.dart';

/// Builder for creating resilience pipelines.
///
/// This builder allows you to combine multiple resilience strategies
/// in a fluent manner to create a resilience pipeline.
class ResiliencePipelineBuilder {
  final List<ResilienceStrategy> _strategies = [];

  /// Creates a new resilience pipeline builder.
  ResiliencePipelineBuilder();

  /// Adds a retry strategy to the pipeline.
  ResiliencePipelineBuilder addRetry([RetryStrategyOptions? options]) {
    _strategies.add(RetryStrategy(options ?? RetryStrategyOptions()));
    return this;
  }

  /// Adds a timeout strategy to the pipeline.
  ResiliencePipelineBuilder addTimeout(Duration timeout) {
    _strategies.add(TimeoutStrategy(TimeoutStrategyOptions(timeout: timeout)));
    return this;
  }

  /// Adds a timeout strategy with options to the pipeline.
  ResiliencePipelineBuilder addTimeoutWithOptions(
      TimeoutStrategyOptions options) {
    _strategies.add(TimeoutStrategy(options));
    return this;
  }

  /// Adds a circuit breaker strategy to the pipeline.
  ResiliencePipelineBuilder addCircuitBreaker(
      [CircuitBreakerStrategyOptions? options]) {
    _strategies.add(
        CircuitBreakerStrategy(options ?? CircuitBreakerStrategyOptions()));
    return this;
  }

  /// Adds a fallback strategy to the pipeline.
  ResiliencePipelineBuilder addFallback<T>(FallbackStrategyOptions<T> options) {
    _strategies.add(FallbackStrategy(options));
    return this;
  }

  /// Adds a hedging strategy to the pipeline.
  ResiliencePipelineBuilder addHedging<T>(HedgingStrategyOptions<T> options) {
    _strategies.add(HedgingStrategy(options));
    return this;
  }

  /// Adds a rate limiter strategy to the pipeline.
  ResiliencePipelineBuilder addRateLimiter(RateLimiterStrategyOptions options) {
    _strategies.add(RateLimiterStrategy(options));
    return this;
  }

  /// Adds a concurrency limiter (bulkhead) to the pipeline.
  ResiliencePipelineBuilder addConcurrencyLimiter(int permitLimit,
      [int? queueLimit]) {
    final options = RateLimiterStrategyOptions.concurrencyLimiter(
      permitLimit: permitLimit,
      queueLimit: queueLimit ?? 0,
    );
    _strategies.add(RateLimiterStrategy(options));
    return this;
  }

  /// Adds a cache strategy to the pipeline.
  ///
  /// Example:
  /// ```dart
  /// final cache = MemoryCacheProvider();
  /// final options = CacheStrategyOptions<String>(cache: cache);
  /// builder.addCache(options);
  /// ```
  ResiliencePipelineBuilder addCache<T>(CacheStrategyOptions<T> options) {
    _strategies.add(CacheStrategy<T>(options));
    return this;
  }

  /// Adds a memory cache strategy with simple configuration.
  ///
  /// This is a convenience method for adding in-memory caching with basic options.
  ///
  /// Example:
  /// ```dart
  /// builder.addMemoryCache<String>(
  ///   ttl: Duration(minutes: 5),
  ///   maxSize: 1000,
  /// );
  /// ```
  ResiliencePipelineBuilder addMemoryCache<T>({
    Duration? ttl,
    int? maxSize,
    Duration cleanupInterval = const Duration(minutes: 5),
  }) {
    final provider = MemoryCacheProvider(
      defaultTtl: ttl,
      maxSize: maxSize,
      cleanupInterval: cleanupInterval,
    );

    final options = CacheStrategyOptions<T>(
      cache: provider,
      ttl: ttl,
    );

    return addCache(options);
  }

  /// Adds a cache strategy with custom key generator.
  ///
  /// Example:
  /// ```dart
  /// builder.addCacheWithKeyGenerator<String>(
  ///   cache: myCache,
  ///   keyGenerator: (context) => 'user:${context.properties['userId']}',
  ///   ttl: Duration(minutes: 10),
  /// );
  /// ```
  ResiliencePipelineBuilder addCacheWithKeyGenerator<T>({
    required CacheProvider cache,
    required String Function(ResilienceContext) keyGenerator,
    Duration? ttl,
  }) {
    final options = CacheStrategyOptions<T>(
      cache: cache,
      keyGenerator: keyGenerator,
      ttl: ttl,
    );

    return addCache(options);
  }

  /// Adds a custom strategy to the pipeline.
  ResiliencePipelineBuilder addStrategy(ResilienceStrategy strategy) {
    _strategies.add(strategy);
    return this;
  }

  /// Builds the resilience pipeline.
  ResiliencePipeline build() {
    return ResiliencePipeline(List.unmodifiable(_strategies));
  }

  /// Gets the current number of strategies in the builder.
  int get strategyCount => _strategies.length;

  /// Clears all strategies from the builder.
  void clear() {
    _strategies.clear();
  }
}

/// Generic builder for creating typed resilience pipelines.
class TypedResiliencePipelineBuilder<T> {
  final ResiliencePipelineBuilder _builder = ResiliencePipelineBuilder();

  /// Creates a new typed resilience pipeline builder.
  TypedResiliencePipelineBuilder();

  /// Adds a retry strategy to the pipeline.
  TypedResiliencePipelineBuilder<T> addRetry(
      [RetryStrategyOptions<T>? options]) {
    _builder.addStrategy(RetryStrategy(options ?? RetryStrategyOptions<T>()));
    return this;
  }

  /// Adds a timeout strategy to the pipeline.
  TypedResiliencePipelineBuilder<T> addTimeout(Duration timeout) {
    _builder.addTimeout(timeout);
    return this;
  }

  /// Adds a timeout strategy with options to the pipeline.
  TypedResiliencePipelineBuilder<T> addTimeoutWithOptions(
      TimeoutStrategyOptions options) {
    _builder.addTimeoutWithOptions(options);
    return this;
  }

  /// Adds a circuit breaker strategy to the pipeline.
  TypedResiliencePipelineBuilder<T> addCircuitBreaker(
      [CircuitBreakerStrategyOptions<T>? options]) {
    _builder.addStrategy(
        CircuitBreakerStrategy(options ?? CircuitBreakerStrategyOptions<T>()));
    return this;
  }

  /// Adds a fallback strategy to the pipeline.
  TypedResiliencePipelineBuilder<T> addFallback(
      FallbackStrategyOptions<T> options) {
    _builder.addFallback<T>(options);
    return this;
  }

  /// Adds a hedging strategy to the pipeline.
  TypedResiliencePipelineBuilder<T> addHedging(
      HedgingStrategyOptions<T> options) {
    _builder.addHedging<T>(options);
    return this;
  }

  /// Adds a rate limiter strategy to the pipeline.
  TypedResiliencePipelineBuilder<T> addRateLimiter(
      RateLimiterStrategyOptions options) {
    _builder.addRateLimiter(options);
    return this;
  }

  /// Adds a concurrency limiter (bulkhead) to the pipeline.
  TypedResiliencePipelineBuilder<T> addConcurrencyLimiter(int permitLimit,
      [int? queueLimit]) {
    _builder.addConcurrencyLimiter(permitLimit, queueLimit);
    return this;
  }

  /// Adds a custom strategy to the pipeline.
  TypedResiliencePipelineBuilder<T> addStrategy(ResilienceStrategy strategy) {
    _builder.addStrategy(strategy);
    return this;
  }

  /// Builds the typed resilience pipeline.
  TypedResiliencePipeline<T> build() {
    return TypedResiliencePipeline<T>(_builder.build());
  }

  /// Gets the current number of strategies in the builder.
  int get strategyCount => _builder.strategyCount;

  /// Clears all strategies from the builder.
  void clear() {
    _builder.clear();
  }
}
