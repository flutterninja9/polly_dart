---
sidebar_position: 6
---

# Hedging Strategy

The **Hedging Strategy** launches multiple parallel operations against the same resource and returns the result from whichever completes first. This proactive approach reduces tail latency and improves response times when some requests may be slower than others.

## When to Use Hedging

Hedging is ideal for:

- 🚀 **Latency optimization** when response time is critical
- 🌐 **Multi-region requests** to different geographical locations
- 📡 **Multiple API endpoints** serving identical data
- 🔄 **Load balancing** across multiple service instances
- 📱 **Mobile networks** with variable connection quality
- ☁️ **Cloud services** with occasional slow responses
- 🎯 **SLA requirements** demanding consistent response times

:::tip Performance vs Cost Trade-off
Hedging trades increased resource usage (multiple concurrent requests) for better performance. Use it when latency matters more than resource efficiency.
:::

## Basic Usage

### Simple Hedging
```dart
import 'package:polly_dart/polly_dart.dart';

final pipeline = ResiliencePipelineBuilder()
    .addHedging(HedgingStrategyOptions(
      maxHedgedAttempts: 2,
      delay: Duration(milliseconds: 100),
    ))
    .build();

final result = await pipeline.execute((context) async {
  return await fetchDataFromService();
});
// Launches hedged requests if primary takes longer than 100ms
```

### Hedging Multiple Endpoints
```dart
final endpoints = [
  'https://api-us.example.com',
  'https://api-eu.example.com',
  'https://api-asia.example.com',
];

final hedgingPipeline = ResiliencePipelineBuilder()
    .addHedging(HedgingStrategyOptions(
      maxHedgedAttempts: endpoints.length - 1,
      delay: Duration(milliseconds: 50),
      actionGenerator: (attempt) async {
        final endpoint = endpoints[attempt % endpoints.length];
        return await httpClient.get(endpoint);
      },
    ))
    .build();
```

## Configuration Options

### HedgingStrategyOptions

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `maxHedgedAttempts` | `int` | `1` | Maximum number of hedged attempts to run concurrently |
| `delay` | `Duration` | `Duration(milliseconds: 2)` | Delay before launching each hedged attempt |
| `actionGenerator` | `HedgingActionGenerator<T>?` | `null` | Generator for creating hedged actions (uses original if null) |
| `shouldHandle` | `ShouldHandlePredicate<T>?` | `null` | Predicate to determine which results should trigger hedging |
| `onHedging` | `OnHedgingCallback<T>?` | `null` | Callback invoked when hedging is activated |

### Type Definitions

```dart
typedef HedgingActionGenerator<T> = Future<Outcome<T>> Function(int attemptNumber);
typedef OnHedgingCallback<T> = Future<void> Function(OnHedgingArguments<T> args);
```

## Hedging Patterns

### Latency-Based Hedging
Launch hedged attempts when primary request is slow:

```dart
final latencyOptimizedPipeline = ResiliencePipelineBuilder()
    .addHedging(HedgingStrategyOptions(
      maxHedgedAttempts: 2,
      delay: Duration(milliseconds: 100), // If primary takes >100ms, hedge
      onHedging: (args) async {
        logger.info('Hedging activated after ${args.duration.inMilliseconds}ms');
      },
    ))
    .build();

Future<UserData> getUserData(int userId) async {
  return await latencyOptimizedPipeline.execute((context) async {
    return await userService.getUser(userId);
  });
}
```

### Multi-Region Hedging
Try different geographical regions for better performance:

```dart
class MultiRegionApiClient {
  final List<String> _regions = [
    'us-east-1',
    'eu-west-1', 
    'ap-southeast-1',
  ];
  
  late final ResiliencePipeline _pipeline = ResiliencePipelineBuilder()
      .addHedging(HedgingStrategyOptions(
        maxHedgedAttempts: _regions.length - 1,
        delay: Duration(milliseconds: 50),
        actionGenerator: (attemptNumber) => _callRegion(attemptNumber),
        onHedging: (args) => _logHedgingAttempt(args),
      ))
      .build();

  Future<ApiResponse> getData(String path) async {
    final context = ResilienceContext(operationKey: 'multi-region-api');
    context.setProperty('path', path);
    
    return await _pipeline.execute((ctx) async {
      // Primary attempt uses the first region
      return await _callRegion(0);
    }, context: context);
  }

  Future<Outcome<ApiResponse>> _callRegion(int regionIndex) async {
    final region = _regions[regionIndex % _regions.length];
    final baseUrl = 'https://api-$region.example.com';
    
    try {
      final response = await httpClient.get('$baseUrl${context.getProperty('path')}');
      
      logger.info('Response received from region: $region');
      return Outcome.fromResult(ApiResponse.fromJson(response.data));
    } catch (e) {
      logger.warning('Request failed for region $region: $e');
      return Outcome.fromException(e);
    }
  }

  Future<void> _logHedgingAttempt(OnHedgingArguments args) async {
    logger.info('Hedging activated for ${args.context.operationKey}');
    
    // Track metrics by region
    metrics.incrementCounter('api_hedging_activated', tags: {
      'operation': args.context.operationKey ?? 'unknown',
    });
  }
}
```

