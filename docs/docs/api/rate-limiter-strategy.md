---
sidebar_position: 10
---

# RateLimiterStrategy

The `RateLimiterStrategy` controls the rate of operations to prevent system overload and ensure fair resource usage.

## Overview

The rate limiter strategy throttles operations to stay within specified limits. It helps prevent system overload, ensures fair resource allocation, and protects against abuse or runaway processes.

```dart
class RateLimiterStrategy<T> extends ResilienceStrategy<T> {
  RateLimiterStrategy(RateLimiterStrategyOptions<T> options);
  
  Future<Outcome<T>> executeCore<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
    ResilienceCallback<T> next,
  );
}

class RateLimiterStrategyOptions<T> {
  const RateLimiterStrategyOptions({
    required this.permitLimit,
    this.window = const Duration(seconds: 60),
    this.queueLimit = 0,
    this.onRateLimitExceeded,
  });
}
```

## RateLimiterStrategyOptions Properties

### permitLimit

Maximum number of permits allowed within the specified window.

**Type:** `int`  
**Required:** Yes

```dart
RateLimiterStrategyOptions(
  permitLimit: 100, // 100 operations per window
)
```

### window

Time window for the rate limit.

**Type:** `Duration`  
**Default:** `Duration(seconds: 60)`

```dart
RateLimiterStrategyOptions(
  permitLimit: 100,
  window: Duration(minutes: 1), // 100 operations per minute
)
```

### queueLimit

Maximum number of operations to queue when rate limit is exceeded.

**Type:** `int`  
**Default:** `0` (no queueing)

```dart
RateLimiterStrategyOptions(
  permitLimit: 100,
  queueLimit: 10, // Queue up to 10 operations
)
```

### onRateLimitExceeded

Callback invoked when the rate limit is exceeded.

**Type:** `OnRateLimitExceededCallback<T>?`  
**Default:** `null`

```dart
RateLimiterStrategyOptions(
  permitLimit: 100,
  onRateLimitExceeded: (context, args) {
    logger.warn('Rate limit exceeded: ${args.retryAfter}');
  },
)
```

## Callback Types

### OnRateLimitExceededCallback&lt;T&gt;

```dart
typedef OnRateLimitExceededCallback<T> = void Function(
  ResilienceContext context,
  OnRateLimitExceededArgs args,
);
```

Called when the rate limit is exceeded.

**OnRateLimitExceededArgs Properties:**
- `retryAfter` - Duration to wait before retrying
- `currentCount` - Current number of operations in the window

## Usage Examples

### Basic Rate Limiting

```dart
final rateLimiter = RateLimiterStrategy(RateLimiterStrategyOptions(
  permitLimit: 100,
  window: Duration(minutes: 1),
));

final pipeline = ResiliencePipelineBuilder()
    .addStrategy(rateLimiter)
    .build();
```

### API Rate Limiting

```dart
final apiRateLimiter = RateLimiterStrategy(RateLimiterStrategyOptions(
  permitLimit: 1000, // 1000 requests per hour
  window: Duration(hours: 1),
  onRateLimitExceeded: (context, args) {
    final endpoint = context.getProperty<String>('endpoint') ?? 'unknown';
    logger.warn('API rate limit exceeded for $endpoint');
    
    // Track rate limit violations
    metrics.incrementCounter('rate_limit_exceeded', {
      'endpoint': endpoint,
    });
  },
));

// Usage with context
final context = ResilienceContext();
context.setProperty('endpoint', '/api/users');

final response = await pipeline.execute(
  (context) => apiClient.get('/api/users'),
  context: context,
);
```

### Database Connection Rate Limiting

```dart
final dbRateLimiter = RateLimiterStrategy(RateLimiterStrategyOptions(
  permitLimit: 50, // 50 concurrent operations
  window: Duration(seconds: 1),
  queueLimit: 20, // Queue up to 20 operations
  onRateLimitExceeded: (context, args) {
    logger.debug('Database rate limit reached, queueing operation');
  },
));

final dbPipeline = ResiliencePipelineBuilder()
    .addStrategy(dbRateLimiter)
    .addTimeout(Duration(seconds: 30))
    .build();
```

### User-Specific Rate Limiting

