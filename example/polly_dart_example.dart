import 'dart:async';
import 'dart:math';

import 'package:polly_dart/polly_dart.dart';

/// Example demonstrating various Polly resilience strategies.
void main() async {
  print('Polly Dart Examples');
  print('===================\n');

  await retryExample();
  await timeoutExample();
  await circuitBreakerExample();
  await fallbackExample();
  await hedgingExample();
  await rateLimiterExample();
  await combinedStrategiesExample();
  await basicCachingExample();
  await customKeyGenerationExample();
  await cacheWithCallbacksExample();
  await cacheWithOtherStrategiesExample();
  await advancedCacheConfigurationExample();
  await cacheMetricsExample();
}

/// Demonstrates retry strategy with exponential backoff.
Future<void> retryExample() async {
  print('1. Retry Strategy Example');
  print('-------------------------');

  final pipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions(
        maxRetryAttempts: 3,
        delay: Duration(milliseconds: 500),
        backoffType: DelayBackoffType.exponential,
        useJitter: true,
        onRetry: (args) async {
          print(
              '  Retry attempt ${args.attemptNumber + 1} after ${args.delay.inMilliseconds}ms delay');
        },
      ))
      .build();

  try {
    final result = await pipeline.execute((context) async {
      print('  Executing potentially failing operation...');

      // Simulate a flaky operation (70% failure rate)
      if (Random().nextDouble() < 0.7) {
        throw Exception('Simulated transient failure');
      }

      return 'Success!';
    });

    print('  Result: $result');
  } catch (e) {
    print('  Final failure: $e');
  }

  print('');
}

/// Demonstrates timeout strategy.
Future<void> timeoutExample() async {
  print('2. Timeout Strategy Example');
  print('---------------------------');

  final pipeline =
      ResiliencePipelineBuilder().addTimeout(Duration(seconds: 2)).build();

  try {
    final result = await pipeline.execute((context) async {
      print('  Starting slow operation...');

      // Simulate a slow operation
      await Future.delayed(Duration(seconds: 3));

      return 'This should timeout';
    });

    print('  Result: $result');
  } catch (e) {
    print('  Timeout occurred: ${e.runtimeType}');
  }

  print('');
}

/// Demonstrates circuit breaker strategy.
Future<void> circuitBreakerExample() async {
  print('3. Circuit Breaker Strategy Example');
  print('-----------------------------------');

  final stateProvider = CircuitBreakerStateProvider();
  final pipeline = ResiliencePipelineBuilder()
      .addCircuitBreaker(CircuitBreakerStrategyOptions(
        failureRatio: 0.5,
        minimumThroughput: 3,
        samplingDuration: Duration(seconds: 10),
        breakDuration: Duration(seconds: 2),
        stateProvider: stateProvider,
        onOpened: (args) async {
          print('  Circuit breaker opened!');
        },
        onClosed: (args) async {
          print('  Circuit breaker closed.');
        },
      ))
      .build();

  print('  Circuit state: ${stateProvider.circuitState}');

  // Execute several failing operations to trigger circuit breaker
  for (int i = 0; i < 5; i++) {
    try {
      await pipeline.execute((context) async {
        print('  Attempt ${i + 1}...');
        throw Exception('Simulated failure');
      });
    } catch (e) {
      print('  Failed: ${e.runtimeType}');
    }

    print('  Circuit state: ${stateProvider.circuitState}');
    await Future.delayed(Duration(milliseconds: 100));
  }

  print('');
}

/// Demonstrates fallback strategy.
Future<void> fallbackExample() async {
  print('4. Fallback Strategy Example');
  print('----------------------------');

  final pipeline = TypedResiliencePipelineBuilder<String>()
      .addFallback(FallbackStrategyOptions<String>(
        fallbackAction: (args) async {
          print('  Executing fallback action...');
          return Outcome.fromResult('Fallback result');
        },
        onFallback: (args) async {
          print('  Primary operation failed, using fallback');
        },
      ))
      .build();

  try {
    final result = await pipeline.execute((context) async {
      print('  Executing primary operation...');
      throw Exception('Primary operation failed');
    });

    print('  Result: $result');
  } catch (e) {
    print('  Unexpected error: $e');
  }

  print('');
}