### Load Balancer Hedging
Distribute requests across multiple service instances:

```dart
class LoadBalancedService {
  final List<String> _serviceInstances;
  
  LoadBalancedService(this._serviceInstances);

  late final ResiliencePipeline _pipeline = ResiliencePipelineBuilder()
      .addHedging(HedgingStrategyOptions(
        maxHedgedAttempts: min(_serviceInstances.length - 1, 3),
        delay: Duration(milliseconds: 75),
        actionGenerator: _generateInstanceCall,
        shouldHandle: (outcome) {
          // Only hedge if we get server errors, not client errors
          if (!outcome.hasException) return false;
          
          final exception = outcome.exception;
          return exception is SocketException ||
                 exception is TimeoutException ||
                 (exception is HttpException && 
                  exception.message.contains('50'));
        },
      ))
      .build();

  Future<ServiceResponse> callService(ServiceRequest request) async {
    final context = ResilienceContext();
    context.setProperty('request', request);
    
    return await _pipeline.execute((ctx) async {
      return await _callInstance(0, request);
    }, context: context);
  }

  Future<Outcome<ServiceResponse>> _generateInstanceCall(int attemptNumber) async {
    final request = context.getProperty<ServiceRequest>('request')!;
    
    try {
      return Outcome.fromResult(await _callInstance(attemptNumber, request));
    } catch (e) {
      return Outcome.fromException(e);
    }
  }

  Future<ServiceResponse> _callInstance(int instanceIndex, ServiceRequest request) async {
    final instance = _serviceInstances[instanceIndex % _serviceInstances.length];
    
    logger.debug('Calling service instance: $instance');
    
    final response = await httpClient.post(
      '$instance/api/service',
      data: request.toJson(),
    );
    
    return ServiceResponse.fromJson(response.data);
  }
}
```

### Conditional Hedging
Only hedge based on specific conditions:

```dart
final conditionalHedgingPipeline = ResiliencePipelineBuilder()
    .addHedging(HedgingStrategyOptions(
      maxHedgedAttempts: 2,
      delay: Duration(milliseconds: 200),
      shouldHandle: (outcome) {
        // Only hedge during peak hours or for critical operations
        final now = DateTime.now();
        final isPeakHours = now.hour >= 9 && now.hour <= 17;
        final isCritical = context.getProperty<bool>('critical') ?? false;
        
        return isPeakHours || isCritical;
      },
      onHedging: (args) async {
        logger.info('Conditional hedging activated: ${args.context.properties}');
      },
    ))
    .build();

// Usage with critical flag
Future<ImportantData> getCriticalData(int id) async {
  final context = ResilienceContext();
  context.setProperty('critical', true);
  
  return await conditionalHedgingPipeline.execute((ctx) async {
    return await criticalDataService.getData(id);
  }, context: context);
}
```

## Advanced Hedging Patterns

### Adaptive Hedging with Performance Tracking
Adjust hedging behavior based on historical performance:

```dart
class AdaptiveHedgingService {
  final Map<String, PerformanceMetrics> _endpointMetrics = {};
  
  ResiliencePipeline _createAdaptivePipeline(String endpoint) {
    final metrics = _endpointMetrics[endpoint] ?? PerformanceMetrics();
    
    return ResiliencePipelineBuilder()
        .addHedging(HedgingStrategyOptions(
          maxHedgedAttempts: _calculateOptimalAttempts(metrics),
          delay: _calculateOptimalDelay(metrics),
          onHedging: (args) => _updateMetrics(endpoint, args),
        ))
        .build();
  }

  int _calculateOptimalAttempts(PerformanceMetrics metrics) {
    // More attempts for endpoints with higher variance
    if (metrics.responseTimeVariance > 1000) return 3;
    if (metrics.responseTimeVariance > 500) return 2;
    return 1;
  }

  Duration _calculateOptimalDelay(PerformanceMetrics metrics) {
    // Shorter delay for consistently slow endpoints
    final p95 = metrics.percentile95ResponseTime;
    return Duration(milliseconds: (p95 * 0.3).round().clamp(50, 500));
  }

  Future<void> _updateMetrics(String endpoint, OnHedgingArguments args) async {
    final metrics = _endpointMetrics.putIfAbsent(endpoint, () => PerformanceMetrics());
    metrics.recordHedgingEvent(args.duration);
    
    // Periodically adjust pipeline configuration
    if (metrics.sampleCount % 100 == 0) {
      logger.info('Updating hedging configuration for $endpoint based on metrics');
    }
  }
}

class PerformanceMetrics {
  final List<int> _responseTimes = [];
  int hedgingActivations = 0;
  int sampleCount = 0;

  double get responseTimeVariance {
    if (_responseTimes.length < 2) return 0;
    
    final mean = _responseTimes.reduce((a, b) => a + b) / _responseTimes.length;
    final variance = _responseTimes
        .map((time) => pow(time - mean, 2))
        .reduce((a, b) => a + b) / _responseTimes.length;
    
    return variance;
  }

  int get percentile95ResponseTime {
    if (_responseTimes.isEmpty) return 1000;
    
    final sorted = List<int>.from(_responseTimes)..sort();
    final index = (sorted.length * 0.95).floor();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  void recordHedgingEvent(Duration responseTime) {
    _responseTimes.add(responseTime.inMilliseconds);
    hedgingActivations++;
    sampleCount++;
    
    // Keep only recent samples
    if (_responseTimes.length > 1000) {
      _responseTimes.removeRange(0, 500);
    }
  }
}
```

### Smart Content Delivery with Hedging
```dart
class ContentDeliveryService {
  final List<String> _cdnEndpoints;
  final GeolocationService _geolocation;
  
  ContentDeliveryService(this._cdnEndpoints, this._geolocation);

  Future<ContentResponse> getContent(String contentId) async {
    final userLocation = await _geolocation.getCurrentLocation();
    final rankedEndpoints = _rankEndpointsByDistance(userLocation);
    
    final pipeline = ResiliencePipelineBuilder()
        .addHedging(HedgingStrategyOptions(
          maxHedgedAttempts: min(rankedEndpoints.length - 1, 3),
          delay: Duration(milliseconds: 100),
          actionGenerator: (attemptNumber) => _fetchFromEndpoint(
            rankedEndpoints[attemptNumber],
            contentId,
          ),
          onHedging: (args) => _logCdnHedging(args, contentId),
        ))
        .build();

    return await pipeline.execute((context) async {
      // Primary attempt uses closest endpoint
      return await _fetchFromEndpoint(rankedEndpoints.first, contentId);
    });
  }

  List<String> _rankEndpointsByDistance(GeoLocation userLocation) {
    final endpointsWithDistance = _cdnEndpoints.map((endpoint) {
      final endpointLocation = _getEndpointLocation(endpoint);
      final distance = _calculateDistance(userLocation, endpointLocation);
      return MapEntry(endpoint, distance);
    }).toList();

    endpointsWithDistance.sort((a, b) => a.value.compareTo(b.value));
    return endpointsWithDistance.map((entry) => entry.key).toList();
  }

  Future<Outcome<ContentResponse>> _fetchFromEndpoint(
    String endpoint,
    String contentId,
  ) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      final response = await httpClient.get('$endpoint/content/$contentId');
      
      stopwatch.stop();
      logger.debug(
        'Content fetched from $endpoint in ${stopwatch.elapsedMilliseconds}ms',
      );

      return Outcome.fromResult(ContentResponse.fromJson(response.data));
    } catch (e) {
      logger.warning('Failed to fetch content from $endpoint: $e');
      return Outcome.fromException(e);
    }
  }

  Future<void> _logCdnHedging(OnHedgingArguments args, String contentId) async {
    logger.info('CDN hedging activated for content: $contentId');
    
    // Track CDN performance for future optimizations
    metrics.incrementCounter('cdn_hedging_activated', tags: {
      'content_id': contentId,
      'delay_ms': args.duration.inMilliseconds.toString(),
    });
  }
}
```

