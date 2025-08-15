---
sidebar_position: 3
---

# Basic Concepts

Understanding the fundamental concepts behind Polly Dart will help you build more effective resilience strategies and debug issues when they arise.

## The Resilience Pipeline

At the heart of Polly Dart is the **Resilience Pipeline** - a composable chain of strategies that wrap your code execution.

```mermaid
graph LR
    A[Your Code] --> B[Pipeline]
    B --> C[Strategy 1]
    C --> D[Strategy 2]  
    D --> E[Strategy N]
    E --> F[Actual Operation]
    F --> E
    E --> D
    D --> C
    C --> B
    B --> A
```

### Pipeline Execution Flow

When you execute code through a pipeline:

1. **Request enters** the pipeline
2. **Each strategy** gets a chance to handle/modify the execution
3. **The operation** is executed at the end of the chain
4. **Each strategy** can handle the result/exception on the way back
5. **Final result** is returned to your code

### Strategy Ordering Matters

Strategies are applied in the order you add them to the builder:

```dart
// This order: Retry → Circuit Breaker → Timeout → Your Code
final pipeline1 = ResiliencePipelineBuilder()
    .addRetry()
    .addCircuitBreaker() 
    .addTimeout()
    .build();

// This order: Circuit Breaker → Retry → Timeout → Your Code  
final pipeline2 = ResiliencePipelineBuilder()
    .addCircuitBreaker()
    .addRetry()
    .addTimeout()
    .build();
```

**Why order matters:**
- `pipeline1`: Circuit breaker sees retry attempts as separate calls
- `pipeline2`: Circuit breaker sees original calls, retry happens after circuit check

## Outcomes vs Exceptions

Polly Dart introduces the concept of **Outcomes** to handle both successful results and failures uniformly.

### The Outcome Type

```dart
sealed class Outcome<T> {
  // Creates a successful outcome
  const factory Outcome.fromResult(T result);
  
  // Creates a failure outcome  
  const factory Outcome.fromException(Object exception, [StackTrace? stackTrace]);
  
  bool get hasResult;
  bool get hasException;
  T get result;
  Object get exception;
  StackTrace? get stackTrace;
}
```

### Why Outcomes?

Traditional exception handling has limitations in resilience scenarios:

```dart
// ❌ Traditional approach - strategies can't inspect results
try {
  final result = await someOperation();
  // What if result indicates a "soft failure"?
  if (result.status == 'temporary_failure') {
    // Should we retry? Strategies don't know!
  }
} catch (e) {
  // Only exceptions trigger resilience logic
}

// ✅ Outcome approach - strategies can inspect everything
final outcome = await pipeline.executeAndCapture((context) async {
  final result = await someOperation();
  
  // Convert "soft failures" to exceptions for strategy handling
  if (result.status == 'temporary_failure') {
    throw TemporaryFailureException(result.message);
  }
  
  return result;
});
```

## Resilience Context

The `ResilienceContext` carries information and state through the pipeline execution.

### Context Properties

```dart
class ResilienceContext {
  // Tracks retry attempts
  int get attemptNumber;
  
  // Unique identifier for the operation
  String? get operationKey;
  
  // Cancellation support
  bool get isCancellationRequested;
  
  // Custom properties
  T? getProperty<T>(String key);
  void setProperty(String key, Object value);
}
```

### Using Context

```dart
final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      onRetry: (args) async {
        // Access context in callbacks
        print('Retry attempt: ${args.context.attemptNumber}');
        print('User ID: ${args.context.getProperty<int>('userId')}');
      },
    ))
    .build();

// Pass custom context
final context = ResilienceContext(operationKey: 'fetch-user-data');
context.setProperty('userId', 123);
context.setProperty('timeout', Duration(seconds: 30));

final result = await pipeline.execute(
  (ctx) async {
    final userId = ctx.getProperty<int>('userId')!;
    final timeout = ctx.getProperty<Duration>('timeout')!;
    return await fetchUserWithTimeout(userId, timeout);
  },
  context: context,
);
```

## Strategy Types

Polly Dart provides two main categories of resilience strategies:

### Reactive Strategies
Handle failures **after** they occur:

| Strategy | Purpose | When to Use |
|----------|---------|-------------|
| **Retry** | Automatically retry failed operations | Transient network issues, temporary service unavailability |
| **Circuit Breaker** | Stop calling failing services | Prevent cascading failures, give services time to recover |
| **Fallback** | Provide alternative responses | Graceful degradation when primary operation fails |
| **Hedging** | Execute multiple attempts in parallel | When you need the fastest response from redundant services |

### Proactive Strategies  
Prevent failures **before** they impact your system:

| Strategy | Purpose | When to Use |
|----------|---------|-------------|
| **Timeout** | Cancel operations that take too long | Prevent hanging requests, ensure responsive UX |
| **Rate Limiter** | Control operation rate and concurrency | Prevent overwhelming services, manage resource usage |

## Predicate Functions

Many strategies use **predicate functions** to determine when they should activate:

### ShouldHandle Predicate

```dart
typedef ShouldHandlePredicate<T> = bool Function(Outcome<T> outcome);
```

This function decides whether a strategy should handle a particular outcome:

```dart
final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      shouldHandle: (outcome) {
        // Only retry on specific exceptions
        if (!outcome.hasException) return false;
        
        final exception = outcome.exception;
        return exception is SocketException ||
               exception is TimeoutException ||
               (exception is HttpException && 
                exception.message.contains('503'));
      },
    ))
    .addFallback(FallbackStrategyOptions(
      shouldHandle: (outcome) {
        // Fallback on any failure
        return outcome.hasException;
      },
      fallbackAction: (args) async {
        return Outcome.fromResult('Cached data');
      },
    ))
    .build();
```

