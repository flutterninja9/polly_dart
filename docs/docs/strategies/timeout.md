---
sidebar_position: 4
---

# Timeout Strategy

The **Timeout Strategy** prevents operations from running indefinitely by cancelling them after a specified duration. This is crucial for maintaining responsive applications and preventing resource exhaustion.

## When to Use Timeout

Timeouts are essential for:

- 🌐 **Network operations** that might hang indefinitely
- 🗄️ **Database queries** that could lock resources
- 📁 **File operations** that might block on I/O
- 🔄 **External service calls** with unpredictable response times
- 📱 **User-facing operations** that need to stay responsive

:::tip Timeout vs Cancellation
Polly Dart's timeout strategy integrates with Dart's cancellation tokens, providing clean cancellation semantics rather than forceful termination.
:::

## Basic Usage

### Simple Timeout
```dart
import 'package:polly_dart/polly_dart.dart';

final pipeline = ResiliencePipelineBuilder()
    .addTimeout(Duration(seconds: 10))  // 10-second timeout
    .build();

final result = await pipeline.execute((context) async {
  return await longRunningOperation();
});
```

### Configured Timeout
```dart
final pipeline = ResiliencePipelineBuilder()
    .addTimeoutWithOptions(TimeoutStrategyOptions(
      timeout: Duration(seconds: 30),
      onTimeout: (args) async {
        logger.warning('Operation timed out after ${args.timeout}');
      },
    ))
    .build();
```

## Configuration Options

### TimeoutStrategyOptions

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `timeout` | `Duration` | Required | Fixed timeout duration |
| `timeoutGenerator` | `TimeoutGenerator?` | `null` | Dynamic timeout calculation |
| `onTimeout` | `OnTimeoutCallback?` | `null` | Callback invoked when timeout occurs |

## Dynamic Timeouts

### Context-Based Timeouts
Calculate timeouts based on operation context:

```dart
final dynamicTimeoutPipeline = ResiliencePipelineBuilder()
    .addTimeoutWithOptions(TimeoutStrategyOptions.withGenerator(
      timeoutGenerator: (args) async {
        final context = args.context;
        
        // Different timeouts for different operations
        final operationKey = context.operationKey ?? '';
        
        if (operationKey.contains('critical')) {
          return Duration(seconds: 5);   // Fast timeout for critical ops
        } else if (operationKey.contains('bulk')) {
          return Duration(minutes: 5);   // Longer timeout for bulk ops
        } else if (operationKey.contains('report')) {
          return Duration(minutes: 10);  // Even longer for reports
        }
        
        // Default timeout
        return Duration(seconds: 30);
      },
    ))
    .build();
```

### Adaptive Timeouts
Adjust timeouts based on historical performance:

```dart
class AdaptiveTimeoutManager {
  final Map<String, Duration> _averageResponseTimes = {};
  final Map<String, List<Duration>> _recentResponses = {};
  
  Duration calculateTimeout(String operationKey) {
    final recentTimes = _recentResponses[operationKey] ?? [];
    
    if (recentTimes.isEmpty) {
      return Duration(seconds: 30); // Default
    }
    
    // Calculate average response time
    final totalMs = recentTimes.fold<int>(
      0, 
      (sum, duration) => sum + duration.inMilliseconds,
    );
    final averageMs = totalMs / recentTimes.length;
    
    // Set timeout to 3x average response time, with bounds
    final timeoutMs = (averageMs * 3).clamp(1000, 120000); // 1s to 2min
    return Duration(milliseconds: timeoutMs.toInt());
  }
  
  void recordResponseTime(String operationKey, Duration responseTime) {
    _recentResponses.putIfAbsent(operationKey, () => <Duration>[]);
    final recent = _recentResponses[operationKey]!;
    
    recent.add(responseTime);
    
    // Keep only last 10 measurements
    if (recent.length > 10) {
      recent.removeAt(0);
    }
  }
}

final adaptiveManager = AdaptiveTimeoutManager();

final adaptivePipeline = ResiliencePipelineBuilder()
    .addTimeoutWithOptions(TimeoutStrategyOptions.withGenerator(
      timeoutGenerator: (args) async {
        final operationKey = args.context.operationKey ?? 'default';
        return adaptiveManager.calculateTimeout(operationKey);
      },
    ))
    .build();
```

### Time-of-Day Based Timeouts
Adjust timeouts based on expected system load:

```dart
final timeBasedPipeline = ResiliencePipelineBuilder()
    .addTimeoutWithOptions(TimeoutStrategyOptions.withGenerator(
      timeoutGenerator: (args) async {
        final now = DateTime.now();
        final hour = now.hour;
        
        // Longer timeouts during peak hours (9-17)
        if (hour >= 9 && hour < 17) {
          return Duration(minutes: 2);  // Peak hours
        } else if (hour >= 22 || hour < 6) {
          return Duration(seconds: 15); // Maintenance window
        } else {
          return Duration(seconds: 45); // Off-peak hours
        }
      },
    ))
    .build();
```

