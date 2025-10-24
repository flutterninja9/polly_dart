# Cache Strategy Examples

This page provides practical examples of using the cache strategy in various scenarios.

## Basic Caching

### Simple Memory Cache

The simplest way to add caching to your operations:

```dart
import 'package:polly_dart/polly_dart.dart';

void main() async {
  // Create pipeline with basic memory caching
  final pipeline = ResiliencePipelineBuilder()
      .addMemoryCache<String>(
        ttl: Duration(minutes: 5),
        maxSize: 1000,
      )
      .build();

  // Expensive operation that will be cached
  Future<String> expensiveOperation() async {
    print('Executing expensive operation...');
    await Future.delayed(Duration(milliseconds: 500));
    return 'Expensive result';
  }

  // First call - executes operation and caches result
  print('First call:');
  final result1 = await pipeline.execute(
    (context) async => expensiveOperation(),
    context: ResilienceContext(operationKey: 'expensive-op'),
  );
  print('Result: $result1');

  // Second call - returns cached result instantly
  print('\nSecond call (from cache):');
  final result2 = await pipeline.execute(
    (context) async => expensiveOperation(),
    context: ResilienceContext(operationKey: 'expensive-op'),
  );
  print('Result: $result2');
}
```

### Custom Cache Configuration

More control over cache behavior:

```dart
import 'package:polly_dart/polly_dart.dart';

void main() async {
  // Create custom cache provider
  final cacheProvider = MemoryCacheProvider(
    defaultTtl: Duration(minutes: 10),
    maxSize: 500,
    cleanupInterval: Duration(minutes: 2),
  );

  // Configure cache strategy
  final pipeline = ResiliencePipelineBuilder()
      .addCache(CacheStrategyOptions<ApiResponse>(
        cache: cacheProvider,
        keyGenerator: (context) => 'api:${context.operationKey}',
        ttl: Duration(minutes: 15),
        shouldCache: (outcome) => outcome.hasResult && outcome.result.isSuccess,
        onHit: (args) async => print('✅ Cache hit: ${args.key}'),
        onMiss: (args) async => print('❌ Cache miss: ${args.key}'),
      ))
      .build();

  // Usage remains the same
  final response = await pipeline.execute(
    (context) => callApi(),
    context: ResilienceContext(operationKey: 'api-call'),
  );
}

class ApiResponse {
  final bool isSuccess;
  final String data;
  
  ApiResponse(this.isSuccess, this.data);
}

Future<ApiResponse> callApi() async {
  // Simulate API call
  await Future.delayed(Duration(milliseconds: 200));
  return ApiResponse(true, 'API data');
}
```

## Advanced Key Generation

### User-Specific Caching

Cache data separately for different users:

```dart
import 'package:polly_dart/polly_dart.dart';

void main() async {
  final pipeline = ResiliencePipelineBuilder()
      .addCache(CacheStrategyOptions<UserProfile>(
        cache: MemoryCacheProvider(defaultTtl: Duration(hours: 1)),
        keyGenerator: (context) {
          final userId = context.getProperty<String>('userId');
          return 'profile:$userId';
        },
      ))
      .build();

  Future<UserProfile> getUserProfile(String userId) async {
    final context = ResilienceContext(operationKey: 'user-profile')
      ..setProperty('userId', userId);
    
    return await pipeline.execute(
      (context) async {
        final userId = context.getProperty<String>('userId');
        print('Fetching profile for user $userId');
        await Future.delayed(Duration(milliseconds: 300));
        return UserProfile(userId!, 'User $userId');
      },
      context: context,
    );
  }

  // Each user gets their own cached profile
  final user1Profile = await getUserProfile('user1');
  final user2Profile = await getUserProfile('user2');
  final user1ProfileCached = await getUserProfile('user1'); // From cache
}

class UserProfile {
  final String id;
  final String name;
  
  UserProfile(this.id, this.name);
}
```

### Multi-Parameter Keys

Include multiple parameters in cache keys:

```dart
Future<SearchResults> searchWithCache(String query, int page, int pageSize) async {
  final pipeline = ResiliencePipelineBuilder()
      .addCache(CacheStrategyOptions<SearchResults>(
        cache: MemoryCacheProvider(defaultTtl: Duration(minutes: 5)),
        keyGenerator: (context) {
          final query = context.getProperty<String>('query');
          final page = context.getProperty<int>('page');
          final pageSize = context.getProperty<int>('pageSize');
          return 'search:$query:$page:$pageSize';
        },
      ))
      .build();

  final context = ResilienceContext(operationKey: 'search')
    ..setProperty('query', query)
    ..setProperty('page', page)
    ..setProperty('pageSize', pageSize);

  return await pipeline.execute(
    (context) async {
      final query = context.getProperty<String>('query');
      final page = context.getProperty<int>('page');
      final pageSize = context.getProperty<int>('pageSize');
      print('Searching: $query (page $page, size $pageSize)');
      await Future.delayed(Duration(milliseconds: 400));
      return SearchResults(query!, page!, ['Result 1', 'Result 2']);
    },
    context: context,
  );
}

class SearchResults {
  final String query;
  final int page;
  final List<String> results;
  
  SearchResults(this.query, this.page, this.results);
}
```

## Integration with Other Strategies

### Cache + Retry

Combine caching with retry for robust API calls:

```dart
import 'package:polly_dart/polly_dart.dart';

void main() async {
  final pipeline = ResiliencePipelineBuilder()
      // First retry on failures
      .addRetry(RetryStrategyOptions(
        maxRetryAttempts: 3,
        delay: Duration(milliseconds: 100),
      ))
      // Then cache successful results
      .addCache(CacheStrategyOptions<String>(
        cache: MemoryCacheProvider(defaultTtl: Duration(minutes: 10)),
        keyGenerator: (context) => 'api-call',
        onHit: (args) async => print('Using cached result'),
        onMiss: (args) async => print('Cache miss, will retry if needed'),
      ))
      .build();

  int attempts = 0;
  Future<String> unreliableApiCall() async {
    attempts++;
    print('API attempt #$attempts');
    
    // Fail first 2 attempts, succeed on 3rd
    if (attempts < 3) {
      throw Exception('API temporarily unavailable');
    }
    
    return 'API Success!';
  }

  // First call - executes operation and caches result
  print('First call:');
  final result1 = await pipeline.execute(
    (context) => unreliableApiCall(),
    context: ResilienceContext(operationKey: 'api-call'),
  );
  print('Result: $result1');

  // Second call - returns cached result instantly
  print('\nSecond call (from cache):');
  final result2 = await pipeline.execute(
    (context) => unreliableApiCall(),
    context: ResilienceContext(operationKey: 'api-call'),
  );
  print('Result: $result2');
}
```

### Cache + Circuit Breaker

Protect external services while maintaining performance:

```dart
import 'package:polly_dart/polly_dart.dart';

void main() async {
  final pipeline = ResiliencePipelineBuilder()
      // Circuit breaker to protect external service
      .addCircuitBreaker(CircuitBreakerStrategyOptions(
        failureThreshold: 3,
        recoveryTimeout: Duration(seconds: 30),
      ))
      // Cache to reduce load on external service
      .addCache(CacheStrategyOptions<ServiceData>(
        cache: MemoryCacheProvider(defaultTtl: Duration(minutes: 5)),
        keyGenerator: (context) => 'external-service-data',
        onHit: (args) async => print('Cache hit - circuit breaker bypassed'),
      ))
      .build();

  Future<ServiceData> callExternalService() async {
    print('Calling external service...');
    // Simulate external service call
    await Future.delayed(Duration(milliseconds: 200));
    
    // Simulate occasional failures
    if (DateTime.now().millisecond % 3 == 0) {
      throw Exception('External service error');
    }
    
    return ServiceData('External data');
  }

  // Multiple calls - cache hits will bypass circuit breaker
  for (int i = 1; i <= 5; i++) {
    try {
      print('\n--- Call $i ---');
      final result = await pipeline.execute(
        (context) => callExternalService(),
        context: ResilienceContext(operationKey: 'external-service'),
      );
      print('Success: ${result.data}');
    } catch (e) {
      print('Failed: $e');
    }
  }
}

class ServiceData {
  final String data;
  ServiceData(this.data);
}
```

## Performance Monitoring

### Basic Metrics Collection

Monitor cache performance with built-in metrics:

```dart
import 'package:polly_dart/polly_dart.dart';

void main() async {
  // Wrap cache provider with metrics collection
  final baseCache = MemoryCacheProvider(defaultTtl: Duration(minutes: 5));
  final metricsCache = MetricsCollectingCacheProvider(baseCache);

  final pipeline = ResiliencePipelineBuilder()
      .addCache(CacheStrategyOptions<String>(
        cache: metricsCache,
        keyGenerator: (context) => 'operation',
      ))
      .build();

  Future<String> operation() async {
    await Future.delayed(Duration(milliseconds: 100));
    return 'Operation result';
  }

  // Execute multiple operations
  for (int i = 1; i <= 10; i++) {
    await pipeline.execute(
      (context) => operation(),
      context: ResilienceContext(operationKey: 'operation'),
    );
    
    if (i == 5) {
      // Clear cache midway to show miss behavior
      await metricsCache.clear();
    }
  }

  // Display metrics
  final metrics = metricsCache.metrics;
  print('\n📊 Cache Performance:');
  print('Total operations: ${metrics.totalOperations}');
  print('Cache hits: ${metrics.hits}');
  print('Cache misses: ${metrics.misses}');
  print('Hit ratio: ${(metrics.hitRatio * 100).toStringAsFixed(1)}%');
  print('Average hit time: ${metrics.averageHitTime.inMicroseconds}μs');
  print('Average miss time: ${metrics.averageMissTime.inMicroseconds}μs');
}
```

### Custom Metrics with Callbacks

Implement custom metrics collection:

```dart
import 'package:polly_dart/polly_dart.dart';

class CustomMetrics {
  int totalCalls = 0;
  int cacheHits = 0;
  int cacheMisses = 0;
  Duration totalTime = Duration.zero;
  
  void recordCall(bool wasHit, Duration responseTime) {
    totalCalls++;
    totalTime += responseTime;
    
    if (wasHit) {
      cacheHits++;
    } else {
      cacheMisses++;
    }
  }
  
  void printReport() {
    print('\n📈 Custom Metrics Report:');
    print('Total calls: $totalCalls');
    print('Cache hits: $cacheHits');
    print('Cache misses: $cacheMisses');
    print('Hit ratio: ${((cacheHits / totalCalls) * 100).toStringAsFixed(1)}%');
    print('Average response time: ${(totalTime.inMicroseconds / totalCalls).round()}μs');
  }
}

void main() async {
  final metrics = CustomMetrics();
  
  final pipeline = ResiliencePipelineBuilder()
      .addCache(CacheStrategyOptions<String>(
        cache: MemoryCacheProvider(defaultTtl: Duration(seconds: 30)),
        keyGenerator: (context) => 'operation',
        onHit: (args) async {
          final stopwatch = Stopwatch()..start();
          // Simulate cache hit processing time
          await Future.delayed(Duration(microseconds: 10));
          stopwatch.stop();
          metrics.recordCall(true, stopwatch.elapsed);
        },
        onMiss: (args) async {
          // Miss timing will be recorded after operation completes
        },
      ))
      .build();

  Future<String> operation() async {
    final stopwatch = Stopwatch()..start();
    await Future.delayed(Duration(milliseconds: 50));
    stopwatch.stop();
    
    // Record miss timing (will be called if cache miss occurred)
    metrics.recordCall(false, stopwatch.elapsed);
    
    return 'Operation result';
  }

  // Execute operations
  for (int i = 1; i <= 5; i++) {
    await pipeline.execute(
      (context) => operation(),
      context: ResilienceContext(operationKey: 'operation'),
    );
  }

  metrics.printReport();
}
```

## Real-World Scenarios

### API Response Caching

Complete example for caching API responses:

```dart
import 'package:polly_dart/polly_dart.dart';
import 'dart:convert';

class ApiClient {
  final ResiliencePipeline _pipeline;
  
  ApiClient() : _pipeline = ResiliencePipelineBuilder()
      .addTimeout(Duration(seconds: 30))
      .addRetry(RetryStrategyOptions(maxRetryAttempts: 2))
      .addCache(CacheStrategyOptions<Map<String, dynamic>>(
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
        shouldCache: (outcome) {
          // Only cache successful responses
          if (!outcome.hasResult) return false;
          final response = outcome.result;
          return response['status'] == 'success';
        },
        onHit: (args) async => print('📋 Cache hit: ${args.key}'),
        onMiss: (args) async => print('🌐 API call: ${args.key}'),
      ))
      .build();

  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? params}) async {
    final context = ResilienceContext(operationKey: 'api-call')
      ..setProperty('endpoint', endpoint)
      ..setProperty('params', params ?? <String, String>{});

    return await _pipeline.execute(
      (context) {
        final endpoint = context.getProperty<String>('endpoint');
        final params = context.getProperty<Map<String, String>>('params');
        return _makeApiCall(endpoint!, params);
      },
      context: context,
    );
  }

  Future<Map<String, dynamic>> _makeApiCall(String endpoint, Map<String, String>? params) async {
    print('Making HTTP request to $endpoint');
    await Future.delayed(Duration(milliseconds: 200)); // Simulate network call
    
    return {
      'status': 'success',
      'data': {'endpoint': endpoint, 'timestamp': DateTime.now().toIso8601String()},
      'params': params,
    };
  }
}

void main() async {
  final client = ApiClient();

  // First call - cache miss, makes HTTP request
  print('=== First call ===');
  final response1 = await client.get('/users', params: {'page': '1'});
  print('Response: ${response1['data']}');

  // Second call - cache hit, no HTTP request
  print('\n=== Second call (same params) ===');
  final response2 = await client.get('/users', params: {'page': '1'});
  print('Response: ${response2['data']}');

  // Third call - different params, cache miss
  print('\n=== Third call (different params) ===');
  final response3 = await client.get('/users', params: {'page': '2'});
  print('Response: ${response3['data']}');
}
```

### Database Query Caching

Cache expensive database queries:

```dart
import 'package:polly_dart/polly_dart.dart';

class DatabaseClient {
  final ResiliencePipeline _pipeline;
  
  DatabaseClient() : _pipeline = ResiliencePipelineBuilder()
      .addCache(CacheStrategyOptions<List<Map<String, dynamic>>>(
        cache: MemoryCacheProvider(
          defaultTtl: Duration(minutes: 10),
          maxSize: 100,
        ),
        keyGenerator: (context) {
          final sql = context.getProperty<String>('sql');
          final params = context.getProperty<List<dynamic>>('params') ?? [];
          final paramHash = params.map((p) => p.toString()).join('|');
          return 'query:${sql.hashCode}:$paramHash';
        },
        shouldCache: (outcome) {
          // Only cache non-empty results
          return outcome.hasResult && outcome.result.isNotEmpty;
        },
        onHit: (args) async => print('📊 Query cache hit'),
        onMiss: (args) async => print('🗄️  Executing database query'),
      ))
      .build();

  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? params]) async {
    final context = ResilienceContext(operationKey: 'db-query')
      ..setProperty('sql', sql)
      ..setProperty('params', params ?? []);

    return await _pipeline.execute(
      (context) {
        final sql = context.getProperty<String>('sql');
        final params = context.getProperty<List<dynamic>>('params');
        return _executeQuery(sql!, params);
      },
      context: context,
    );
  }

  Future<List<Map<String, dynamic>>> _executeQuery(String sql, List<dynamic>? params) async {
    print('Executing SQL: $sql');
    if (params?.isNotEmpty == true) {
      print('Parameters: $params');
    }
    
    // Simulate database query time
    await Future.delayed(Duration(milliseconds: 300));
    
    // Simulate query results
    return [
      {'id': 1, 'name': 'John Doe', 'email': 'john@example.com'},
      {'id': 2, 'name': 'Jane Smith', 'email': 'jane@example.com'},
    ];
  }
}

void main() async {
  final db = DatabaseClient();

  // First query - cache miss
  print('=== First query ===');
  final users1 = await db.query('SELECT * FROM users WHERE active = ?', [true]);
  print('Found ${users1.length} users');

  // Same query - cache hit
  print('\n=== Same query (cached) ===');
  final users2 = await db.query('SELECT * FROM users WHERE active = ?', [true]);
  print('Found ${users2.length} users');

  // Different query - cache miss
  print('\n=== Different query ===');
  final users3 = await db.query('SELECT * FROM users WHERE active = ?', [false]);
  print('Found ${users3.length} users');
}
```

These examples demonstrate the flexibility and power of the cache strategy in various real-world scenarios. The cache strategy can significantly improve application performance by reducing redundant operations while maintaining data consistency and reliability.