/// Demonstrates hedging strategy.
Future<void> hedgingExample() async {
  print('5. Hedging Strategy Example');
  print('---------------------------');

  final pipeline = TypedResiliencePipelineBuilder<String>()
      .addHedging(HedgingStrategyOptions<String>(
        maxHedgedAttempts: 2,
        delay: Duration(milliseconds: 500),
        onHedging: (args) async {
          print('  Starting hedged attempt ${args.attemptNumber + 1}...');
        },
      ))
      .build();

  final stopwatch = Stopwatch()..start();

  try {
    final result = await pipeline.execute((context) async {
      final delay = Duration(milliseconds: 800 + Random().nextInt(400));
      print(
          '  Attempt ${context.attemptNumber + 1} will take ${delay.inMilliseconds}ms');

      await Future.delayed(delay);
      return 'Result from attempt ${context.attemptNumber + 1}';
    });

    stopwatch.stop();
    print('  Result: $result');
    print('  Total time: ${stopwatch.elapsedMilliseconds}ms');
  } catch (e) {
    print('  Error: $e');
  }

  print('');
}

/// Demonstrates rate limiter strategy.
Future<void> rateLimiterExample() async {
  print('6. Rate Limiter Strategy Example');
  print('--------------------------------');

  final pipeline = ResiliencePipelineBuilder()
      .addRateLimiter(RateLimiterStrategyOptions.slidingWindow(
        permitLimit: 3,
        window: Duration(seconds: 2),
        onRejected: (args) async {
          print('  Request rejected: ${args.reason}');
        },
      ))
      .build();

  // Try to execute 5 requests rapidly
  final futures = <Future>[];
  for (int i = 0; i < 5; i++) {
    futures.add(pipeline.execute((context) async {
      print('  Request ${i + 1} executing...');
      await Future.delayed(Duration(milliseconds: 100));
      return 'Response ${i + 1}';
    }).catchError((e) {
      return 'Rejected';
    }));
  }

  final results = await Future.wait(futures);
  for (int i = 0; i < results.length; i++) {
    print('  Request ${i + 1} result: ${results[i]}');
  }

  print('');
}

/// Demonstrates combining multiple strategies.
Future<void> combinedStrategiesExample() async {
  print('7. Combined Strategies Example');
  print('------------------------------');

  final pipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions(
        maxRetryAttempts: 2,
        delay: Duration(milliseconds: 200),
      ))
      .addTimeout(Duration(seconds: 5))
      .addCircuitBreaker(CircuitBreakerStrategyOptions(
        failureRatio: 0.8,
        minimumThroughput: 2,
      ))
      .build();

  for (int i = 0; i < 3; i++) {
    try {
      final result = await pipeline.execute((context) async {
        print('  Execution ${i + 1}, attempt ${context.attemptNumber + 1}');

        // Simulate occasional failures
        if (Random().nextDouble() < 0.6) {
          throw Exception('Simulated failure');
        }

        return 'Success on execution ${i + 1}';
      });

      print('  Result: $result');
    } catch (e) {
      print('  Failed: ${e.runtimeType}');
    }

    await Future.delayed(Duration(milliseconds: 100));
  }

  print('');
  print('Examples completed!');
}

/// Example 1: Basic Memory Caching
///
/// Demonstrates the simplest cache setup with default configuration.
Future<void> basicCachingExample() async {
  print('\n=== Basic Caching Example ===');

  // Create a pipeline with basic memory caching
  final cacheProvider = MemoryCacheProvider(
    defaultTtl: Duration(minutes: 5),
    maxSize: 1000,
  );

  final pipeline = ResiliencePipelineBuilder()
      .addCache(CacheStrategyOptions<String>(
        cache: cacheProvider,
        keyGenerator: (context) =>
            'expensive-operation', // Fixed key for this example
      ))
      .build();

  // Simulate an expensive operation
  var callCount = 0;
  Future<String> expensiveOperation() async {
    callCount++;
    print('Executing expensive operation (call #$callCount)');
    await Future.delayed(Duration(milliseconds: 100)); // Simulate work
    return 'Expensive result $callCount';
  }

  // First call - will execute the operation and cache the result
  print('First call:');
  final result1 =
      await pipeline.execute<String>((context) => expensiveOperation());
  print('Result: $result1');
  print('Call count: $callCount\n');

  // Second call - will return cached result without executing operation
  print('Second call (should use cache):');
  final result2 =
      await pipeline.execute<String>((context) => expensiveOperation());
  print('Result: $result2');
  print('Call count: $callCount (should still be 1)');
}

