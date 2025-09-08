# Cache Strategy

## CacheStrategy

Core cache strategy implementation that provides caching capabilities for resilience pipelines.

### Constructor

```dart
CacheStrategy(CacheStrategyOptions<T> options)
```

Creates a new cache strategy with the specified options.

**Parameters:**
- `options` - Configuration options for the cache strategy

---

## CacheStrategyOptions&lt;T&gt;

Configuration options for the cache strategy.

### Properties

#### cache
```dart
final CacheProvider cache;
```
The cache provider instance to use for storing and retrieving values.

#### keyGenerator
```dart
final CacheKeyGenerator<T>? keyGenerator;
```
Generator for cache keys. If not provided, uses the context's operation key.

**Example:**
```dart
keyGenerator: (context) => 'user:${context.getProperty<String>('userId')}'
```

#### ttl
```dart
final Duration? ttl;
```
Time-to-live for cached entries. If not provided, uses the cache provider's default.

#### shouldCache
```dart
final ShouldCachePredicate<T>? shouldCache;
```
Predicate to determine which outcomes should be cached. If not provided, all successful results are cached.

**Example:**
```dart
shouldCache: (outcome) => outcome.hasResult && outcome.result.isNotEmpty
```

#### onHit
```dart
final OnCacheHit<T>? onHit;
```
Callback invoked when a cache hit occurs.

#### onMiss
```dart
final OnCacheMiss<T>? onMiss;
```
Callback invoked when a cache miss occurs.

#### onSet
```dart
final OnCacheSet<T>? onSet;
```
Callback invoked when a value is stored in the cache.

### Constructor

```dart
const CacheStrategyOptions({
  required this.cache,
  this.keyGenerator,
  this.ttl,
  this.shouldCache,
  this.onHit,
  this.onMiss,
  this.onSet,
})
```

---

## CacheProvider

Abstract interface for cache providers.

### Methods

#### get&lt;T&gt;
```dart
Future<T?> get<T>(String key);
```
Retrieves a value from the cache.

**Parameters:**
- `key` - The cache key
- `T` - The type of the cached value

**Returns:** The cached value or `null` if not found or expired.

#### set&lt;T&gt;
```dart
Future<void> set<T>(String key, T value, {Duration? ttl});
```
Stores a value in the cache.

**Parameters:**
- `key` - The cache key
- `value` - The value to cache
- `ttl` - Optional time-to-live for this entry

#### remove
```dart
Future<void> remove(String key);
```
Removes a value from the cache.

**Parameters:**
- `key` - The cache key to remove

#### clear
```dart
Future<void> clear();
```
Clears all values from the cache.

#### size
```dart
int? get size;
```
Gets the current number of entries in the cache.

---

## MemoryCacheProvider

In-memory cache provider with TTL and LRU eviction support.

### Constructor

```dart
MemoryCacheProvider({
  Duration? defaultTtl,
  int? maxSize,
  Duration cleanupInterval = const Duration(minutes: 5),
})
```

**Parameters:**
- `defaultTtl` - Default time-to-live for cache entries
- `maxSize` - Maximum number of entries (LRU eviction when exceeded)
- `cleanupInterval` - How often to clean up expired entries

### Features

- **TTL Support**: Automatic expiration of cached entries
- **LRU Eviction**: Removes least recently used items when cache is full
- **Background Cleanup**: Periodic removal of expired entries
- **Type Safety**: Full generic type support with safe casting
- **Thread Safety**: Safe for concurrent access

---

## CacheMetrics

Basic cache metrics collector for performance monitoring.

### Properties

#### hits
```dart
int get hits;
```
Number of cache hits.

#### misses
```dart
int get misses;
```
Number of cache misses.

#### sets
```dart
int get sets;
```
Number of cache sets.

#### totalOperations
```dart
int get totalOperations;
```
Total operations (hits + misses).

#### hitRatio
```dart
double get hitRatio;
```
Cache hit ratio (0.0 to 1.0).

#### averageHitTime
```dart
Duration get averageHitTime;
```
Average time for cache hits.

#### averageMissTime
```dart
Duration get averageMissTime;
```
Average time for cache misses.

### Methods

#### recordHit
```dart
void recordHit([Duration? responseTime]);
```
Record a cache hit.

#### recordMiss
```dart
void recordMiss([Duration? responseTime]);
```
Record a cache miss.

#### recordSet
```dart
void recordSet();
```
Record a cache set operation.

#### reset
```dart
void reset();
```
Reset all metrics to zero.

---

## MetricsCollectingCacheProvider

Cache provider wrapper that automatically collects performance metrics.

### Constructor

```dart
MetricsCollectingCacheProvider(CacheProvider inner);
```

**Parameters:**
- `inner` - The cache provider to wrap

### Properties

#### metrics
```dart
CacheMetrics get metrics;
```
Access to the collected metrics.

### Features

- Automatically tracks all cache operations
- Measures response times for hits and misses
- Delegates all operations to the wrapped provider
- Maintains separate metrics per instance

---

## Type Definitions

### CacheKeyGenerator&lt;T&gt;
```dart
typedef CacheKeyGenerator<T> = String Function(ResilienceContext context);
```
Function that generates cache keys from resilience context.

### ShouldCachePredicate&lt;T&gt;
```dart
typedef ShouldCachePredicate<T> = bool Function(Outcome<T> outcome);
```
Predicate function to determine if an outcome should be cached.

### OnCacheHit&lt;T&gt;
```dart
typedef OnCacheHit<T> = Future<void> Function(OnCacheHitArguments<T> args);
```
Callback function invoked on cache hits.

### OnCacheMiss&lt;T&gt;
```dart
typedef OnCacheMiss<T> = Future<void> Function(OnCacheMissArguments<T> args);
```
Callback function invoked on cache misses.

### OnCacheSet&lt;T&gt;
```dart
typedef OnCacheSet<T> = Future<void> Function(OnCacheSetArguments<T> args);
```
Callback function invoked when setting cache values.

---

## Callback Arguments

### OnCacheHitArguments&lt;T&gt;
```dart
class OnCacheHitArguments<T> {
  final String key;
  final T value;
  final ResilienceContext context;
}
```

### OnCacheMissArguments&lt;T&gt;
```dart
class OnCacheMissArguments<T> {
  final String key;
  final ResilienceContext context;
}
```

### OnCacheSetArguments&lt;T&gt;
```dart
class OnCacheSetArguments<T> {
  final String key;
  final T value;
  final Duration? ttl;
  final ResilienceContext context;
}
```

---

## Pipeline Builder Extensions

The cache strategy integrates with `ResiliencePipelineBuilder` through extension methods:

### addCache&lt;T&gt;
```dart
ResiliencePipelineBuilder addCache<T>([CacheStrategyOptions<T>? options]);
```
Adds a cache strategy to the pipeline with custom options.

### addMemoryCache&lt;T&gt;
```dart
ResiliencePipelineBuilder addMemoryCache<T>({
  Duration? ttl,
  int? maxSize,
  Duration cleanupInterval = const Duration(minutes: 5),
});
```
Adds a memory cache strategy with simple configuration.

### addCacheWithKeyGenerator&lt;T&gt;
```dart
ResiliencePipelineBuilder addCacheWithKeyGenerator<T>({
  required CacheProvider cache,
  required String Function(ResilienceContext) keyGenerator,
  Duration? ttl,
});
```
Adds a cache strategy with custom key generator.
