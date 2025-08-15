---
sidebar_position: 5
---

# RetryStrategy

The `RetryStrategy` provides automatic retry functionality for transient failures with configurable backoff strategies.

## Overview

The retry strategy automatically retries failed operations based on configurable criteria. It supports different backoff strategies, jitter, and customizable retry conditions.

```dart
class RetryStrategy<T> extends ResilienceStrategy<T> {
  RetryStrategy(RetryStrategyOptions<T> options);
  
  Future<Outcome<T>> executeCore<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
    ResilienceCallback<T> next,
  );
}

class RetryStrategyOptions<T> {
  const RetryStrategyOptions({
    this.maxRetryAttempts = 3,
    this.delay = const Duration(seconds: 1),
    this.backoffType = DelayBackoffType.exponential,
    this.useJitter = false,
    this.maxDelay = const Duration(seconds: 30),
    this.shouldHandle,
    this.delayGenerator,
    this.onRetry,
  });
  
  const RetryStrategyOptions.noDelay({
    this.maxRetryAttempts = 3,
    this.backoffType = DelayBackoffType.constant,
    this.useJitter = false,
    this.maxDelay = const Duration(seconds: 30),
    this.shouldHandle,
    this.delayGenerator,
    this.onRetry,
  });
  
  const RetryStrategyOptions.exponentialBackoff({
    this.maxRetryAttempts = 3,
    this.delay = const Duration(seconds: 1),
    this.useJitter = false,
    this.maxDelay = const Duration(seconds: 30),
    this.shouldHandle,
    this.delayGenerator,
    this.onRetry,
  });
}

enum DelayBackoffType {
  constant,
  linear,
  exponential,
}
```

## RetryStrategyOptions Properties

### maxRetryAttempts

Maximum number of retry attempts.

**Type:** `int`  
**Default:** `3`

```dart
RetryStrategyOptions(maxRetryAttempts: 5)
```

### delay

Base delay between retry attempts.

**Type:** `Duration`  
**Default:** `Duration(seconds: 1)`

```dart
RetryStrategyOptions(delay: Duration(milliseconds: 500))
```

### backoffType

The type of backoff strategy to use between retries.

**Type:** `DelayBackoffType`  
**Default:** `DelayBackoffType.exponential`

**Values:**
- `DelayBackoffType.constant` - Fixed delay between retries
- `DelayBackoffType.linear` - Linearly increasing delay
- `DelayBackoffType.exponential` - Exponentially increasing delay

```dart
RetryStrategyOptions(backoffType: DelayBackoffType.linear)
```

### useJitter

Whether to add jitter to the delay to prevent thundering herd.

**Type:** `bool`  
**Default:** `false`

```dart
RetryStrategyOptions(useJitter: true)
```

### maxDelay

Maximum delay between retries.

**Type:** `Duration`  
**Default:** `Duration(seconds: 30)`

```dart
RetryStrategyOptions(maxDelay: Duration(minutes: 2))
```

### shouldHandle

Predicate to determine which outcomes should be retried.

**Type:** `ShouldHandlePredicate<T>?`  
**Default:** `null` (retries all exceptions)

```dart
RetryStrategyOptions(
  shouldHandle: (outcome) => 
    outcome.hasException && 
    outcome.exception is TimeoutException,
)
```

### delayGenerator

Custom delay generator for advanced retry logic.

**Type:** `DelayGenerator<T>?`  
**Default:** `null`

```dart
RetryStrategyOptions(
  delayGenerator: (context, args) {
    // Custom exponential backoff with jitter
    final baseDelay = args.delay.inMilliseconds;
    final attempt = args.attemptNumber;
    final delayMs = baseDelay * math.pow(2, attempt - 1);
    final jitter = Random().nextInt(1000);
    return Duration(milliseconds: delayMs.toInt() + jitter);
  },
)
```

### onRetry

Callback invoked when a retry is about to be performed.

**Type:** `OnRetryCallback<T>?`  
**Default:** `null`

```dart
RetryStrategyOptions(
  onRetry: (context, args) {
    print('Retry attempt ${args.attemptNumber} after ${args.delay}');
  },
)
```

## Constructors

### RetryStrategyOptions()

Creates retry options with default exponential backoff.

```dart
final options = RetryStrategyOptions(
  maxRetryAttempts: 3,
  delay: Duration(seconds: 1),
  backoffType: DelayBackoffType.exponential,
);
```

### RetryStrategyOptions.noDelay()

Creates retry options with no delay between attempts.

```dart
final options = RetryStrategyOptions.noDelay(
  maxRetryAttempts: 5,
);
```

### RetryStrategyOptions.exponentialBackoff()

Creates retry options with exponential backoff (same as default constructor).

```dart
final options = RetryStrategyOptions.exponentialBackoff(
  maxRetryAttempts: 3,
  delay: Duration(seconds: 2),
  useJitter: true,
);
```

## DelayBackoffType

### constant

Fixed delay between retry attempts.

```dart
// Always waits 1 second between retries
RetryStrategyOptions(
  delay: Duration(seconds: 1),
  backoffType: DelayBackoffType.constant,
)
```

