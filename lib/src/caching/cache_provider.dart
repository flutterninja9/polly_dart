/// Abstract interface for cache providers.
///
/// This interface defines the contract for cache implementations that can be
/// used with the cache strategy. Different implementations can provide
/// in-memory caching, persistent storage, or distributed caching.
abstract class CacheProvider {
  /// Retrieves a value from the cache by its key.
  ///
  /// Returns `null` if the key is not found or the cached value has expired.
  ///
  /// Example:
  /// ```dart
  /// final value = await cache.get<String>('user:123');
  /// if (value != null) {
  ///   print('Found cached value: $value');
  /// }
  /// ```
  Future<T?> get<T>(String key);

  /// Stores a value in the cache with the specified key.
  ///
  /// The [ttl] (time-to-live) parameter specifies how long the value should
  /// remain in the cache. If not provided, the cache provider's default TTL
  /// will be used, or the value may be cached indefinitely.
  ///
  /// Example:
  /// ```dart
  /// await cache.set('user:123', userData, ttl: Duration(minutes: 5));
  /// ```
  Future<void> set<T>(String key, T value, {Duration? ttl});

  /// Removes a specific key from the cache.
  ///
  /// Example:
  /// ```dart
  /// await cache.remove('user:123');
  /// ```
  Future<void> remove(String key);

  /// Clears all entries from the cache.
  ///
  /// Example:
  /// ```dart
  /// await cache.clear();
  /// ```
  Future<void> clear();

  /// Gets the number of entries currently in the cache.
  ///
  /// This is optional and may not be supported by all cache providers.
  /// Returns `null` if the size cannot be determined.
  int? get size => null;
}