### Database Read Replica Hedging
```dart
class DatabaseService {
  final List<String> _readReplicas;
  final String _primaryDb;
  
  DatabaseService(this._primaryDb, this._readReplicas);

  late final ResiliencePipeline _readPipeline = ResiliencePipelineBuilder()
      .addHedging(HedgingStrategyOptions(
        maxHedgedAttempts: min(_readReplicas.length, 2),
        delay: Duration(milliseconds: 50),
        actionGenerator: _generateReplicaRead,
        shouldHandle: (outcome) {
          // Only hedge for read operations, not writes
          final operation = context.getProperty<String>('operation');
          return operation == 'read' && outcome.hasException;
        },
        onHedging: (args) => _trackReplicaPerformance(args),
      ))
      .build();

  Future<User> getUser(int userId) async {
    final context = ResilienceContext(operationKey: 'get-user');
    context.setProperty('operation', 'read');
    context.setProperty('userId', userId);

    return await _readPipeline.execute((ctx) async {
      // Primary attempt uses first replica or primary
      return await _readFromDatabase(_primaryDb, userId);
    }, context: context);
  }

  Future<List<User>> getUsers(List<int> userIds) async {
    final context = ResilienceContext(operationKey: 'get-users');
    context.setProperty('operation', 'read');
    context.setProperty('userIds', userIds);

    return await _readPipeline.execute((ctx) async {
      return await _readUsersFromDatabase(_primaryDb, userIds);
    }, context: context);
  }

  Future<Outcome<dynamic>> _generateReplicaRead(int attemptNumber) async {
    final operation = context.getProperty<String>('operation');
    
    switch (operation) {
      case 'get-user':
        final userId = context.getProperty<int>('userId')!;
        final replica = _selectReplica(attemptNumber);
        return Outcome.fromResult(await _readFromDatabase(replica, userId));
        
      case 'get-users':
        final userIds = context.getProperty<List<int>>('userIds')!;
        final replica = _selectReplica(attemptNumber);
        return Outcome.fromResult(await _readUsersFromDatabase(replica, userIds));
        
      default:
        throw Exception('Unknown read operation: $operation');
    }
  }

  String _selectReplica(int attemptNumber) {
    if (attemptNumber == 0) return _primaryDb;
    return _readReplicas[(attemptNumber - 1) % _readReplicas.length];
  }

  Future<User> _readFromDatabase(String database, int userId) async {
    final connection = await DatabaseConnection.connect(database);
    try {
      return await connection.query('SELECT * FROM users WHERE id = ?', [userId]);
    } finally {
      await connection.close();
    }
  }

  Future<List<User>> _readUsersFromDatabase(String database, List<int> userIds) async {
    final connection = await DatabaseConnection.connect(database);
    try {
      final placeholders = userIds.map((_) => '?').join(',');
      return await connection.query(
        'SELECT * FROM users WHERE id IN ($placeholders)',
        userIds,
      );
    } finally {
      await connection.close();
    }
  }

  Future<void> _trackReplicaPerformance(OnHedgingArguments args) async {
    logger.info('Database hedging activated for ${args.context.operationKey}');
    
    // Track which replicas are performing poorly
    metrics.incrementCounter('database_hedging_activated', tags: {
      'operation': args.context.operationKey ?? 'unknown',
      'delay_ms': args.duration.inMilliseconds.toString(),
    });
  }
}
```

## Real-World Examples

