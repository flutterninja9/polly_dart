---
sidebar_position: 2
---

# Retry Strategy

The **Retry Strategy** automatically retries failed operations, making your application more resilient to transient failures like network hiccups, temporary service unavailability, or resource contention.

## When to Use Retry

Retry is ideal for handling **transient failures** - temporary conditions that are likely to resolve themselves:

- 🌐 **Network timeouts** and connection failures
- 🔧 **HTTP 5xx errors** (server errors) and 429 (rate limiting)
- 🗄️ **Database deadlocks** and temporary unavailability
- ☁️ **Cloud service throttling** and temporary outages
- 📱 **Mobile network** connectivity issues

:::warning Don't retry everything
Avoid retrying **persistent failures** like authentication errors (401), not found errors (404), or validation failures (400). These won't resolve with retries and waste resources.
:::

## Basic Usage

### Simple Retry
```dart
import 'package:polly_dart/polly_dart.dart';

final pipeline = ResiliencePipelineBuilder()
    .addRetry()  // Default: 3 attempts, 1 second delay
    .build();

final result = await pipeline.execute((context) async {
  return await httpClient.get('https://api.example.com/data');
});
```

### Configured Retry
```dart
final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 5,
      delay: Duration(milliseconds: 500),
      backoffType: DelayBackoffType.exponential,
    ))
    .build();
```

## Configuration Options

### RetryStrategyOptions

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `maxRetryAttempts` | `int` | `3` | Maximum number of retry attempts |
| `delay` | `Duration` | `1 second` | Base delay between retries |
| `backoffType` | `DelayBackoffType` | `exponential` | How delay increases between retries |
| `useJitter` | `bool` | `false` | Add randomness to delays |
| `maxDelay` | `Duration` | `30 seconds` | Maximum delay between retries |
| `shouldHandle` | `ShouldHandlePredicate<T>?` | `null` | Predicate to determine which failures to retry |
| `delayGenerator` | `DelayGenerator<T>?` | `null` | Custom delay logic |
| `onRetry` | `OnRetryCallback<T>?` | `null` | Callback invoked before each retry |

## Backoff Strategies

### Constant Delay
Each retry waits the same amount of time:

```dart
final constantRetry = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 3,
      delay: Duration(seconds: 2),
      backoffType: DelayBackoffType.constant,
    ))
    .build();

// Retry pattern: 2s → 2s → 2s
```

### Linear Backoff
Delay increases linearly with each attempt:

```dart
final linearRetry = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 4,
      delay: Duration(seconds: 1),
      backoffType: DelayBackoffType.linear,
    ))
    .build();

// Retry pattern: 1s → 2s → 3s → 4s
```

### Exponential Backoff (Recommended)
Delay doubles with each attempt, preventing overwhelming failing services:

```dart
final exponentialRetry = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 5,
      delay: Duration(milliseconds: 500),
      backoffType: DelayBackoffType.exponential,
      maxDelay: Duration(seconds: 30),
    ))
    .build();

// Retry pattern: 500ms → 1s → 2s → 4s → 8s
```

### Jitter
Add randomness to prevent the "thundering herd" problem when multiple clients retry simultaneously:

```dart
final jitteredRetry = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 3,
      delay: Duration(seconds: 1),
      backoffType: DelayBackoffType.exponential,
      useJitter: true,  // Adds ±25% randomness
    ))
    .build();

// Retry pattern: ~1s ± 250ms → ~2s ± 500ms → ~4s ± 1s
```

## Smart Retry Logic

### Selective Retrying
Only retry specific types of failures:

```dart
bool shouldRetryHttpError(Outcome outcome) {
  if (!outcome.hasException) return false;
  
  final exception = outcome.exception;
  
  // Retry network issues
  if (exception is SocketException) return true;
  if (exception is TimeoutException) return true;
  
  // Retry specific HTTP errors
  if (exception is HttpException) {
    final message = exception.message.toLowerCase();
    return message.contains('500') ||  // Server error
           message.contains('502') ||  // Bad gateway
           message.contains('503') ||  // Service unavailable
           message.contains('504') ||  // Gateway timeout
           message.contains('429');    // Rate limited
  }
  
  return false;
}

final smartRetry = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 3,
      delay: Duration(seconds: 1),
      backoffType: DelayBackoffType.exponential,
      shouldHandle: shouldRetryHttpError,
    ))
    .build();
```

### Custom Delay Logic
Implement sophisticated delay calculations:

```dart
final customDelayRetry = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 5,
      delayGenerator: (args) async {
        // Custom delay based on attempt number and exception type
        final baseDelay = Duration(seconds: 1);
        final attemptNumber = args.attemptNumber;
        
        // Different delays for different error types
        if (args.outcome.hasException) {
          final exception = args.outcome.exception;
          
          if (exception.toString().contains('rate limit')) {
            // Longer delay for rate limiting
            return Duration(seconds: 30 + (attemptNumber * 10));
          } else if (exception.toString().contains('timeout')) {
            // Shorter delay for timeouts
            return Duration(milliseconds: 500 * (attemptNumber + 1));
          }
        }
        
        // Default exponential backoff
        return Duration(
          milliseconds: baseDelay.inMilliseconds * math.pow(2, attemptNumber).toInt()
        );
      },
    ))
    .build();
```

