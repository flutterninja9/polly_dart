# Cache Strategy

The Cache Strategy provides efficient caching capabilities for your resilience pipelines, allowing you to store and reuse the results of expensive operations to improve performance and reduce resource consumption.

## Overview

The cache strategy implements a cache-aside pattern where:
1. The strategy first checks if a result exists in the cache
2. If found (cache hit), it returns the cached result without executing the operation
3. If not found (cache miss), it executes the operation and stores the result in the cache
4. Subsequent requests with the same cache key will use the cached result

## Key Features

- **Multiple Cache Providers**: Support for in-memory, persistent, and custom cache implementations
- **Flexible Key Generation**: Custom cache key strategies for different scenarios
- **TTL Support**: Configurable time-to-live for cache entries
- **LRU Eviction**: Automatic removal of least recently used items when cache is full
- **Metrics Collection**: Built-in performance monitoring and cache hit/miss tracking
- **Error Resilience**: Cache failures don't break your business logic
- **Integration**: Works seamlessly with other resilience strategies

## Basic Usage

### Simple Memory Caching

```dart
import 'package:polly_dart/polly_dart.dart';

// Create a pipeline with basic memory caching
final pipeline = ResiliencePipelineBuilder()
    .addMemoryCache<String>(
      ttl: Duration(minutes: 5),
      maxSize: 1000,
    )
    .build();

// Expensive operation that will be cached
Future<String> expensiveApiCall() async {
  print('Making expensive API call...');
  await Future.delayed(Duration(milliseconds: 500));
  return 'API Result';
}

// First call - executes the operation and caches the result
final result1 = await pipeline.execute(expensiveApiCall);
print(result1); // Output: API Result

// Second call - returns cached result without executing operation
final result2 = await pipeline.execute(expensiveApiCall);
print(result2); // Output: API Result (from cache)
```

### Custom Cache Configuration

```dart
// Create custom cache provider
final cacheProvider = MemoryCacheProvider(
  defaultTtl: Duration(minutes: 10),
  maxSize: 500,
  cleanupInterval: Duration(minutes: 2),
);

// Configure cache strategy with custom options
final pipeline = ResiliencePipelineBuilder()
    .addCache(CacheStrategyOptions<String>(
      cache: cacheProvider,
      keyGenerator: (context) {
        final userId = context.getProperty<String>('userId');
        return 'user-data:$userId';
      },
      ttl: Duration(minutes: 15),
      shouldCache: (outcome) => outcome.hasResult && outcome.result.isNotEmpty,
      onHit: (args) async => print('Cache hit for ${args.key}'),
      onMiss: (args) async => print('Cache miss for ${args.key}'),
    ))
    .build();
```

## Cache Providers

### Memory Cache Provider

The built-in `MemoryCacheProvider` offers high-performance in-memory caching with advanced features:

```dart
final memoryCache = MemoryCacheProvider(
  defaultTtl: Duration(hours: 1),    // Default expiration time
  maxSize: 10000,                    // Maximum number of entries
  cleanupInterval: Duration(minutes: 5), // Background cleanup frequency
);
```

**Features:**
- **TTL Support**: Automatic expiration of cached entries
- **LRU Eviction**: Removes least recently used items when cache is full  
- **Background Cleanup**: Periodic removal of expired entries
- **Type Safety**: Full generic type support with safe casting
- **Thread Safety**: Safe for concurrent access

### Metrics Collection

Monitor cache performance with the `MetricsCollectingCacheProvider`:

```dart
final baseCache = MemoryCacheProvider();
final metricsCache = MetricsCollectingCacheProvider(baseCache);

final pipeline = ResiliencePipelineBuilder()
    .addCache(CacheStrategyOptions<String>(
      cache: metricsCache,
      keyGenerator: (context) => 'my-operation',
    ))
    .build();

// After some operations...
final metrics = metricsCache.metrics;
print('Hit ratio: ${(metrics.hitRatio * 100).toStringAsFixed(1)}%');
print('Average hit time: ${metrics.averageHitTime.inMicroseconds}μs');
print('Total operations: ${metrics.totalOperations}');
```

## Key Generation Strategies

### Default Key Generation

By default, the cache uses the `operationKey` from the resilience context:

```dart
final context = ResilienceContext(operationKey: 'get-user-profile');
final result = await pipeline.execute(operation, context: context);
```

### Custom Key Generation

Create dynamic cache keys based on context properties:

```dart
final pipeline = ResiliencePipelineBuilder()
    .addCache(CacheStrategyOptions<UserProfile>(
      cache: cacheProvider,
      keyGenerator: (context) {
        final userId = context.getProperty<String>('userId');
        final includeDetails = context.getProperty<bool>('includeDetails') ?? false;
        return 'user:$userId:details:$includeDetails';
      },
    ))
    .build();

// Usage with context properties
final context = ResilienceContext()
  ..setProperty('userId', '12345')
  ..setProperty('includeDetails', true);

final userProfile = await pipeline.execute(
  () => getUserProfile('12345', includeDetails: true),
  context: context,
);
```