### Financial Trading Platform
```dart
class TradingService {
  final List<String> _marketDataProviders;
  final List<String> _executionVenues;
  
  TradingService(this._marketDataProviders, this._executionVenues);

  // Market data with aggressive hedging for low latency
  late final ResiliencePipeline _marketDataPipeline = ResiliencePipelineBuilder()
      .addHedging(HedgingStrategyOptions(
        maxHedgedAttempts: _marketDataProviders.length - 1,
        delay: Duration(milliseconds: 10), // Very aggressive for real-time data
        actionGenerator: _fetchMarketData,
        onHedging: (args) => _logMarketDataHedging(args),
      ))
      .build();

  // Order execution with moderate hedging
  late final ResiliencePipeline _executionPipeline = ResiliencePipelineBuilder()
      .addHedging(HedgingStrategyOptions(
        maxHedgedAttempts: 2,
        delay: Duration(milliseconds: 50),
        actionGenerator: _executeOrder,
        shouldHandle: (outcome) {
          // Only hedge execution failures, not rejections
          if (!outcome.hasException) return false;
          
          final exception = outcome.exception;
          return exception is TimeoutException ||
                 exception is SocketException;
        },
      ))
      .build();

  Future<MarketData> getQuote(String symbol) async {
    final context = ResilienceContext(operationKey: 'get-quote');
    context.setProperty('symbol', symbol);
    context.setProperty('timestamp', DateTime.now().millisecondsSinceEpoch);

    return await _marketDataPipeline.execute((ctx) async {
      return await _fetchFromProvider(_marketDataProviders.first, symbol);
    }, context: context);
  }

  Future<OrderResult> executeOrder(Order order) async {
    final context = ResilienceContext(operationKey: 'execute-order');
    context.setProperty('order', order);

    return await _executionPipeline.execute((ctx) async {
      return await _submitOrder(_executionVenues.first, order);
    }, context: context);
  }

  Future<Outcome<MarketData>> _fetchMarketData(int attemptNumber) async {
    final symbol = context.getProperty<String>('symbol')!;
    final provider = _marketDataProviders[attemptNumber % _marketDataProviders.length];
    
    try {
      final data = await _fetchFromProvider(provider, symbol);
      return Outcome.fromResult(data);
    } catch (e) {
      return Outcome.fromException(e);
    }
  }

  Future<Outcome<OrderResult>> _executeOrder(int attemptNumber) async {
    final order = context.getProperty<Order>('order')!;
    final venue = _executionVenues[attemptNumber % _executionVenues.length];
    
    try {
      final result = await _submitOrder(venue, order);
      return Outcome.fromResult(result);
    } catch (e) {
      return Outcome.fromException(e);
    }
  }

  Future<MarketData> _fetchFromProvider(String provider, String symbol) async {
    // Implementation for fetching market data
    final response = await httpClient.get('$provider/quotes/$symbol');
    return MarketData.fromJson(response.data);
  }

  Future<OrderResult> _submitOrder(String venue, Order order) async {
    // Implementation for order execution
    final response = await httpClient.post('$venue/orders', data: order.toJson());
    return OrderResult.fromJson(response.data);
  }

  Future<void> _logMarketDataHedging(OnHedgingArguments args) async {
    final symbol = args.context.getProperty<String>('symbol');
    final timestamp = args.context.getProperty<int>('timestamp');
    
    logger.info('Market data hedging activated for $symbol after ${args.duration.inMicroseconds}μs');
    
    // Critical latency tracking for trading
    metrics.recordHistogram('market_data_hedging_delay_microseconds', 
      args.duration.inMicroseconds,
      tags: {'symbol': symbol ?? 'unknown'},
    );
  }
}
```

### Global Search Service
```dart
class GlobalSearchService {
  final Map<String, String> _searchRegions = {
    'us': 'https://search-us.example.com',
    'eu': 'https://search-eu.example.com',
    'asia': 'https://search-asia.example.com',
  };

  late final ResiliencePipeline _searchPipeline = ResiliencePipelineBuilder()
      .addHedging(HedgingStrategyOptions(
        maxHedgedAttempts: 2, // Search two additional regions
        delay: Duration(milliseconds: 100),
        actionGenerator: _generateRegionalSearch,
        onHedging: (args) => _trackSearchHedging(args),
      ))
      .build();

  Future<SearchResults> search(String query, {String? preferredRegion}) async {
    final context = ResilienceContext(operationKey: 'global-search');
    context.setProperty('query', query);
    context.setProperty('preferredRegion', preferredRegion ?? _detectUserRegion());
    context.setProperty('searchStartTime', DateTime.now());

    return await _searchPipeline.execute((ctx) async {
      final region = context.getProperty<String>('preferredRegion')!;
      return await _searchInRegion(region, query);
    }, context: context);
  }

  Future<Outcome<SearchResults>> _generateRegionalSearch(int attemptNumber) async {
    final query = context.getProperty<String>('query')!;
    final preferredRegion = context.getProperty<String>('preferredRegion')!;
    
    // Select different regions for hedged attempts
    final regions = _searchRegions.keys.toList();
    regions.remove(preferredRegion); // Remove preferred region
    
    if (attemptNumber <= regions.length) {
      final region = regions[(attemptNumber - 1) % regions.length];
      
      try {
        final results = await _searchInRegion(region, query);
        return Outcome.fromResult(results);
      } catch (e) {
        return Outcome.fromException(e);
      }
    }
    
    throw Exception('No more regions available for hedging');
  }

  Future<SearchResults> _searchInRegion(String region, String query) async {
    final endpoint = _searchRegions[region]!;
    
    logger.debug('Searching in region: $region');
    
    final response = await httpClient.get('$endpoint/search', queryParameters: {
      'q': query,
      'region': region,
    });

    return SearchResults.fromJson(response.data)..region = region;
  }

  Future<void> _trackSearchHedging(OnHedgingArguments args) async {
    final query = args.context.getProperty<String>('query');
    final startTime = args.context.getProperty<DateTime>('searchStartTime');
    final duration = DateTime.now().difference(startTime!);
    
    logger.info('Search hedging activated for query: "$query" after ${duration.inMilliseconds}ms');
    
    // Track search performance across regions
    metrics.recordHistogram('search_hedging_delay_ms', 
      duration.inMilliseconds,
      tags: {
        'query_length': query?.length.toString() ?? '0',
        'preferred_region': args.context.getProperty<String>('preferredRegion') ?? 'unknown',
      },
    );
  }

  String _detectUserRegion() {
    // Implementation to detect user's geographical region
    return 'us'; // Default fallback
  }
}
```