## Monitoring and Observability

### Retry Callbacks
Track retry behavior for monitoring and debugging:

```dart
final monitoredRetry = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 3,
      onRetry: (args) async {
        final attemptNumber = args.attemptNumber + 1;
        final operationKey = args.context.operationKey ?? 'unknown';
        final exception = args.outcome.exception;
        
        // Log retry attempts
        logger.warning(
          'Retry attempt $attemptNumber for operation $operationKey: $exception'
        );
        
        // Emit metrics
        metrics.incrementCounter('retry_attempts', tags: {
          'operation': operationKey,
          'attempt': attemptNumber.toString(),
          'exception_type': exception.runtimeType.toString(),
        });
        
        // Send alerts for excessive retries
        if (attemptNumber >= 3) {
          alerts.send('High retry count for $operationKey');
        }
      },
    ))
    .build();
```

## Named Constructors

Polly Dart provides convenient named constructors for common retry patterns:

### Immediate Retries
For operations where delay isn't needed:

```dart
final immediateRetry = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions.immediate(
      maxRetryAttempts: 3,
    ))
    .build();
```

### No Delay Retries
For scenarios requiring rapid retries:

```dart
final noDelayRetry = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions.noDelay(
      maxRetryAttempts: 2,
    ))
    .build();
```

### Infinite Retries
For critical operations that must eventually succeed:

```dart
final infiniteRetry = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions.infinite(
      delay: Duration(seconds: 5),
      backoffType: DelayBackoffType.exponential,
    ))
    .build();

// ⚠️ Use infinite retries carefully - ensure you have circuit breakers!
```

## Real-World Examples

### HTTP Client with Smart Retries
```dart
class ResilientHttpClient {
  final HttpClient _httpClient = HttpClient();
  late final ResiliencePipeline _pipeline;

  ResilientHttpClient() {
    _pipeline = ResiliencePipelineBuilder()
        .addRetry(RetryStrategyOptions(
          maxRetryAttempts: 3,
          delay: Duration(seconds: 1),
          backoffType: DelayBackoffType.exponential,
          useJitter: true,
          shouldHandle: _shouldRetryHttpRequest,
          onRetry: _logRetryAttempt,
        ))
        .build();
  }

  Future<String> get(String url) async {
    return await _pipeline.execute((context) async {
      context.setProperty('url', url);
      context.setProperty('method', 'GET');
      
      final request = await _httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      
      if (response.statusCode >= 400) {
        throw HttpException(
          'HTTP ${response.statusCode}',
          uri: Uri.parse(url),
        );
      }
      
      return await response.transform(utf8.decoder).join();
    });
  }

  bool _shouldRetryHttpRequest(Outcome outcome) {
    if (!outcome.hasException) return false;
    
    final exception = outcome.exception;
    
    // Always retry network issues
    if (exception is SocketException || exception is TimeoutException) {
      return true;
    }
    
    // Retry specific HTTP status codes
    if (exception is HttpException) {
      final uri = exception.uri;
      final message = exception.message;
      
      // Don't retry client errors (4xx) except rate limiting
      if (message.contains('4')) {
        return message.contains('429'); // Rate limited
      }
      
      // Retry server errors (5xx)
      return message.contains('5');
    }
    
    return false;
  }

  Future<void> _logRetryAttempt(OnRetryArguments args) async {
    final url = args.context.getProperty<String>('url') ?? 'unknown';
    final method = args.context.getProperty<String>('method') ?? 'unknown';
    final attemptNumber = args.attemptNumber + 1;
    
    print('Retrying $method $url (attempt $attemptNumber): ${args.outcome.exception}');
  }

  void dispose() {
    _httpClient.close();
  }
}
```

### Database Operations with Retry
```dart
class ResilientDatabase {
  final Database _db;
  late final ResiliencePipeline _pipeline;

  ResilientDatabase(this._db) {
    _pipeline = ResiliencePipelineBuilder()
        .addRetry(RetryStrategyOptions(
          maxRetryAttempts: 2,
          delay: Duration(milliseconds: 100),
          backoffType: DelayBackoffType.linear,
          shouldHandle: _shouldRetryDbOperation,
        ))
        .build();
  }

  Future<List<User>> getUsers() async {
    return await _pipeline.execute((context) async {
      return await _db.query('SELECT * FROM users');
    });
  }

  Future<void> saveUser(User user) async {
    await _pipeline.execute((context) async {
      await _db.insert('users', user.toMap());
      return null;
    });
  }

  bool _shouldRetryDbOperation(Outcome outcome) {
    if (!outcome.hasException) return false;
    
    final exception = outcome.exception;
    final message = exception.toString().toLowerCase();
    
    // Retry transient database issues
    return message.contains('deadlock') ||
           message.contains('timeout') ||
           message.contains('connection') ||
           message.contains('busy');
  }
}
```