### Common Predicate Patterns

```dart
// Retry only transient HTTP errors
bool isTransientHttpError(Outcome outcome) {
  if (!outcome.hasException) return false;
  
  final exception = outcome.exception;
  if (exception is HttpException) {
    final status = exception.statusCode;
    return status >= 500 || status == 408 || status == 429;
  }
  
  return exception is SocketException || exception is TimeoutException;
}

// Handle specific business logic failures
bool isBusinessLogicRetryable(Outcome outcome) {
  if (outcome.hasResult) {
    final result = outcome.result;
    if (result is ApiResponse) {
      return result.isRetryable;
    }
  }
  return false;
}
```

## Configuration Patterns

### Strategy Options

Each strategy has its own options class that follows a consistent pattern:

```dart
// Basic configuration
final basicOptions = RetryStrategyOptions(
  maxRetryAttempts: 3,
  delay: Duration(seconds: 1),
);

// Advanced configuration with callbacks
final advancedOptions = RetryStrategyOptions(
  maxRetryAttempts: 5,
  delay: Duration(milliseconds: 500),
  backoffType: DelayBackoffType.exponential,
  useJitter: true,
  maxDelay: Duration(seconds: 30),
  shouldHandle: (outcome) => isTransientError(outcome),
  onRetry: (args) async {
    logRetryAttempt(args.attemptNumber, args.outcome);
  },
);
```

### Named Constructors

Many options classes provide named constructors for common scenarios:

```dart
// Immediate retries (no delay)
final immediateRetry = RetryStrategyOptions.immediate(
  maxRetryAttempts: 3,
);

// Constant delay retries
final constantDelay = RetryStrategyOptions.noDelay(
  maxRetryAttempts: 2,
);

// Infinite retries (use carefully!)
final infiniteRetry = RetryStrategyOptions.infinite(
  delay: Duration(seconds: 1),
);
```

## Error Handling Philosophy

### Fail Fast vs Resilience

There's a balance between failing fast and providing resilience:

```dart
// ❌ Too aggressive - might mask real issues
final overlyResilient = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 100))
    .addFallback(FallbackStrategyOptions.withValue('always works'))
    .build();

// ✅ Balanced - retries transient issues, fails on persistent problems
final balanced = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 3,
      shouldHandle: (outcome) => isTransientError(outcome),
    ))
    .addFallback(FallbackStrategyOptions(
      shouldHandle: (outcome) => isRecoverableError(outcome),
      fallbackAction: (args) async => getCachedData(),
    ))
    .build();
```

### Observability

Always include observability in your resilience strategies:

```dart
final observablePipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      onRetry: (args) async {
        // Log retry attempts
        logger.info('Retrying operation ${args.context.operationKey}, '
                   'attempt ${args.attemptNumber + 1}');
        
        // Emit metrics
        metrics.incrementCounter('retry_attempts', {
          'operation': args.context.operationKey ?? 'unknown',
          'attempt': args.attemptNumber.toString(),
        });
      },
    ))
    .addCircuitBreaker(CircuitBreakerStrategyOptions(
      onOpened: (args) async {
        // Alert on circuit breaker opening
        alerts.send('Circuit breaker opened for ${args.context.operationKey}');
      },
    ))
    .build();
```

## Performance Considerations

### Pipeline Overhead

Resilience pipelines add a small overhead:

```dart
// Minimal overhead - strategies only activate on failure
final lightPipeline = ResiliencePipelineBuilder()
    .addTimeout(Duration(seconds: 30))
    .build();

// Higher overhead - complex retry logic and circuit breaker state
final heavyPipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      delayGenerator: (args) async => calculateDynamicDelay(args),
    ))
    .addCircuitBreaker(CircuitBreakerStrategyOptions(
      stateProvider: customStateProvider,
    ))
    .build();
```

### Memory Usage

Pipelines are stateless and can be reused:

```dart
class ApiClient {
  // ✅ Good - single pipeline instance, reused for all calls
  static final _pipeline = ResiliencePipelineBuilder()
      .addRetry()
      .addTimeout(Duration(seconds: 30))
      .build();
  
  Future<String> getData() async {
    return await _pipeline.execute((context) async {
      return await httpClient.get('/data');
    });
  }
}

// ❌ Bad - creates new pipeline for each call
Future<String> getData() async {
  final pipeline = ResiliencePipelineBuilder()  // Don't do this!
      .addRetry()
      .build();
  
  return await pipeline.execute((context) async {
    return await httpClient.get('/data');
  });
}
```

## Next Steps

Now that you understand the core concepts:

1. **[Explore Strategies](../strategies/overview)** - Learn about each resilience strategy in detail
2. **[See Real Examples](../examples/http-client)** - Study practical implementations  
3. **[Advanced Patterns](../advanced/combining-strategies)** - Build sophisticated resilience pipelines
4. **[Testing](../advanced/testing)** - Learn how to test resilient code effectively

## Key Takeaways

- **Pipelines** compose multiple strategies into a coherent resilience solution
- **Outcomes** provide a unified way to handle both successes and failures  
- **Context** carries state and metadata through the execution
- **Strategy order** affects how they interact with each other
- **Predicates** give you fine-grained control over when strategies activate
- **Observability** is crucial for understanding and debugging resilience behavior