## Testing Hedging Strategies

### Unit Testing Hedging Behavior
```dart
import 'package:test/test.dart';
import 'package:polly_dart/polly_dart.dart';

void main() {
  group('Hedging Strategy Tests', () {
    test('should hedge when primary is slow', () async {
      var hedgeActivated = false;
      final pipeline = ResiliencePipelineBuilder()
          .addHedging(HedgingStrategyOptions(
            maxHedgedAttempts: 1,
            delay: Duration(milliseconds: 50),
            onHedging: (args) async {
              hedgeActivated = true;
            },
          ))
          .build();

      final result = await pipeline.execute((context) async {
        // Simulate slow primary operation
        await Future.delayed(Duration(milliseconds: 100));
        return 'primary';
      });

      expect(result, equals('primary'));
      expect(hedgeActivated, isTrue);
    });

    test('should return fastest response', () async {
      final pipeline = ResiliencePipelineBuilder()
          .addHedging(HedgingStrategyOptions(
            maxHedgedAttempts: 2,
            delay: Duration(milliseconds: 10),
            actionGenerator: (attempt) async {
              if (attempt == 1) {
                // Fast hedged operation
                await Future.delayed(Duration(milliseconds: 20));
                return Outcome.fromResult('hedged-fast');
              } else {
                // Slower hedged operation
                await Future.delayed(Duration(milliseconds: 100));
                return Outcome.fromResult('hedged-slow');
              }
            },
          ))
          .build();

      final result = await pipeline.execute((context) async {
        // Very slow primary operation
        await Future.delayed(Duration(milliseconds: 200));
        return 'primary';
      });

      expect(result, equals('hedged-fast'));
    });

    test('should respect maxHedgedAttempts', () async {
      var hedgeCount = 0;
      final pipeline = ResiliencePipelineBuilder()
          .addHedging(HedgingStrategyOptions(
            maxHedgedAttempts: 2,
            delay: Duration(milliseconds: 10),
            actionGenerator: (attempt) async {
              hedgeCount++;
              await Future.delayed(Duration(milliseconds: 100));
              return Outcome.fromResult('hedged-$attempt');
            },
          ))
          .build();

      await pipeline.execute((context) async {
        await Future.delayed(Duration(milliseconds: 50));
        return 'primary';
      });

      expect(hedgeCount, equals(2));
    });

    test('should handle shouldHandle predicate', () async {
      var hedgeActivated = false;
      final pipeline = ResiliencePipelineBuilder()
          .addHedging(HedgingStrategyOptions(
            maxHedgedAttempts: 1,
            delay: Duration(milliseconds: 10),
            shouldHandle: (outcome) => outcome.result == 'should-hedge',
            onHedging: (args) async {
              hedgeActivated = true;
            },
          ))
          .build();

      // Should not hedge
      await pipeline.execute((context) async {
        return 'no-hedge';
      });
      expect(hedgeActivated, isFalse);

      // Should hedge
      await pipeline.execute((context) async {
        await Future.delayed(Duration(milliseconds: 50));
        return 'should-hedge';
      });
      expect(hedgeActivated, isTrue);
    });
  });

  group('Hedging Performance Tests', () {
    test('should improve response time with hedging', () async {
      final slowPipeline = ResiliencePipelineBuilder().build();
      final hedgedPipeline = ResiliencePipelineBuilder()
          .addHedging(HedgingStrategyOptions(
            maxHedgedAttempts: 2,
            delay: Duration(milliseconds: 10),
            actionGenerator: (attempt) async {
              // Fast hedged operations
              await Future.delayed(Duration(milliseconds: 50));
              return Outcome.fromResult('fast');
            },
          ))
          .build();

      // Measure slow pipeline
      final slowStopwatch = Stopwatch()..start();
      await slowPipeline.execute((context) async {
        await Future.delayed(Duration(milliseconds: 200));
        return 'slow';
      });
      slowStopwatch.stop();

      // Measure hedged pipeline
      final hedgedStopwatch = Stopwatch()..start();
      await hedgedPipeline.execute((context) async {
        await Future.delayed(Duration(milliseconds: 200));
        return 'slow';
      });
      hedgedStopwatch.stop();

      expect(hedgedStopwatch.elapsedMilliseconds, 
             lessThan(slowStopwatch.elapsedMilliseconds));
    });
  });
}
```