/// Example 2: Custom Key Generation
///
/// Shows how to use custom cache keys for different contexts.
Future<void> customKeyGenerationExample() async {
  print('\n=== Custom Key Generation Example ===');

  // Create cache provider
  final cacheProvider = MemoryCacheProvider(
    maxSize: 100,
    defaultTtl: Duration(minutes: 10),
  );

  // Pipeline with custom key generation based on user context
  final pipeline = ResiliencePipelineBuilder()
      .addCache(CacheStrategyOptions<String>(
        cache: cacheProvider,
        keyGenerator: (context) {
          final userId = context.getProperty<String>('userId');
          final operation = context.getProperty<String>('operation');
          return 'user:$userId:$operation';
        },
        ttl: Duration(seconds: 30),
      ))
      .build();

  // Helper to create user-specific contexts
  ResilienceContext createUserContext(String userId, String operation) {
    final context = ResilienceContext();
    context.setProperty('userId', userId);
    context.setProperty('operation', operation);
    return context;
  }

  var callCount = 0;
  Future<String> getUserData(String userId) async {
    callCount++;
    print('Fetching data for user $userId (call #$callCount)');
    return 'Data for user $userId';
  }

  // Call for user1 - will cache with key "user:user1:getData"
  print('Getting data for user1 (first time):');
  final context1 = createUserContext('user1', 'getData');
  final result1 = await pipeline.execute(
    (ctx) => getUserData('user1'),
    context: context1,
  );
  print('Result: $result1');
  print('Call count: $callCount\n');

  // Call for user2 - different key, will execute
  print('Getting data for user2 (different user):');
  final context2 = createUserContext('user2', 'getData');
  final result2 = await pipeline.execute(
    (ctx) => getUserData('user2'),
    context: context2,
  );
  print('Result: $result2');
  print('Call count: $callCount\n');

  // Call for user1 again - should use cache
  print('Getting data for user1 again (should use cache):');
  final context3 = createUserContext('user1', 'getData');
  final result3 = await pipeline.execute(
    (ctx) => getUserData('user1'),
    context: context3,
  );
  print('Result: $result3');
  print('Call count: $callCount (should still be 2)');
}

/// Example 3: Cache with Callbacks
///
/// Demonstrates monitoring cache behavior with callbacks.
Future<void> cacheWithCallbacksExample() async {
  print('\n=== Cache with Callbacks Example ===');

  var hitCount = 0;
  var missCount = 0;
  var setCount = 0;

  final pipeline = ResiliencePipelineBuilder()
      .addCache(CacheStrategyOptions<String>(
        cache: MemoryCacheProvider(defaultTtl: Duration(seconds: 5)),
        keyGenerator: (context) => 'api-call',
        onHit: (args) async {
          hitCount++;
          print('🎯 Cache HIT for key: ${args.key} -> ${args.value}');
        },
        onMiss: (args) async {
          missCount++;
          print('❌ Cache MISS for key: ${args.key}');
        },
        onSet: (args) async {
          setCount++;
          print('💾 Cache SET for key: ${args.key} -> ${args.value}');
        },
      ))
      .build();

  Future<String> apiCall() async {
    print('Making API call...');
    await Future.delayed(Duration(milliseconds: 50));
    return 'API Response ${DateTime.now().millisecondsSinceEpoch}';
  }

  // First call - cache miss
  print('Call 1 (cache miss expected):');
  await pipeline.execute((ctx) => apiCall());

  // Second call - cache hit
  print('\nCall 2 (cache hit expected):');
  await pipeline.execute((ctx) => apiCall());

  // Wait for TTL to expire
  print('\nWaiting for cache to expire...');
  await Future.delayed(Duration(seconds: 6));

  // Third call - cache miss due to expiration
  print('\nCall 3 (cache miss due to expiration):');
  await pipeline.execute((ctx) => apiCall());

  print('\n📊 Final stats:');
  print('Cache hits: $hitCount');
  print('Cache misses: $missCount');
  print('Cache sets: $setCount');
}

