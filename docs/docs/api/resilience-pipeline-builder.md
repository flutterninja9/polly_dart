---
sidebar_position: 2
---

# ResiliencePipelineBuilder

The `ResiliencePipelineBuilder` class provides a fluent API for constructing resilience pipelines with multiple strategies.

## Overview

The builder pattern allows you to chain multiple resilience strategies together in a readable and intuitive way. Each strategy is applied in the order it's added to the builder.

```dart
class ResiliencePipelineBuilder {
  ResiliencePipelineBuilder();
  
  ResiliencePipelineBuilder addRetry(RetryStrategyOptions options);
  ResiliencePipelineBuilder addCircuitBreaker(CircuitBreakerStrategyOptions options);
  ResiliencePipelineBuilder addTimeout(Duration timeout);
  ResiliencePipelineBuilder addTimeoutStrategy(TimeoutStrategyOptions options);
  ResiliencePipelineBuilder addFallback(FallbackStrategyOptions options);
  ResiliencePipelineBuilder addHedging(HedgingStrategyOptions options);
  ResiliencePipelineBuilder addRateLimiter(RateLimiterStrategyOptions options);
  ResiliencePipelineBuilder addStrategy(ResilienceStrategy strategy);
  
  ResiliencePipeline build();
}
```

## Constructor

### ResiliencePipelineBuilder()

Creates a new resilience pipeline builder instance.

```dart
final builder = ResiliencePipelineBuilder();
```

## Methods

### addRetry(RetryStrategyOptions options)

Adds a retry strategy to the pipeline.

**Parameters:**
- `options` - Configuration options for the retry strategy

**Returns:** `ResiliencePipelineBuilder` for method chaining

```dart
builder.addRetry(RetryStrategyOptions(
  maxRetryAttempts: 3,
  delay: Duration(seconds: 1),
  backoffType: DelayBackoffType.exponential,
));
```

### addCircuitBreaker(CircuitBreakerStrategyOptions options)

Adds a circuit breaker strategy to the pipeline.

**Parameters:**
- `options` - Configuration options for the circuit breaker strategy

**Returns:** `ResiliencePipelineBuilder` for method chaining

```dart
builder.addCircuitBreaker(CircuitBreakerStrategyOptions(
  failureRatio: 0.5,
  minimumThroughput: 10,
  samplingDuration: Duration(seconds: 30),
  breakDuration: Duration(seconds: 60),
));
```

### addTimeout(Duration timeout)

Adds a timeout strategy to the pipeline with the specified duration.

**Parameters:**
- `timeout` - Maximum duration to allow for execution

**Returns:** `ResiliencePipelineBuilder` for method chaining

```dart
builder.addTimeout(Duration(seconds: 30));
```

### addTimeoutStrategy(TimeoutStrategyOptions options)

Adds a timeout strategy to the pipeline with advanced configuration.

**Parameters:**
- `options` - Configuration options for the timeout strategy

**Returns:** `ResiliencePipelineBuilder` for method chaining

```dart
builder.addTimeoutStrategy(TimeoutStrategyOptions(
  timeout: Duration(seconds: 30),
  onTimeout: (context, args) {
    print('Operation timed out after ${args.timeout}');
  },
));
```

### addFallback(FallbackStrategyOptions options)

Adds a fallback strategy to the pipeline.

**Parameters:**
- `options` - Configuration options for the fallback strategy

**Returns:** `ResiliencePipelineBuilder` for method chaining

```dart
builder.addFallback(FallbackStrategyOptions<String>(
  shouldHandle: (outcome) => outcome.hasException,
  fallbackAction: (context, args) async => 'fallback-value',
));
```

### addHedging(HedgingStrategyOptions options)

Adds a hedging strategy to the pipeline.

**Parameters:**
- `options` - Configuration options for the hedging strategy

**Returns:** `ResiliencePipelineBuilder` for method chaining

```dart
builder.addHedging(HedgingStrategyOptions(
  maxHedgedAttempts: 2,
  delay: Duration(milliseconds: 100),
));
```

### addRateLimiter(RateLimiterStrategyOptions options)

Adds a rate limiter strategy to the pipeline.

**Parameters:**
- `options` - Configuration options for the rate limiter strategy

**Returns:** `ResiliencePipelineBuilder` for method chaining

```dart
builder.addRateLimiter(RateLimiterStrategyOptions(
  permitLimit: 100,
  window: Duration(seconds: 60),
));
```

### addStrategy(ResilienceStrategy strategy)

Adds a custom resilience strategy to the pipeline.

**Parameters:**
- `strategy` - A custom resilience strategy implementation

**Returns:** `ResiliencePipelineBuilder` for method chaining

```dart
final customStrategy = MyCustomStrategy();
builder.addStrategy(customStrategy);
```

### build()

Builds and returns the configured resilience pipeline.

**Returns:** `ResiliencePipeline` - The constructed resilience pipeline

```dart
final pipeline = builder.build();
```

## Usage Examples

### Basic Pipeline

```dart
final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 3))
    .addTimeout(Duration(seconds: 30))
    .build();
```

### Complex Pipeline

```dart
final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 3,
      delay: Duration(seconds: 1),
      backoffType: DelayBackoffType.exponential,
      shouldHandle: (outcome) => outcome.hasException,
    ))
    .addCircuitBreaker(CircuitBreakerStrategyOptions(
      failureRatio: 0.5,
      minimumThroughput: 10,
      onOpened: (context, args) => print('Circuit breaker opened'),
      onClosed: (context, args) => print('Circuit breaker closed'),
    ))
    .addTimeout(Duration(seconds: 30))
    .addFallback(FallbackStrategyOptions<String>(
      shouldHandle: (outcome) => outcome.hasException,
      fallbackAction: (context, args) async => 'Service unavailable',
    ))
    .build();
```

### Pipeline with Rate Limiting

```dart
final pipeline = ResiliencePipelineBuilder()
    .addRateLimiter(RateLimiterStrategyOptions(
      permitLimit: 100,
      window: Duration(minutes: 1),
    ))
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 2))
    .addTimeout(Duration(seconds: 10))
    .build();
```

## Strategy Execution Order

Strategies are executed in the order they are added to the builder:

1. **Rate Limiter** - Controls request rate
2. **Retry** - Handles transient failures
3. **Circuit Breaker** - Prevents cascading failures
4. **Timeout** - Limits execution time
5. **Hedging** - Parallel execution for latency
6. **Fallback** - Provides alternative responses

Choose the order carefully based on your resilience requirements and the nature of failures you want to handle.