## Timeout Monitoring

### Timeout Callbacks
Track timeout patterns for optimization:

```dart
final monitoredPipeline = ResiliencePipelineBuilder()
    .addTimeoutWithOptions(TimeoutStrategyOptions(
      timeout: Duration(seconds: 30),
      onTimeout: (args) async {
        final operationKey = args.context.operationKey ?? 'unknown';
        final timeoutDuration = args.timeout;
        
        // Log timeout events
        logger.warning(
          'Operation $operationKey timed out after $timeoutDuration'
        );
        
        // Emit metrics
        metrics.incrementCounter('operation_timeouts', tags: {
          'operation': operationKey,
          'timeout_seconds': timeoutDuration.inSeconds.toString(),
        });
        
        // Record for adaptive timeout calculation
        timeoutTracker.recordTimeout(operationKey, timeoutDuration);
        
        // Alert on frequent timeouts
        final recentTimeouts = timeoutTracker.getRecentTimeouts(operationKey);
        if (recentTimeouts.length > 5) {
          await alertService.send(
            'Frequent Timeouts',
            'Operation $operationKey has timed out ${recentTimeouts.length} times recently',
          );
        }
      },
    ))
    .build();
```

## Exception Handling

### Timeout Exceptions
```dart
try {
  final result = await timeoutPipeline.execute((context) async {
    return await slowOperation();
  });
} on TimeoutRejectedException catch (e) {
  // Handle timeout specifically
  logger.warning('Operation timed out: ${e.message}');
  return getDefaultValue();
} catch (e) {
  // Handle other exceptions
  logger.error('Operation failed: $e');
  rethrow;
}
```

### Graceful Timeout Handling
```dart
Future<ApiResponse> fetchDataWithGracefulTimeout() async {
  try {
    return await timeoutPipeline.execute((context) async {
      return await apiClient.fetchData();
    });
  } on TimeoutRejectedException {
    // Return partial data or cached data on timeout
    return ApiResponse.partial(
      data: await getCachedData(),
      message: 'Request timed out, showing cached data',
    );
  }
}
```

## Real-World Examples

### HTTP Client with Smart Timeouts
```dart
class TimeoutAwareHttpClient {
  final HttpClient _client = HttpClient();
  late final ResiliencePipeline _pipeline;
  final Map<String, Duration> _endpointTimeouts = {};

  TimeoutAwareHttpClient() {
    _pipeline = ResiliencePipelineBuilder()
        .addTimeoutWithOptions(TimeoutStrategyOptions.withGenerator(
          timeoutGenerator: _calculateTimeout,
          onTimeout: _onTimeout,
        ))
        .build();
  }

  Future<HttpClientResponse> get(String url) async {
    final uri = Uri.parse(url);
    final context = ResilienceContext(operationKey: 'GET:${uri.path}');
    
    return await _pipeline.execute((ctx) async {
      final request = await _client.getUrl(uri);
      return await request.close();
    }, context: context);
  }

  Future<Duration> _calculateTimeout(TimeoutGeneratorArguments args) async {
    final operationKey = args.context.operationKey ?? '';
    
    // Check for endpoint-specific timeout configuration
    final endpointTimeout = _endpointTimeouts[operationKey];
    if (endpointTimeout != null) {
      return endpointTimeout;
    }
    
    // Different timeouts for different endpoint types
    if (operationKey.contains('/auth/')) {
      return Duration(seconds: 5);    // Auth should be fast
    } else if (operationKey.contains('/reports/')) {
      return Duration(minutes: 2);    // Reports can be slow
    } else if (operationKey.contains('/realtime/')) {
      return Duration(seconds: 3);    // Real-time needs to be fast
    } else if (operationKey.contains('/batch/')) {
      return Duration(minutes: 5);    // Batch operations are slower
    }
    
    // Default timeout
    return Duration(seconds: 30);
  }

  Future<void> _onTimeout(OnTimeoutArguments args) async {
    final endpoint = args.context.operationKey ?? 'unknown';
    
    logger.warning('HTTP request timeout: $endpoint (${args.timeout})');
    
    // Adjust timeout for this endpoint if it's timing out frequently
    await _adjustEndpointTimeout(endpoint, args.timeout);
  }

  Future<void> _adjustEndpointTimeout(String endpoint, Duration currentTimeout) async {
    // Increase timeout by 50% for this endpoint
    final newTimeout = Duration(
      milliseconds: (currentTimeout.inMilliseconds * 1.5).toInt(),
    );
    
    // Cap at 5 minutes
    final cappedTimeout = Duration(
      milliseconds: math.min(newTimeout.inMilliseconds, 300000),
    );
    
    _endpointTimeouts[endpoint] = cappedTimeout;
    
    logger.info('Adjusted timeout for $endpoint to $cappedTimeout');
  }

  void dispose() {
    _client.close();
  }
}
```