## Best Practices

### ✅ Do

**Use Appropriate Delays**
```dart
// ✅ Good: Reasonable delay based on expected response time
.addHedging(HedgingStrategyOptions(
  delay: Duration(milliseconds: 100), // 10% of expected response time
  maxHedgedAttempts: 2,
));
```

**Monitor Resource Usage**
```dart
// ✅ Good: Track hedging effectiveness
.addHedging(HedgingStrategyOptions(
  onHedging: (args) async {
    metrics.incrementCounter('hedging_activated');
    metrics.recordHistogram('hedging_delay', args.duration.inMilliseconds);
  },
));
```

**Implement Circuit Breaking**
```dart
// ✅ Good: Combine with circuit breaker to prevent cascade failures
.addCircuitBreaker(CircuitBreakerStrategyOptions(failureRatio: 0.5))
.addHedging(HedgingStrategyOptions(maxHedgedAttempts: 2))
```

### ❌ Don't

**Over-hedge Resources**
```dart
// ❌ Bad: Too many concurrent requests
.addHedging(HedgingStrategyOptions(
  maxHedgedAttempts: 10, // Excessive load on services
));
```

**Use Hedging for Write Operations**
```dart
// ❌ Bad: Could cause duplicate writes
.addHedging(HedgingStrategyOptions(
  shouldHandle: (outcome) => true, // Dangerous for writes!
));
```

**Set Delays Too Small**
```dart
// ❌ Bad: Creates unnecessary load
.addHedging(HedgingStrategyOptions(
  delay: Duration(milliseconds: 1), // Too aggressive
));
```

## Performance Considerations

- **Resource Multiplication**: Each hedged attempt consumes additional resources
- **Network Bandwidth**: Multiple concurrent requests increase bandwidth usage
- **Service Load**: Target services experience increased load
- **Cost Implications**: Cloud services may charge for additional requests
- **Cache Effectiveness**: Multiple requests may bypass caching layers

## Common Patterns

### Hedging with Jitter
```dart
Duration _calculateJitteredDelay(Duration baseDelay) {
  final jitter = Random().nextDouble() * 0.2; // ±20% jitter
  final multiplier = 0.8 + jitter;
  return Duration(milliseconds: (baseDelay.inMilliseconds * multiplier).round());
}
```

### Regional Preference
```dart
List<String> _orderEndpointsByPreference(String userRegion) {
  final endpoints = [...allEndpoints];
  final preferred = endpoints.firstWhere((e) => e.contains(userRegion));
  endpoints.remove(preferred);
  return [preferred, ...endpoints];
}
```

## Next Steps

Hedging optimizes for performance through parallel execution:

1. **[Learn Rate Limiter Strategy](./rate-limiter)** - Control resource usage and concurrency
2. **[Explore Combining Strategies](../advanced/combining-strategies)** - Build comprehensive resilience pipelines  
3. **[Advanced Topics](../advanced/)** - Master complex resilience patterns

Hedging trades resources for performance - use it wisely where latency is critical.
