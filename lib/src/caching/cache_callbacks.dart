import '../outcome.dart';
import '../resilience_context.dart';

/// Signature for generating cache keys from resilience context.
///
/// The cache key generator receives the [ResilienceContext] and should return
/// a unique string that identifies the operation being cached.
///
/// Example:
/// ```dart
/// final keyGenerator = (context) => 'user:${context.properties['userId']}';
/// ```
typedef CacheKeyGenerator<T> = String Function(ResilienceContext context);

/// Signature for determining whether an outcome should be cached.
///
/// This predicate receives an [Outcome] and should return `true` if the
/// outcome should be stored in the cache, `false` otherwise.
///
/// Example:
/// ```dart
/// final shouldCache = (outcome) => outcome.hasResult && outcome.result != null;
/// ```
typedef ShouldCachePredicate<T> = bool Function(Outcome<T> outcome);

/// Signature for cache hit callbacks.
///
/// Called when a cached value is found and returned.
typedef OnCacheHit<T> = Future<void> Function(OnCacheHitArguments<T> args);

/// Signature for cache miss callbacks.
///
/// Called when no cached value is found and the callback needs to be executed.
typedef OnCacheMiss<T> = Future<void> Function(OnCacheMissArguments<T> args);

/// Signature for cache set callbacks.
///
/// Called when a new value is stored in the cache.
typedef OnCacheSet<T> = Future<void> Function(OnCacheSetArguments<T> args);

/// Arguments passed to cache hit callbacks.
class OnCacheHitArguments<T> {
  /// The cache key that was hit.
  final String key;

  /// The cached value that was retrieved.
  final T value;

  /// The resilience context for the operation.
  final ResilienceContext context;

  /// Creates cache hit arguments.
  const OnCacheHitArguments({
    required this.key,
    required this.value,
    required this.context,
  });
}

/// Arguments passed to cache miss callbacks.
class OnCacheMissArguments<T> {
  /// The cache key that was missed.
  final String key;

  /// The resilience context for the operation.
  final ResilienceContext context;

  /// Creates cache miss arguments.
  const OnCacheMissArguments({
    required this.key,
    required this.context,
  });
}

/// Arguments passed to cache set callbacks.
class OnCacheSetArguments<T> {
  /// The cache key being set.
  final String key;

  /// The value being cached.
  final T value;

  /// The TTL for the cached value, if any.
  final Duration? ttl;

  /// The resilience context for the operation.
  final ResilienceContext context;

  /// Creates cache set arguments.
  const OnCacheSetArguments({
    required this.key,
    required this.value,
    this.ttl,
    required this.context,
  });
}