### Database Query with Timeout
```dart
class TimeoutAwareDatabase {
  final Database _db;
  late final ResiliencePipeline _queryPipeline;
  late final ResiliencePipeline _transactionPipeline;

  TimeoutAwareDatabase(this._db) {
    // Different timeouts for different operation types
    _queryPipeline = ResiliencePipelineBuilder()
        .addTimeout(Duration(seconds: 15))  // Quick queries
        .build();
    
    _transactionPipeline = ResiliencePipelineBuilder()
        .addTimeout(Duration(minutes: 2))   // Longer for transactions
        .build();
  }

  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? params]) async {
    return await _queryPipeline.execute((context) async {
      return await _db.rawQuery(sql, params);
    });
  }

  Future<T> transaction<T>(Future<T> Function(DatabaseTransaction) action) async {
    return await _transactionPipeline.execute((context) async {
      return await _db.transaction(action);
    });
  }

  Future<User?> findUserById(int id) async {
    try {
      final results = await query(
        'SELECT * FROM users WHERE id = ? LIMIT 1',
        [id],
      );
      
      return results.isNotEmpty ? User.fromMap(results.first) : null;
    } on TimeoutRejectedException {
      logger.warning('Database query timed out for user $id');
      return null; // Return null instead of throwing
    }
  }

  Future<void> bulkInsert(String table, List<Map<String, dynamic>> rows) async {
    // Use transaction pipeline for bulk operations
    await _transactionPipeline.execute((context) async {
      await _db.transaction((txn) async {
        for (final row in rows) {
          await txn.insert(table, row);
        }
      });
    });
  }
}
```

### File Operations with Progressive Timeouts
```dart
class TimeoutAwareFileManager {
  late final ResiliencePipeline _readPipeline;
  late final ResiliencePipeline _writePipeline;

  TimeoutAwareFileManager() {
    _readPipeline = ResiliencePipelineBuilder()
        .addTimeoutWithOptions(TimeoutStrategyOptions.withGenerator(
          timeoutGenerator: _calculateReadTimeout,
        ))
        .build();
    
    _writePipeline = ResiliencePipelineBuilder()
        .addTimeoutWithOptions(TimeoutStrategyOptions.withGenerator(
          timeoutGenerator: _calculateWriteTimeout,
        ))
        .build();
  }

  Future<String> readFile(String path) async {
    final context = ResilienceContext();
    context.setProperty('filePath', path);
    
    return await _readPipeline.execute((ctx) async {
      return await File(path).readAsString();
    }, context: context);
  }

  Future<void> writeFile(String path, String content) async {
    final context = ResilienceContext();
    context.setProperty('filePath', path);
    context.setProperty('contentSize', content.length);
    
    await _writePipeline.execute((ctx) async {
      await File(path).writeAsString(content);
    }, context: context);
  }

  Future<Duration> _calculateReadTimeout(TimeoutGeneratorArguments args) async {
    final filePath = args.context.getProperty<String>('filePath') ?? '';
    
    try {
      final file = File(filePath);
      final size = await file.length();
      
      // Base timeout of 1 second + 1 second per MB
      final timeoutSeconds = 1 + (size / (1024 * 1024)).ceil();
      return Duration(seconds: timeoutSeconds);
    } catch (e) {
      // If we can't determine size, use default
      return Duration(seconds: 10);
    }
  }

  Future<Duration> _calculateWriteTimeout(TimeoutGeneratorArguments args) async {
    final contentSize = args.context.getProperty<int>('contentSize') ?? 0;
    
    // Base timeout of 2 seconds + 2 seconds per MB
    final timeoutSeconds = 2 + ((contentSize / (1024 * 1024)) * 2).ceil();
    return Duration(seconds: timeoutSeconds);
  }
}
```

## Testing Timeout Behavior