### Hierarchical Keys

Create hierarchical cache keys for better organization:

```dart
keyGenerator: (context) {
  final tenant = context.getProperty<String>('tenant');
  final operation = context.getProperty<String>('operation');
  final version = context.getProperty<String>('version') ?? 'v1';
  return '$tenant:$operation:$version';
}
```

## TTL (Time To Live) Strategies

### Fixed TTL

Set a consistent expiration time for all cached entries:

```dart
final pipeline = ResiliencePipelineBuilder()
    .addCache(CacheStrategyOptions<String>(
      cache: cacheProvider,
      ttl: Duration(minutes: 30), // All entries expire after 30 minutes
    ))
    .build();
```

### Dynamic TTL

Adjust TTL based on the type of data or operation:

```dart
final pipeline = ResiliencePipelineBuilder()
    .addCache(CacheStrategyOptions<ApiResponse>(
      cache: cacheProvider,
      onSet: (args) async {
        // Adjust TTL based on response type
        final response = args.value;
        Duration ttl;
        
        if (response.isStatic) {
          ttl = Duration(hours: 24);      // Static data cached longer
        } else if (response.isUserSpecific) {
          ttl = Duration(minutes: 15);    // User data cached shorter
        } else {
          ttl = Duration(hours: 1);       // Default TTL
        }
        
        // Re-cache with custom TTL
        await args.context.cache.set(args.key, response, ttl: ttl);
      },
    ))
    .build();
```

## Integration with Other Strategies

The cache strategy works seamlessly with other resilience strategies:

### Cache + Retry

```dart
final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 3))
    .addCache(CacheStrategyOptions<String>(
      cache: cacheProvider,
      keyGenerator: (context) => 'api-call',
    ))
    .build();

// If the operation fails and retries succeed, the result is cached
// Subsequent calls use the cache, avoiding retries entirely
```

### Cache + Circuit Breaker

```dart
final pipeline = ResiliencePipelineBuilder()
    .addCircuitBreaker(CircuitBreakerStrategyOptions(
      failureThreshold: 5,
      recoveryTimeout: Duration(seconds: 30),
    ))
    .addCache(CacheStrategyOptions<String>(
      cache: cacheProvider,
      keyGenerator: (context) => 'external-service',
    ))
    .build();

// Cache hits bypass the circuit breaker entirely
// Cache misses are subject to circuit breaker state
```

### Cache + Timeout

```dart
final pipeline = ResiliencePipelineBuilder()
    .addTimeout(Duration(seconds: 5))
    .addCache(CacheStrategyOptions<String>(
      cache: cacheProvider,
      keyGenerator: (context) => 'slow-operation',
    ))
    .build();

// Cached responses return immediately, avoiding timeout checks
// Cache misses are subject to the timeout constraint
```

## Advanced Configuration

### Conditional Caching

Only cache successful results that meet certain criteria:

```dart
final pipeline = ResiliencePipelineBuilder()
    .addCache(CacheStrategyOptions<ApiResponse>(
      cache: cacheProvider,
      shouldCache: (outcome) {
        if (!outcome.hasResult) return false;
        
        final response = outcome.result;
        return response.statusCode == 200 && 
               response.data.isNotEmpty &&
               !response.hasErrors;
      },
    ))
    .build();
```

### Cache Callbacks

Monitor and react to cache events:

```dart
final pipeline = ResiliencePipelineBuilder()
    .addCache(CacheStrategyOptions<String>(
      cache: cacheProvider,
      onHit: (args) async {
        logger.info('Cache hit for ${args.key}: ${args.value}');
        metrics.incrementCacheHits();
      },
      onMiss: (args) async {
        logger.info('Cache miss for ${args.key}');
        metrics.incrementCacheMisses();
      },
      onSet: (args) async {
        logger.info('Cached ${args.key} with TTL ${args.ttl}');
        if (args.value.toString().length > 1000) {
          logger.warn('Large object cached: ${args.key}');
        }
      },
    ))
    .build();
```

## Performance Considerations

### Memory Usage

Monitor memory consumption with large caches:

```dart
// Configure appropriate cache size limits
final memoryCache = MemoryCacheProvider(
  maxSize: 10000,  // Limit number of entries
  defaultTtl: Duration(hours: 1), // Automatic cleanup
);

// Use metrics to monitor cache efficiency
final metricsCache = MetricsCollectingCacheProvider(memoryCache);
```

### Cache Key Design

Design efficient cache keys:

```dart
// ✅ Good: Specific, deterministic keys
keyGenerator: (context) => 'user:${context.userId}:profile:v2'

// ❌ Avoid: Keys with timestamp or random elements
keyGenerator: (context) => 'user:${context.userId}:${DateTime.now().millisecondsSinceEpoch}'

// ✅ Good: Include relevant parameters
keyGenerator: (context) => 'search:${context.query}:page:${context.page}:size:${context.pageSize}'
```

### TTL Strategy

Balance cache efficiency with data freshness:

```dart
// Static/reference data: Long TTL
Duration(days: 1)

// User-specific data: Medium TTL  
Duration(hours: 1)

// Real-time data: Short TTL
Duration(minutes: 5)

// Frequently changing data: Very short TTL
Duration(seconds: 30)
```

## Error Handling

The cache strategy is designed to be resilient:

- **Cache failures don't break operations**: If cache operations fail, the original operation still executes
- **Graceful degradation**: Cache misses fall back to executing the operation
- **Type safety**: Invalid cached types return cache misses rather than throwing exceptions

```dart
// Even if cache operations fail, your business logic continues to work
final pipeline = ResiliencePipelineBuilder()
    .addCache(CacheStrategyOptions<String>(
      cache: UnreliableCacheProvider(), // This might fail
      keyGenerator: (context) => 'operation',
    ))
    .build();

// This will always succeed, even if cache fails
final result = await pipeline.execute(() => 'Important result');
```

## Best Practices

### 1. Choose Appropriate Cache Keys

```dart
// Include all parameters that affect the result
keyGenerator: (context) {
  final params = [
    context.getProperty<String>('userId'),
    context.getProperty<String>('locale'),
    context.getProperty<String>('version'),
  ].where((p) => p != null).join(':');
  return 'api:getData:$params';
}
```

### 2. Set Reasonable TTL Values

```dart
// Consider data volatility
final userPreferences = CacheStrategyOptions<UserPrefs>(
  cache: cacheProvider,
  ttl: Duration(minutes: 30), // User preferences change occasionally
);

final stockPrices = CacheStrategyOptions<Price>(
  cache: cacheProvider,
  ttl: Duration(seconds: 10), // Stock prices change frequently
);
```

### 3. Monitor Cache Performance

```dart
// Use metrics to optimize cache configuration
final metricsCache = MetricsCollectingCacheProvider(baseCache);

// Periodically check metrics
Timer.periodic(Duration(minutes: 5), (timer) {
  final metrics = metricsCache.metrics;
  if (metrics.hitRatio < 0.7) {
    logger.warn('Low cache hit ratio: ${metrics.hitRatio}');
  }
});
```

### 4. Handle Large Objects Carefully

```dart
final pipeline = ResiliencePipelineBuilder()
    .addCache(CacheStrategyOptions<LargeData>(
      cache: cacheProvider,
      shouldCache: (outcome) {
        if (!outcome.hasResult) return false;
        
        // Don't cache very large objects
        final sizeEstimate = outcome.result.estimatedSize();
        return sizeEstimate < 1024 * 1024; // 1MB limit
      },
    ))
    .build();
```

### 5. Use Appropriate Cache Sizes

```dart
// Size cache based on your application's needs
final smallAppCache = MemoryCacheProvider(maxSize: 100);
final mediumAppCache = MemoryCacheProvider(maxSize: 1000);
final largeAppCache = MemoryCacheProvider(maxSize: 10000);
```

## Common Patterns

### API Response Caching

```dart
final apiCache = ResiliencePipelineBuilder()
    .addTimeout(Duration(seconds: 30))
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 2))
    .addCache(CacheStrategyOptions<ApiResponse>(
      cache: MemoryCacheProvider(
        defaultTtl: Duration(minutes: 5),
        maxSize: 1000,
      ),
      keyGenerator: (context) {
        final endpoint = context.getProperty<String>('endpoint');
        final params = context.getProperty<Map<String, String>>('params');
        final paramString = params?.entries
            .map((e) => '${e.key}=${e.value}')
            .join('&') ?? '';
        return '$endpoint?$paramString';
      },
      shouldCache: (outcome) => 
          outcome.hasResult && outcome.result.isSuccessful,
    ))
    .build();
```

### User Session Caching

```dart
final sessionCache = ResiliencePipelineBuilder()
    .addCache(CacheStrategyOptions<UserSession>(
      cache: MemoryCacheProvider(
        defaultTtl: Duration(minutes: 20),
        maxSize: 10000,
      ),
      keyGenerator: (context) {
        final sessionId = context.getProperty<String>('sessionId');
        return 'session:$sessionId';
      },
      onHit: (args) async {
        // Extend session on access
        final session = args.value;
        session.updateLastAccessed();
      },
    ))
    .build();
```

### Database Query Caching

```dart
final queryCache = ResiliencePipelineBuilder()
    .addCache(CacheStrategyOptions<QueryResult>(
      cache: MemoryCacheProvider(
        defaultTtl: Duration(minutes: 10),
        maxSize: 500,
      ),
      keyGenerator: (context) {
        final sql = context.getProperty<String>('sql');
        final params = context.getProperty<List<dynamic>>('params');
        final paramHash = params?.map((p) => p.toString()).join('|') ?? '';
        return 'query:${sql.hashCode}:$paramHash';
      },
      shouldCache: (outcome) {
        // Only cache successful, non-empty results
        return outcome.hasResult && 
               outcome.result.rows.isNotEmpty;
      },
    ))
    .build();
```

The cache strategy provides a powerful and flexible caching solution that integrates seamlessly with polly_dart's resilience patterns, helping you build more efficient and responsive applications.