/// Example 4: Cache with Other Strategies
///
/// Shows how caching integrates with retry, timeout, and circuit breaker.
Future<void> cacheWithOtherStrategiesExample() async {
  print('\n=== Cache with Other Strategies Example ===');

  // Pipeline combining multiple strategies
  final pipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions(
        maxRetryAttempts: 3,
        delay: Duration(milliseconds: 100),
      ))
      .addTimeout(Duration(seconds: 2))
      .addCache(CacheStrategyOptions<String>(
        cache: MemoryCacheProvider(defaultTtl: Duration(minutes: 1)),
        keyGenerator: (context) => 'resilient-api-call',
        onHit: (args) async => print('✅ Using cached result: ${args.value}'),
        onMiss: (args) async =>
            print('🔄 Cache miss, executing with resilience...'),
      ))
      .build();

  var attemptCount = 0;

  Future<String> unreliableApiCall() async {
    attemptCount++;
    print('API attempt #$attemptCount');

    // Fail first 2 attempts, succeed on 3rd
    if (attemptCount < 3) {
      throw Exception('API temporarily unavailable');
    }

    return 'Success after retries!';
  }

  // First call - will retry and eventually succeed, then cache
  print('First call (will retry and cache result):');
  try {
    final result1 = await pipeline.execute((ctx) => unreliableApiCall());
    print('Result: $result1');
  } catch (e) {
    print('Failed: $e');
  }

  // Reset attempt counter for second call
  attemptCount = 0;

  // Second call - should use cache, no retries needed
  print('\nSecond call (should use cache, no retries):');
  try {
    final result2 = await pipeline.execute((ctx) => unreliableApiCall());
    print('Result: $result2');
    print('Attempt count: $attemptCount (should be 0 due to cache hit)');
  } catch (e) {
    print('Failed: $e');
  }
}