### Unit Testing Timeouts
```dart
import 'package:test/test.dart';
import 'package:polly_dart/polly_dart.dart';

void main() {
  group('Timeout Strategy Tests', () {
    test('should timeout after specified duration', () async {
      final pipeline = ResiliencePipelineBuilder()
          .addTimeout(Duration(milliseconds: 100))
          .build();

      final stopwatch = Stopwatch()..start();
      
      expect(
        () => pipeline.execute((context) async {
          await Future.delayed(Duration(milliseconds: 200));
          return 'should not complete';
        }),
        throwsA(isA<TimeoutRejectedException>()),
      );
      
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(150));
    });

    test('should call onTimeout callback', () async {
      var timeoutCalled = false;
      final pipeline = ResiliencePipelineBuilder()
          .addTimeoutWithOptions(TimeoutStrategyOptions(
            timeout: Duration(milliseconds: 50),
            onTimeout: (args) async {
              timeoutCalled = true;
            },
          ))
          .build();

      try {
        await pipeline.execute((context) async {
          await Future.delayed(Duration(milliseconds: 100));
          return 'test';
        });
      } catch (e) {}

      expect(timeoutCalled, isTrue);
    });

    test('should use dynamic timeout from generator', () async {
      final pipeline = ResiliencePipelineBuilder()
          .addTimeoutWithOptions(TimeoutStrategyOptions.withGenerator(
            timeoutGenerator: (args) async {
              final operationKey = args.context.operationKey ?? '';
              return operationKey == 'fast' 
                  ? Duration(milliseconds: 50)
                  : Duration(milliseconds: 200);
            },
          ))
          .build();

      // Fast operation should timeout
      expect(
        () => pipeline.execute(
          (context) async {
            await Future.delayed(Duration(milliseconds: 100));
            return 'test';
          },
          context: ResilienceContext(operationKey: 'fast'),
        ),
        throwsA(isA<TimeoutRejectedException>()),
      );

      // Slow operation should succeed
      final result = await pipeline.execute(
        (context) async {
          await Future.delayed(Duration(milliseconds: 100));
          return 'success';
        },
        context: ResilienceContext(operationKey: 'slow'),
      );
      
      expect(result, equals('success'));
    });
  });
}
```

## Best Practices

### ✅ Do
- **Set reasonable timeouts** based on operation characteristics
- **Use different timeouts** for different types of operations
- **Monitor timeout patterns** to optimize durations
- **Combine with retry strategies** for comprehensive resilience
- **Handle timeouts gracefully** with fallback responses
- **Consider user experience** when setting UI-facing timeouts

### ❌ Don't
- **Set overly aggressive timeouts** that cause false failures
- **Use the same timeout** for all operations
- **Ignore timeout exceptions** without proper handling
- **Set timeouts too long** for user-facing operations
- **Forget about variable network conditions** in mobile apps

### Timeout Guidelines by Operation Type

| Operation Type | Recommended Timeout | Considerations |
|----------------|-------------------|----------------|
| **Authentication** | 3-5 seconds | Users expect fast auth |
| **Data Fetching** | 10-30 seconds | Balance UX and reliability |
| **File Upload** | 1-5 minutes | Based on file size |
| **Database Queries** | 5-30 seconds | Depends on complexity |
| **Report Generation** | 2-10 minutes | Long-running processes |
| **Real-time Operations** | 1-3 seconds | Must be responsive |
| **Batch Processing** | 5-30 minutes | Large data operations |

## Common Patterns

### Tiered Timeout Pattern
```dart
class TieredTimeoutService {
  static final _fastPipeline = ResiliencePipelineBuilder()
      .addTimeout(Duration(seconds: 5))
      .build();
  
  static final _normalPipeline = ResiliencePipelineBuilder()
      .addTimeout(Duration(seconds: 30))
      .build();
  
  static final _slowPipeline = ResiliencePipelineBuilder()
      .addTimeout(Duration(minutes: 2))
      .build();
  
  Future<T> executeFast<T>(Future<T> Function() operation) {
    return _fastPipeline.execute((context) => operation());
  }
  
  Future<T> executeNormal<T>(Future<T> Function() operation) {
    return _normalPipeline.execute((context) => operation());
  }
  
  Future<T> executeSlow<T>(Future<T> Function() operation) {
    return _slowPipeline.execute((context) => operation());
  }
}
```

### Environment-Specific Timeouts
```dart
class EnvironmentAwareTimeouts {
  static Duration getTimeout(String operationType) {
    final isDevelopment = Platform.environment['ENVIRONMENT'] == 'development';
    final isProduction = Platform.environment['ENVIRONMENT'] == 'production';
    
    final timeouts = {
      'api_call': isDevelopment ? Duration(minutes: 5) : Duration(seconds: 30),
      'database': isDevelopment ? Duration(minutes: 2) : Duration(seconds: 15),
      'file_io': Duration(seconds: 10), // Same across environments
    };
    
    return timeouts[operationType] ?? Duration(seconds: 30);
  }
}
```

## Next Steps

Timeout strategies work best when combined with other resilience patterns:

1. **[🔄 Learn Retry Strategy](./retry)** - Handle transient failures
2. **[🎯 Explore Fallback Strategy](./fallback)** - Provide alternatives on timeout
3. **[🔧 Combine Strategies](../advanced/combining-strategies)** - Build comprehensive resilience

Timeouts are a fundamental building block of resilient systems, providing the foundation for responsive and reliable applications.