### linear

Linearly increasing delay between retry attempts.

```dart
// Waits 1s, 2s, 3s, 4s... between retries
RetryStrategyOptions(
  delay: Duration(seconds: 1),
  backoffType: DelayBackoffType.linear,
)
```

### exponential

Exponentially increasing delay between retry attempts.

```dart
// Waits 1s, 2s, 4s, 8s... between retries
RetryStrategyOptions(
  delay: Duration(seconds: 1),
  backoffType: DelayBackoffType.exponential,
)
```

## Callback Types

### ShouldHandlePredicate&lt;T&gt;

```dart
typedef ShouldHandlePredicate<T> = bool Function(Outcome<T> outcome);
```

Determines whether an outcome should trigger a retry.

### DelayGenerator&lt;T&gt;

```dart
typedef DelayGenerator<T> = Duration Function(
  ResilienceContext context,
  DelayGeneratorArgs args,
);
```

Generates custom delays for retry attempts.

### OnRetryCallback&lt;T&gt;

```dart
typedef OnRetryCallback<T> = void Function(
  ResilienceContext context,
  OnRetryArgs<T> args,
);
```

Called before each retry attempt.

## Usage Examples

### Basic Retry

```dart
final retryStrategy = RetryStrategy(RetryStrategyOptions(
  maxRetryAttempts: 3,
  delay: Duration(seconds: 1),
));

final pipeline = ResiliencePipelineBuilder()
    .addStrategy(retryStrategy)
    .build();
```

### Exponential Backoff with Jitter

```dart
final retryStrategy = RetryStrategy(RetryStrategyOptions(
  maxRetryAttempts: 5,
  delay: Duration(milliseconds: 500),
  backoffType: DelayBackoffType.exponential,
  useJitter: true,
  maxDelay: Duration(seconds: 30),
));
```

### Conditional Retry

```dart
final retryStrategy = RetryStrategy(RetryStrategyOptions(
  maxRetryAttempts: 3,
  shouldHandle: (outcome) {
    if (!outcome.hasException) return false;
    
    final exception = outcome.exception;
    return exception is SocketException || 
           exception is TimeoutException ||
           (exception is HttpException && 
            [502, 503, 504].contains(exception.statusCode));
  },
));
```

### Custom Delay Logic

```dart
final retryStrategy = RetryStrategy(RetryStrategyOptions(
  maxRetryAttempts: 4,
  delayGenerator: (context, args) {
    // Fibonacci backoff: 1, 1, 2, 3, 5, 8...
    final attempt = args.attemptNumber;
    final fibDelay = fibonacci(attempt) * 1000; // milliseconds
    return Duration(milliseconds: fibDelay);
  },
));
```

### Retry with Monitoring

```dart
final retryStrategy = RetryStrategy(RetryStrategyOptions(
  maxRetryAttempts: 3,
  delay: Duration(seconds: 1),
  backoffType: DelayBackoffType.exponential,
  onRetry: (context, args) {
    final requestId = context.getProperty<String>('requestId');
    logger.info('Retry attempt ${args.attemptNumber} for request $requestId');
    
    // Update metrics
    metrics.incrementCounter('retries', {
      'attempt': args.attemptNumber.toString(),
      'exception': args.outcome.exception.runtimeType.toString(),
    });
  },
));
```

### No Delay Retry

```dart
final retryStrategy = RetryStrategy(RetryStrategyOptions.noDelay(
  maxRetryAttempts: 5,
  shouldHandle: (outcome) => 
    outcome.hasException && 
    outcome.exception is TransientException,
));
```

## Best Practices

### Choose Appropriate Backoff

```dart
// For network calls - exponential with jitter
RetryStrategyOptions(
  backoffType: DelayBackoffType.exponential,
  useJitter: true,
)

// For database operations - linear backoff
RetryStrategyOptions(
  backoffType: DelayBackoffType.linear,
  delay: Duration(milliseconds: 100),
)

// For quick local operations - constant delay
RetryStrategyOptions(
  backoffType: DelayBackoffType.constant,
  delay: Duration(milliseconds: 50),
)
```

### Set Maximum Delays

```dart
RetryStrategyOptions(
  maxDelay: Duration(seconds: 30), // Prevent excessive delays
  maxRetryAttempts: 5, // Limit total attempts
)
```

### Handle Specific Exceptions

```dart
RetryStrategyOptions(
  shouldHandle: (outcome) {
    if (!outcome.hasException) return false;
    
    final exception = outcome.exception;
    
    // Retry transient failures only
    return exception is SocketException ||
           exception is TimeoutException ||
           exception is HttpException && isTransientHttpError(exception);
  },
)
```

### Use Context for State

```dart
RetryStrategyOptions(
  onRetry: (context, args) {
    // Track total retry time
    final startTime = context.getProperty<DateTime>('startTime') ?? DateTime.now();
    final elapsed = DateTime.now().difference(startTime);
    context.setProperty('totalRetryTime', elapsed);
  },
)
```