/// Example 5: Advanced Cache Configuration
///
/// Demonstrates advanced caching features and edge cases.
Future<void> advancedCacheConfigurationExample() async {
  print('\n=== Advanced Cache Configuration Example ===');

  // Cache with custom shouldCache predicate
  final pipeline = ResiliencePipelineBuilder()
      .addCache(CacheStrategyOptions<Map<String, dynamic>>(
        cache: MemoryCacheProvider(
          maxSize: 50,
          defaultTtl: Duration(seconds: 10),
        ),
        keyGenerator: (context) {
          final endpoint = context.getProperty<String>('endpoint');
          final params = context.getProperty<Map<String, String>>('params');
          final paramString =
              params?.entries.map((e) => '${e.key}=${e.value}').join('&') ?? '';
          return '$endpoint?$paramString';
        },
        shouldCache: (outcome) {
          // Only cache successful responses with data
          if (!outcome.hasResult) return false;
          final data = outcome.result;
          return data.isNotEmpty && data['status'] == 'success';
        },
        onHit: (args) async => print('📋 Cache hit for: ${args.key}'),
        onMiss: (args) async => print('🔍 Cache miss for: ${args.key}'),
        ttl: Duration(seconds: 15),
      ))
      .build();

  Future<Map<String, dynamic>> apiCall(
      String endpoint, Map<String, String> params, bool shouldSucceed) async {
    print('Calling $endpoint with params: $params');
    await Future.delayed(Duration(milliseconds: 100));

    if (shouldSucceed) {
      return {
        'status': 'success',
        'data': {
          'endpoint': endpoint,
          'timestamp': DateTime.now().toIso8601String()
        },
        'params': params,
      };
    } else {
      return {
        'status': 'error',
        'message': 'Something went wrong',
      };
    }
  }

  // Helper to create context with endpoint and params
  ResilienceContext createApiContext(
      String endpoint, Map<String, String> params) {
    final context = ResilienceContext();
    context.setProperty('endpoint', endpoint);
    context.setProperty('params', params);
    return context;
  }

  // Call 1: Successful call - will be cached
  print('Call 1 (successful, will be cached):');
  final context1 = createApiContext('/users', {'page': '1', 'limit': '10'});
  final result1 = await pipeline.execute(
    (ctx) => apiCall('/users', {'page': '1', 'limit': '10'}, true),
    context: context1,
  );
  print('Result: ${result1['status']}\n');

  // Call 2: Same endpoint and params - should use cache
  print('Call 2 (same params, should use cache):');
  final context2 = createApiContext('/users', {'page': '1', 'limit': '10'});
  final result2 = await pipeline.execute(
    (ctx) => apiCall('/users', {'page': '1', 'limit': '10'}, true),
    context: context2,
  );
  print('Result: ${result2['status']}\n');

  // Call 3: Error response - should NOT be cached
  print('Call 3 (error response, should not be cached):');
  final context3 = createApiContext('/users', {'page': '2', 'limit': '10'});
  final result3 = await pipeline.execute(
    (ctx) => apiCall('/users', {'page': '2', 'limit': '10'}, false),
    context: context3,
  );
  print('Result: ${result3['status']}\n');

  // Call 4: Same as call 3 - should execute again (not cached due to error)
  print('Call 4 (same as error call, should execute again):');
  final context4 = createApiContext('/users', {'page': '2', 'limit': '10'});
  final result4 = await pipeline.execute(
    (ctx) => apiCall('/users', {'page': '2', 'limit': '10'}, false),
    context: context4,
  );
  print('Result: ${result4['status']}');
}

/// Example 6: Cache Metrics (Basic Implementation)
///
/// Demonstrates basic cache metrics collection.
Future<void> cacheMetricsExample() async {
  print('\n=== Cache Metrics Example ===');

  // Create cache provider with metrics collection
  final baseCacheProvider =
      MemoryCacheProvider(defaultTtl: Duration(seconds: 5));
  final metricsCache = MetricsCollectingCacheProvider(baseCacheProvider);

  final pipeline = ResiliencePipelineBuilder()
      .addCache(CacheStrategyOptions<String>(
        cache: metricsCache,
        keyGenerator: (context) => 'metrics-test',
        onHit: (args) async {
          print('✅ Cache hit: ${args.value}');
        },
        onMiss: (args) async {
          print('❌ Cache miss for key: ${args.key}');
        },
      ))
      .build();

  Future<String> operation() async {
    await Future.delayed(Duration(milliseconds: 50));
    return 'Operation result';
  }

  // Execute multiple operations
  for (int i = 1; i <= 5; i++) {
    print('\nOperation $i:');
    await pipeline.execute<String>((ctx) => operation());

    if (i == 2) {
      // Clear cache after second operation to demonstrate miss behavior
      print('Clearing cache...');
      await metricsCache.clear();
    }
  }

  // Print final metrics
  print('\n📊 Final Cache Metrics:');
  final metrics = metricsCache.metrics;
  print('Total operations: ${metrics.totalOperations}');
  print('Cache hits: ${metrics.hits}');
  print('Cache misses: ${metrics.misses}');
  print('Cache sets: ${metrics.sets}');
  print('Hit ratio: ${(metrics.hitRatio * 100).toStringAsFixed(1)}%');
  print('Average hit time: ${metrics.averageHitTime.inMicroseconds}μs');
  print('Average miss time: ${metrics.averageMissTime.inMicroseconds}μs');
}

/// Simple cache metrics collector (kept for backwards compatibility)
class CacheMetrics {
  int hits = 0;
  int misses = 0;

  void recordHit() => hits++;
  void recordMiss() => misses++;

  int get totalOperations => hits + misses;
  double get hitRatio => totalOperations > 0 ? hits / totalOperations : 0.0;
}