### File Operations with Retry
```dart
class ResilientFileManager {
  late final ResiliencePipeline _pipeline;

  ResilientFileManager() {
    _pipeline = ResiliencePipelineBuilder()
        .addRetry(RetryStrategyOptions(
          maxRetryAttempts: 3,
          delay: Duration(milliseconds: 250),
          shouldHandle: _shouldRetryFileOperation,
        ))
        .build();
  }

  Future<String> readFile(String path) async {
    return await _pipeline.execute((context) async {
      return await File(path).readAsString();
    });
  }

  Future<void> writeFile(String path, String content) async {
    await _pipeline.execute((context) async {
      await File(path).writeAsString(content);
      return null;
    });
  }

  bool _shouldRetryFileOperation(Outcome outcome) {
    if (!outcome.hasException) return false;
    
    final exception = outcome.exception;
    
    // Retry I/O issues that might be temporary
    return exception is FileSystemException &&
           (exception.message.contains('busy') ||
            exception.message.contains('locked') ||
            exception.message.contains('access denied'));
  }
}
```

## Testing Retry Behavior

### Unit Testing Retry Logic
```dart
import 'package:test/test.dart';
import 'package:polly_dart/polly_dart.dart';

void main() {
  group('Retry Strategy Tests', () {
    test('should retry specified number of times', () async {
      var attempts = 0;
      final pipeline = ResiliencePipelineBuilder()
          .addRetry(RetryStrategyOptions(maxRetryAttempts: 3))
          .build();

      final result = await pipeline.execute((context) async {
        attempts++;
        if (attempts < 4) {
          throw Exception('Temporary failure');
        }
        return 'success';
      });

      expect(result, equals('success'));
      expect(attempts, equals(4)); // Initial + 3 retries
    });

    test('should respect shouldHandle predicate', () async {
      var attempts = 0;
      final pipeline = ResiliencePipelineBuilder()
          .addRetry(RetryStrategyOptions(
            maxRetryAttempts: 3,
            shouldHandle: (outcome) => 
                outcome.hasException && 
                outcome.exception.toString().contains('retryable'),
          ))
          .build();

      try {
        await pipeline.execute((context) async {
          attempts++;
          throw Exception('non-retryable error');
        });
        fail('Should have thrown exception');
      } catch (e) {
        expect(attempts, equals(1)); // No retries for non-retryable error
      }
    });

    test('should call onRetry callback', () async {
      final retryAttempts = <int>[];
      final pipeline = ResiliencePipelineBuilder()
          .addRetry(RetryStrategyOptions(
            maxRetryAttempts: 2,
            onRetry: (args) async {
              retryAttempts.add(args.attemptNumber);
            },
          ))
          .build();

      try {
        await pipeline.execute((context) async {
          throw Exception('Always fails');
        });
      } catch (e) {}

      expect(retryAttempts, equals([0, 1])); // Two retry attempts
    });
  });
}
```

## Best Practices

### ✅ Do
- **Use exponential backoff** with jitter for most scenarios
- **Be selective** about which failures to retry
- **Set reasonable maximum attempts** (usually 3-5)
- **Add monitoring** to track retry patterns
- **Consider the total time** including all retries and delays
- **Combine with circuit breakers** to prevent infinite loops

### ❌ Don't
- **Retry non-transient failures** (4xx HTTP errors, validation failures)
- **Use infinite retries** without circuit breakers
- **Ignore retry patterns** in your monitoring
- **Set overly aggressive retry counts** that overwhelm failing services
- **Forget about exponential backoff** for external services

### Performance Tips
- **Reuse pipeline instances** instead of creating new ones
- **Use immediate retries** for local operations only
- **Monitor total execution time** including retries
- **Consider timeout strategies** to limit total retry time

## Common Patterns

### API Client Pattern
```dart
class ApiClient {
  static final _retryPipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions(
        maxRetryAttempts: 3,
        delay: Duration(seconds: 1),
        backoffType: DelayBackoffType.exponential,
        useJitter: true,
      ))
      .build();
  
  Future<T> request<T>(String endpoint, T Function(Map<String, dynamic>) parser) {
    return _retryPipeline.execute((context) async {
      final response = await httpClient.get(endpoint);
      return parser(response.data);
    });
  }
}
```

### Repository Pattern
```dart
class UserRepository {
  static final _dbRetryPipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions(
        maxRetryAttempts: 2,
        delay: Duration(milliseconds: 100),
      ))
      .build();
  
  Future<User?> findById(int id) {
    return _dbRetryPipeline.execute((context) async {
      return await database.users.findById(id);
    });
  }
}
```

## Next Steps

Now that you understand retry strategies:

1. **[🔧 Learn Circuit Breaker](./circuit-breaker)** - Prevent cascading failures
2. **[⏱️ Explore Timeout Strategy](./timeout)** - Control operation duration  
3. **[🔄 Combine Strategies](../advanced/combining-strategies)** - Build comprehensive resilience

The retry strategy is often the foundation of resilient systems, but it works best when combined with other strategies to create a complete resilience solution.
