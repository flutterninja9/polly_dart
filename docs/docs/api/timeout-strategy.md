---
sidebar_position: 7
---

# TimeoutStrategy

The `TimeoutStrategy` cancels operations that exceed a specified time limit, preventing resource exhaustion and improving system responsiveness.

## Overview

The timeout strategy ensures that operations complete within a reasonable time frame. It uses cancellation tokens to cleanly abort operations and provides configurable timeout handling.

```dart
class TimeoutStrategy<T> extends ResilienceStrategy<T> {
  TimeoutStrategy(TimeoutStrategyOptions<T> options);
  
  Future<Outcome<T>> executeCore<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
    ResilienceCallback<T> next,
  );
}

class TimeoutStrategyOptions<T> {
  const TimeoutStrategyOptions({
    required this.timeout,
    this.onTimeout,
  });
}
```

## TimeoutStrategyOptions Properties

### timeout

The maximum duration to allow for operation execution.

**Type:** `Duration`  
**Required:** Yes

```dart
TimeoutStrategyOptions(
  timeout: Duration(seconds: 30),
)
```

### onTimeout

Callback invoked when an operation times out.

**Type:** `OnTimeoutCallback<T>?`  
**Default:** `null`

```dart
TimeoutStrategyOptions(
  timeout: Duration(seconds: 30),
  onTimeout: (context, args) {
    logger.warn('Operation timed out after ${args.timeout}');
  },
)
```

## Callback Types

### OnTimeoutCallback&lt;T&gt;

```dart
typedef OnTimeoutCallback<T> = void Function(
  ResilienceContext context,
  OnTimeoutArgs args,
);
```

Called when an operation times out.

**OnTimeoutArgs Properties:**
- `timeout` - The timeout duration that was exceeded
- `task` - The task that was cancelled (if available)

## ResiliencePipelineBuilder Integration

The `ResiliencePipelineBuilder` provides convenient methods for adding timeout strategies:

### addTimeout(Duration timeout)

Adds a simple timeout strategy with the specified duration.

```dart
final pipeline = ResiliencePipelineBuilder()
    .addTimeout(Duration(seconds: 30))
    .build();
```

### addTimeoutStrategy(TimeoutStrategyOptions options)

Adds a timeout strategy with advanced configuration.

```dart
final pipeline = ResiliencePipelineBuilder()
    .addTimeoutStrategy(TimeoutStrategyOptions(
      timeout: Duration(seconds: 30),
      onTimeout: (context, args) {
        print('Request timed out after ${args.timeout}');
      },
    ))
    .build();
```

## Usage Examples

### Basic Timeout

```dart
final timeoutStrategy = TimeoutStrategy(TimeoutStrategyOptions(
  timeout: Duration(seconds: 10),
));

final pipeline = ResiliencePipelineBuilder()
    .addStrategy(timeoutStrategy)
    .build();
```

### Timeout with Monitoring

```dart
final timeoutStrategy = TimeoutStrategy(TimeoutStrategyOptions(
  timeout: Duration(seconds: 30),
  onTimeout: (context, args) {
    final operation = context.getProperty<String>('operation') ?? 'unknown';
    logger.warn('Operation $operation timed out after ${args.timeout}');
    
    // Track timeout metrics
    metrics.incrementCounter('timeouts', {
      'operation': operation,
      'timeout_seconds': args.timeout.inSeconds.toString(),
    });
  },
));
```

### Using Builder Shorthand

```dart
// Simple timeout
final pipeline = ResiliencePipelineBuilder()
    .addTimeout(Duration(seconds: 15))
    .build();

// Advanced timeout
final pipeline = ResiliencePipelineBuilder()
    .addTimeoutStrategy(TimeoutStrategyOptions(
      timeout: Duration(seconds: 15),
      onTimeout: (context, args) {
        print('Timeout exceeded: ${args.timeout}');
      },
    ))
    .build();
```

### HTTP Request Timeout

```dart
final httpPipeline = ResiliencePipelineBuilder()
    .addTimeout(Duration(seconds: 30))
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 3))
    .build();

final response = await httpPipeline.execute((context) async {
  context.setProperty('operation', 'fetch_user_data');
  return await httpClient.get('/api/users/123');
});
```

### Database Query Timeout

```dart
final dbPipeline = ResiliencePipelineBuilder()
    .addTimeoutStrategy(TimeoutStrategyOptions(
      timeout: Duration(seconds: 45), // Longer timeout for complex queries
      onTimeout: (context, args) {
        final query = context.getProperty<String>('query') ?? 'unknown';
        logger.error('Database query timed out: $query');
        
        // Could trigger query optimization analysis
        queryAnalyzer.analyzeSlowQuery(query);
      },
    ))
    .build();
```

### File Upload Timeout

```dart
final uploadPipeline = ResiliencePipelineBuilder()
    .addTimeoutStrategy(TimeoutStrategyOptions(
      timeout: Duration(minutes: 10), // Long timeout for large files
      onTimeout: (context, args) {
        final fileName = context.getProperty<String>('fileName');
        final fileSize = context.getProperty<int>('fileSize');
        
        logger.warn('File upload timed out - File: $fileName, Size: $fileSize bytes');
        
        // Clean up temporary resources
        uploadService.cleanupFailedUpload(fileName);
      },
    ))
    .build();

// Usage with context
final context = ResilienceContext();
context.setProperty('fileName', 'document.pdf');
context.setProperty('fileSize', 5242880); // 5MB

await uploadPipeline.execute(
  (context) => uploadService.uploadFile('document.pdf'),
  context: context,
);
```