```dart
final userRateLimiter = RateLimiterStrategy(RateLimiterStrategyOptions(
  permitLimit: 100, // 100 operations per user per hour
  window: Duration(hours: 1),
  onRateLimitExceeded: (context, args) {
    final userId = context.getProperty<String>('userId');
    logger.warn('User $userId exceeded rate limit');
    
    // Could implement user-specific penalties
    userService.recordRateLimitViolation(userId!);
  },
));

// Usage
final context = ResilienceContext();
context.setProperty('userId', 'user123');

await pipeline.execute(
  (context) => processUserRequest(userId),
  context: context,
);
```

### Bulk Operation Rate Limiting

```dart
final bulkRateLimiter = RateLimiterStrategy(RateLimiterStrategyOptions(
  permitLimit: 10, // Only 10 bulk operations per minute
  window: Duration(minutes: 1),
  queueLimit: 5, // Queue a few bulk operations
  onRateLimitExceeded: (context, args) {
    final operationType = context.getProperty<String>('operationType');
    logger.info('Bulk operation rate limited: $operationType');
  },
));

final bulkPipeline = ResiliencePipelineBuilder()
    .addStrategy(bulkRateLimiter)
    .build();

// Usage for different bulk operations
await bulkPipeline.execute((context) {
  context.setProperty('operationType', 'bulk_email');
  return sendBulkEmails(emailList);
});

await bulkPipeline.execute((context) {
  context.setProperty('operationType', 'bulk_update');
  return updateBulkRecords(updates);
});
```

### External Service Rate Limiting

```dart
final externalServiceRateLimiter = RateLimiterStrategy(RateLimiterStrategyOptions(
  permitLimit: 500, // 500 calls per 15 minutes (respecting external API limits)
  window: Duration(minutes: 15),
  queueLimit: 50,
  onRateLimitExceeded: (context, args) {
    final service = context.getProperty<String>('externalService');
    logger.warn('External service rate limit: $service');
    
    // Alert when approaching external service limits
    if (shouldAlertExternalRateLimit(service!)) {
      alertService.sendAlert('Approaching rate limit for $service');
    }
  },
));
```

### File Processing Rate Limiting

```dart
final fileProcessingRateLimiter = RateLimiterStrategy(RateLimiterStrategyOptions(
  permitLimit: 5, // Process 5 files at a time
  window: Duration(seconds: 1),
  queueLimit: 100, // Large queue for file processing
  onRateLimitExceeded: (context, args) {
    final fileName = context.getProperty<String>('fileName');
    logger.debug('File processing queued: $fileName');
  },
));

final fileProcessingPipeline = ResiliencePipelineBuilder()
    .addStrategy(fileProcessingRateLimiter)
    .addTimeout(Duration(minutes: 10))
    .build();

// Process multiple files with rate limiting
for (final file in filesToProcess) {
  final context = ResilienceContext();
  context.setProperty('fileName', file.name);
  
  await fileProcessingPipeline.execute(
    (context) => processFile(file),
    context: context,
  );
}
```

### Adaptive Rate Limiting

```dart
class AdaptiveRateLimiter {
  int _currentLimit = 100;
  
  RateLimiterStrategy<T> createRateLimiter<T>() {
    return RateLimiterStrategy(RateLimiterStrategyOptions(
      permitLimit: _currentLimit,
      window: Duration(minutes: 1),
      onRateLimitExceeded: (context, args) {
        // Reduce rate limit if we're hitting it too often
        if (shouldReduceLimit()) {
          _currentLimit = (_currentLimit * 0.8).round();
          logger.info('Reduced rate limit to $_currentLimit');
        }
      },
    ));
  }
  
  void increaseLimit() {
    // Gradually increase limit during low traffic
    _currentLimit = (_currentLimit * 1.1).round();
  }
}
```

### Rate Limiting with Retry

```dart
final pipeline = ResiliencePipelineBuilder()
    .addRateLimiter(RateLimiterStrategyOptions(
      permitLimit: 100,
      window: Duration(minutes: 1),
    ))
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 3,
      delay: Duration(seconds: 5),
      shouldHandle: (outcome) =>
        outcome.hasException &&
        outcome.exception is RateLimitExceededException,
    ))
    .build();
```

### Multiple Rate Limiters

