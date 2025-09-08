import 'dart:async';

import '../caching/cache_callbacks.dart';
import '../caching/cache_provider.dart';
import '../outcome.dart';
import '../resilience_context.dart';
import '../strategy.dart';

/// Configuration options for the cache strategy.
///
/// This class contains all the settings needed to configure how the cache
/// strategy behaves, including the cache provider, key generation, TTL,
/// and callback functions.
class CacheStrategyOptions<T> {
  /// The cache provider instance to use for storing and retrieving values.
  final CacheProvider cache;

  /// Generator for cache keys. If not provided, uses the context's operation key.
  ///
  /// Example:
  /// ```dart
  /// keyGenerator: (context) => 'user:${context.properties['userId']}'
  /// ```
  final CacheKeyGenerator<T>? keyGenerator;

  /// Time-to-live for cached entries. If not provided, uses the cache provider's default.
  ///
  /// Example:
  /// ```dart
  /// ttl: Duration(minutes: 5)
  /// ```
  final Duration? ttl;

  /// Predicate to determine which outcomes should be cached.
  /// If not provided, all successful results are cached.
  ///
  /// Example:
  /// ```dart
  /// shouldCache: (outcome) => outcome.hasResult && outcome.result.isNotEmpty
  /// ```
  final ShouldCachePredicate<T>? shouldCache;

  /// Callback invoked when a cache hit occurs.
  ///
  /// Example:
  /// ```dart
  /// onHit: (args) async => print('Cache hit for key: ${args.key}')
  /// ```
  final OnCacheHit<T>? onHit;

  /// Callback invoked when a cache miss occurs.
  ///
  /// Example:
  /// ```dart
  /// onMiss: (args) async => print('Cache miss for key: ${args.key}')
  /// ```
  final OnCacheMiss<T>? onMiss;

  /// Callback invoked when a value is stored in the cache.
  ///
  /// Example:
  /// ```dart
  /// onSet: (args) async => print('Cached value for key: ${args.key}')
  /// ```
  final OnCacheSet<T>? onSet;

  /// Creates cache strategy options.
  ///
  /// The [cache] parameter is required and specifies the cache provider to use.
  /// All other parameters are optional and have sensible defaults.
  ///
  /// Example:
  /// ```dart
  /// final options = CacheStrategyOptions<String>(
  ///   cache: MemoryCacheProvider(),
  ///   ttl: Duration(minutes: 5),
  ///   keyGenerator: (context) => 'api:${context.operationKey}',
  /// );
  /// ```
  const CacheStrategyOptions({
    required this.cache,
    this.keyGenerator,
    this.ttl,
    this.shouldCache,
    this.onHit,
    this.onMiss,
    this.onSet,
  });

  /// Creates cache strategy options with only a cache provider.
  ///
  /// This is a convenience constructor for simple use cases where only
  /// the cache provider needs to be specified.
  ///
  /// Example:
  /// ```dart
  /// final options = CacheStrategyOptions.simple(MemoryCacheProvider());
  /// ```
  const CacheStrategyOptions.simple(this.cache)
      : keyGenerator = null,
        ttl = null,
        shouldCache = null,
        onHit = null,
        onMiss = null,
        onSet = null;

  /// Creates cache strategy options with TTL.
  ///
  /// This is a convenience constructor for use cases where you want to
  /// specify the cache provider and TTL.
  ///
  /// Example:
  /// ```dart
  /// final options = CacheStrategyOptions.withTtl(
  ///   MemoryCacheProvider(),
  ///   Duration(minutes: 10),
  /// );
  /// ```
  const CacheStrategyOptions.withTtl(this.cache, this.ttl)
      : keyGenerator = null,
        shouldCache = null,
        onHit = null,
        onMiss = null,
        onSet = null;
}

/// A resilience strategy that provides caching capabilities.
///
/// This strategy intercepts calls and checks if a cached result exists.
/// If found, it returns the cached value. Otherwise, it executes the
/// callback, caches the result (if appropriate), and returns it.
///
/// Example usage:
/// ```dart
/// final cache = MemoryCacheProvider();
/// final strategy = CacheStrategy(CacheStrategyOptions(cache: cache));
///
/// final pipeline = ResiliencePipelineBuilder()
///     .add(strategy)
///     .build();
/// ```
class CacheStrategy<T> extends ResilienceStrategy {
  final CacheStrategyOptions<T> _options;
  final CacheKeyGenerator<T> _keyGenerator;
  final ShouldCachePredicate<T> _shouldCache;

  /// Creates a new cache strategy with the provided options.
  CacheStrategy(this._options)
      : _keyGenerator = _options.keyGenerator ?? _defaultKeyGenerator,
        _shouldCache = _options.shouldCache ?? _defaultShouldCache;

  @override
  Future<Outcome<U>> executeCore<U>(
    ResilienceCallback<U> callback,
    ResilienceContext context,
  ) async {
    // For this implementation, we'll handle it more simply
    // Generate cache key
    final key = _keyGenerator(context);

    // Handle null/empty keys (bypass caching as per HybridCache behavior)
    if (key.isEmpty) {
      return await _executeAndWrap(callback, context);
    }

    // Try to get from cache
    try {
      final cachedValue = await _options.cache.get<U>(key);
      if (cachedValue != null) {
        // Cache hit
        if (T == U || T == dynamic) {
          await _options.onHit?.call(OnCacheHitArguments<T>(
            key: key,
            value: cachedValue as T,
            context: context,
          ));
        }
        return Outcome.fromResult(cachedValue);
      }
    } catch (error) {
      // Cache retrieval failed, continue with callback execution
      // Log error if needed, but don't fail the operation
    }

    // Cache miss - execute callback
    if (T == U || T == dynamic) {
      await _options.onMiss?.call(OnCacheMissArguments<T>(
        key: key,
        context: context,
      ));
    }

    final outcome = await _executeAndWrap(callback, context);

    // Cache the result if successful and should be cached
    if (outcome.hasResult && (T == U || T == dynamic)) {
      final typedOutcome = outcome as Outcome<T>;
      if (_shouldCache(typedOutcome)) {
        try {
          await _options.cache.set(
            key,
            outcome.result as T,
            ttl: _options.ttl,
          );

          await _options.onSet?.call(OnCacheSetArguments<T>(
            key: key,
            value: outcome.result as T,
            ttl: _options.ttl,
            context: context,
          ));
        } catch (error) {
          // Cache storage failed, but don't fail the operation
          // Log error if needed
        }
      }
    }

    return outcome;
  }

  /// Executes the callback and wraps the result in an Outcome.
  Future<Outcome<U>> _executeAndWrap<U>(
    ResilienceCallback<U> callback,
    ResilienceContext context,
  ) async {
    try {
      final result = await callback(context);
      return Outcome.fromResult(result);
    } catch (error) {
      return Outcome.fromException(error);
    }
  }

  /// Default key generator that uses the operation key from context.
  static String _defaultKeyGenerator(ResilienceContext context) {
    return context.operationKey ?? '';
  }

  /// Default predicate that caches all successful results.
  static bool _defaultShouldCache<T>(Outcome<T> outcome) {
    return outcome.hasResult;
  }
}