### Timeout with Fallback

```dart
final pipeline = ResiliencePipelineBuilder()
    .addTimeout(Duration(seconds: 5))
    .addFallback(FallbackStrategyOptions<String>(
      shouldHandle: (outcome) => 
        outcome.hasException && 
        outcome.exception is TimeoutException,
      fallbackAction: (context, args) async {
        return 'Request timed out - using cached data';
      },
    ))
    .build();
```

### Variable Timeouts Based on Context

```dart
final pipeline = ResiliencePipelineBuilder()
    .addTimeoutStrategy(TimeoutStrategyOptions(
      timeout: Duration(seconds: 30), // Default timeout
      onTimeout: (context, args) {
        final operationType = context.getProperty<String>('operationType');
        logger.warn('$operationType operation timed out');
      },
    ))
    .build();

// Adjust timeout based on operation type
Future<String> performOperation(String operationType) async {
  final context = ResilienceContext();
  context.setProperty('operationType', operationType);
  
  return await pipeline.execute((context) async {
    // The timeout is still fixed, but we can track different operation types
    switch (operationType) {
      case 'quick':
        return await quickOperation();
      case 'normal':
        return await normalOperation();
      case 'heavy':
        return await heavyOperation();
      default:
        throw ArgumentError('Unknown operation type: $operationType');
    }
  }, context: context);
}
```

### Multiple Timeout Strategies

```dart
// Different timeouts for different parts of the pipeline
final pipeline = ResiliencePipelineBuilder()
    .addTimeout(Duration(seconds: 10)) // Overall operation timeout
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 3,
      delay: Duration(seconds: 1),
    ))
    .addTimeout(Duration(seconds: 5)) // Individual attempt timeout
    .build();
```

### Timeout with Cancellation Handling

```dart
final pipeline = ResiliencePipelineBuilder()
    .addTimeoutStrategy(TimeoutStrategyOptions(
      timeout: Duration(seconds: 20),
      onTimeout: (context, args) {
        logger.info('Operation cancelled due to timeout');
      },
    ))
    .build();

try {
  final result = await pipeline.execute((context) async {
    return await longRunningOperation(context.cancellationToken);
  });
} on TimeoutException {
  print('Operation was cancelled due to timeout');
} on OperationCancelledException {
  print('Operation was cancelled');
}
```

## Best Practices

### Choose Appropriate Timeouts

```dart
// Quick operations - short timeout
TimeoutStrategyOptions(timeout: Duration(seconds: 5))

// Network requests - medium timeout
TimeoutStrategyOptions(timeout: Duration(seconds: 30))

// Database queries - longer timeout
TimeoutStrategyOptions(timeout: Duration(seconds: 45))

// File operations - very long timeout
TimeoutStrategyOptions(timeout: Duration(minutes: 5))
```

### Monitor Timeout Events

```dart
TimeoutStrategyOptions(
  timeout: Duration(seconds: 30),
  onTimeout: (context, args) {
    // Log timeout with context
    final operation = context.getProperty<String>('operation');
    final startTime = context.getProperty<DateTime>('startTime');
    
    logger.warn('Timeout: $operation after ${args.timeout}');
    
    // Track metrics
    metrics.recordTimeoutEvent(operation, args.timeout);
    
    // Alert if timeouts are frequent
    if (shouldAlert(operation)) {
      alertService.sendTimeoutAlert(operation);
    }
  },
)
```

### Combine with Other Strategies

```dart
// Timeout + Retry: Each retry attempt has its own timeout
final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 3))
    .addTimeout(Duration(seconds: 10)) // Timeout per attempt
    .build();

// Timeout + Circuit Breaker: Timeouts count as failures
final pipeline = ResiliencePipelineBuilder()
    .addTimeout(Duration(seconds: 30))
    .addCircuitBreaker(CircuitBreakerStrategyOptions(
      shouldHandle: (outcome) => 
        outcome.hasException, // TimeoutException counts as failure
    ))
    .build();
```

### Handle Cleanup on Timeout

```dart
TimeoutStrategyOptions(
  timeout: Duration(seconds: 30),
  onTimeout: (context, args) {
    // Clean up resources
    final resourceId = context.getProperty<String>('resourceId');
    if (resourceId != null) {
      resourceManager.cleanup(resourceId);
    }
    
    // Cancel related operations
    final relatedOperations = context.getProperty<List<String>>('relatedOps');
    relatedOperations?.forEach(operationCanceller.cancel);
  },
)
```

### Respect Cancellation Tokens

```dart
// Always check cancellation token in long-running operations
Future<String> longRunningOperation(CancellationToken cancellationToken) async {
  for (int i = 0; i < 1000; i++) {
    // Check for cancellation periodically
    cancellationToken.throwIfCancellationRequested();
    
    // Do work
    await processItem(i);
  }
  
  return 'completed';
}
```