```dart
// Different rate limits for different operation types
final readRateLimiter = RateLimiterStrategy(RateLimiterStrategyOptions(
  permitLimit: 1000, // High limit for reads
  window: Duration(minutes: 1),
));

final writeRateLimiter = RateLimiterStrategy(RateLimiterStrategyOptions(
  permitLimit: 100, // Lower limit for writes
  window: Duration(minutes: 1),
));

// Use in different pipelines
final readPipeline = ResiliencePipelineBuilder()
    .addStrategy(readRateLimiter)
    .build();

final writePipeline = ResiliencePipelineBuilder()
    .addStrategy(writeRateLimiter)
    .build();
```

### Sliding Window Rate Limiting

```dart
final slidingWindowRateLimiter = RateLimiterStrategy(RateLimiterStrategyOptions(
  permitLimit: 60, // 60 operations per minute
  window: Duration(minutes: 1), // Sliding window
  onRateLimitExceeded: (context, args) {
    final timestamp = DateTime.now();
    logger.debug('Rate limit exceeded at $timestamp, retry after ${args.retryAfter}');
  },
));
```

## Best Practices

### Choose Appropriate Limits

```dart
// For user-facing APIs - generous limits
RateLimiterStrategyOptions(
  permitLimit: 1000,
  window: Duration(hours: 1),
)

// For expensive operations - strict limits
RateLimiterStrategyOptions(
  permitLimit: 10,
  window: Duration(minutes: 1),
)

// For bulk operations - very strict limits
RateLimiterStrategyOptions(
  permitLimit: 1,
  window: Duration(minutes: 5),
)
```

### Use Queueing Wisely

```dart
// For interactive operations - no queueing
RateLimiterStrategyOptions(
  permitLimit: 100,
  queueLimit: 0, // Fail fast for user interactions
)

// For background operations - large queue
RateLimiterStrategyOptions(
  permitLimit: 10,
  queueLimit: 1000, // Large queue for background work
)
```

### Monitor Rate Limit Usage

```dart
RateLimiterStrategyOptions(
  permitLimit: 100,
  onRateLimitExceeded: (context, args) {
    final operation = context.getProperty<String>('operation');
    
    // Track rate limit metrics
    metrics.incrementCounter('rate_limit_exceeded', {
      'operation': operation,
    });
    
    // Track retry-after times
    metrics.recordHistogram('rate_limit_retry_after', 
      args.retryAfter.inSeconds);
    
    // Alert if rate limits are frequently exceeded
    if (isFrequentlyExceeded(operation)) {
      alertService.sendAlert('Frequent rate limit violations: $operation');
    }
  },
)
```

### Combine with Circuit Breakers

```dart
final pipeline = ResiliencePipelineBuilder()
    .addRateLimiter(RateLimiterStrategyOptions(
      permitLimit: 100,
      window: Duration(minutes: 1),
    ))
    .addCircuitBreaker(CircuitBreakerStrategyOptions(
      failureRatio: 0.5,
      minimumThroughput: 10,
    ))
    .build();
```

### Handle Rate Limit Exceptions

```dart
try {
  final result = await pipeline.execute(operation);
  return result;
} on RateLimitExceededException catch (e) {
  // Handle rate limit specifically
  logger.warn('Rate limit exceeded, retry after ${e.retryAfter}');
  
  // Could implement exponential backoff
  await Future.delayed(e.retryAfter);
  
  // Or return cached data
  return getCachedResult();
}
```

### Test Rate Limiting

```dart
test('should enforce rate limits', () async {
  final rateLimiter = RateLimiterStrategy(RateLimiterStrategyOptions(
    permitLimit: 2,
    window: Duration(seconds: 1),
  ));
  
  // First two calls should succeed
  await pipeline.execute(mockOperation);
  await pipeline.execute(mockOperation);
  
  // Third call should be rate limited
  expect(
    () => pipeline.execute(mockOperation),
    throwsA(isA<RateLimitExceededException>()),
  );
});
```

### Consider Time Zones and Peaks

```dart
// Adjust rate limits based on time of day
RateLimiterStrategyOptions(
  permitLimit: isPeakHours() ? 50 : 100,
  window: Duration(minutes: 1),
)

// Or use different rate limiters for different times
final peakHoursRateLimiter = RateLimiterStrategy(RateLimiterStrategyOptions(
  permitLimit: 50,
  window: Duration(minutes: 1),
));

final offPeakRateLimiter = RateLimiterStrategy(RateLimiterStrategyOptions(
  permitLimit: 200,
  window: Duration(minutes: 1),
));
```
