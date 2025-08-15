---
sidebar_position: 6
---

# CircuitBreakerStrategy

The `CircuitBreakerStrategy` prevents cascading failures by monitoring failure rates and temporarily blocking calls when thresholds are exceeded.

## Overview

The circuit breaker pattern protects your system from cascading failures by monitoring the failure rate of operations. When failures exceed a threshold, the circuit breaker opens and fails fast, giving the downstream system time to recover.

```dart
class CircuitBreakerStrategy<T> extends ResilienceStrategy<T> {
  CircuitBreakerStrategy(CircuitBreakerStrategyOptions<T> options);
  
  Future<Outcome<T>> executeCore<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
    ResilienceCallback<T> next,
  );
  
  CircuitBreakerState get state;
  bool get isOpen;
  bool get isClosed;
  bool get isHalfOpen;
}

class CircuitBreakerStrategyOptions<T> {
  const CircuitBreakerStrategyOptions({
    this.failureRatio = 0.5,
    this.minimumThroughput = 10,
    this.samplingDuration = const Duration(seconds: 30),
    this.breakDuration = const Duration(seconds: 60),
    this.shouldHandle,
    this.onOpened,
    this.onClosed,
    this.onHalfOpened,
  });
}

enum CircuitBreakerState {
  closed,
  open,
  halfOpen,
}
```

## CircuitBreakerStrategyOptions Properties

### failureRatio

The failure ratio threshold at which the circuit breaker opens.

**Type:** `double`  
**Default:** `0.5` (50%)  
**Range:** `0.0` to `1.0`

```dart
CircuitBreakerStrategyOptions(
  failureRatio: 0.3, // Open when 30% of calls fail
)
```

### minimumThroughput

Minimum number of calls required before the circuit breaker can open.

**Type:** `int`  
**Default:** `10`

```dart
CircuitBreakerStrategyOptions(
  minimumThroughput: 20, // Need at least 20 calls
)
```

### samplingDuration

Duration over which failures are measured.

**Type:** `Duration`  
**Default:** `Duration(seconds: 30)`

```dart
CircuitBreakerStrategyOptions(
  samplingDuration: Duration(minutes: 1),
)
```

### breakDuration

Duration to keep the circuit breaker open before transitioning to half-open.

**Type:** `Duration`  
**Default:** `Duration(seconds: 60)`

```dart
CircuitBreakerStrategyOptions(
  breakDuration: Duration(minutes: 2),
)
```

### shouldHandle

Predicate to determine which outcomes count as failures.

**Type:** `ShouldHandlePredicate<T>?`  
**Default:** `null` (all exceptions count as failures)

```dart
CircuitBreakerStrategyOptions(
  shouldHandle: (outcome) => 
    outcome.hasException && 
    outcome.exception is! ArgumentException,
)
```

### onOpened

Callback invoked when the circuit breaker opens.

**Type:** `OnCircuitBreakerOpenedCallback<T>?`  
**Default:** `null`

```dart
CircuitBreakerStrategyOptions(
  onOpened: (context, args) {
    logger.warn('Circuit breaker opened - failure ratio: ${args.failureRate}');
  },
)
```

### onClosed

Callback invoked when the circuit breaker closes.

**Type:** `OnCircuitBreakerClosedCallback<T>?`  
**Default:** `null`

```dart
CircuitBreakerStrategyOptions(
  onClosed: (context, args) {
    logger.info('Circuit breaker closed - system recovered');
  },
)
```

### onHalfOpened

Callback invoked when the circuit breaker transitions to half-open.

**Type:** `OnCircuitBreakerHalfOpenedCallback<T>?`  
**Default:** `null`

```dart
CircuitBreakerStrategyOptions(
  onHalfOpened: (context, args) {
    logger.info('Circuit breaker half-opened - testing recovery');
  },
)
```

## CircuitBreakerState

### closed

Normal operation state where all calls are allowed through.

```dart
if (circuitBreaker.state == CircuitBreakerState.closed) {
  // Normal operation
}
```

### open

Failure state where all calls are immediately rejected.

```dart
if (circuitBreaker.state == CircuitBreakerState.open) {
  // Calls are being blocked
}
```

### halfOpen

Testing state where a limited number of calls are allowed to test recovery.

```dart
if (circuitBreaker.state == CircuitBreakerState.halfOpen) {
  // Testing if service has recovered
}
```

## Properties

### state

Gets the current state of the circuit breaker.

**Type:** `CircuitBreakerState`

```dart
final currentState = circuitBreaker.state;
print('Circuit breaker is ${currentState.name}');
```

### isOpen

Gets whether the circuit breaker is currently open.

**Type:** `bool`

```dart
if (circuitBreaker.isOpen) {
  print('Circuit breaker is blocking calls');
}
```

### isClosed

Gets whether the circuit breaker is currently closed.

**Type:** `bool`

```dart
if (circuitBreaker.isClosed) {
  print('Circuit breaker is allowing calls');
}
```

### isHalfOpen

Gets whether the circuit breaker is currently half-open.

**Type:** `bool`

```dart
if (circuitBreaker.isHalfOpen) {
  print('Circuit breaker is testing recovery');
}
```

## Callback Types

### ShouldHandlePredicate&lt;T&gt;

```dart
typedef ShouldHandlePredicate<T> = bool Function(Outcome<T> outcome);
```

Determines whether an outcome counts as a failure for the circuit breaker.

### OnCircuitBreakerOpenedCallback&lt;T&gt;

```dart
typedef OnCircuitBreakerOpenedCallback<T> = void Function(
  ResilienceContext context,
  OnCircuitBreakerOpenedArgs args,
);
```

Called when the circuit breaker opens due to excessive failures.

### OnCircuitBreakerClosedCallback&lt;T&gt;

```dart
typedef OnCircuitBreakerClosedCallback<T> = void Function(
  ResilienceContext context,
  OnCircuitBreakerClosedArgs args,
);
```

Called when the circuit breaker closes after successful recovery.

### OnCircuitBreakerHalfOpenedCallback&lt;T&gt;

```dart
typedef OnCircuitBreakerHalfOpenedCallback<T> = void Function(
  ResilienceContext context,
  OnCircuitBreakerHalfOpenedArgs args,
);
```

Called when the circuit breaker transitions to half-open state.

## Usage Examples

### Basic Circuit Breaker

```dart
final circuitBreaker = CircuitBreakerStrategy(CircuitBreakerStrategyOptions(
  failureRatio: 0.5,
  minimumThroughput: 10,
  samplingDuration: Duration(seconds: 30),
  breakDuration: Duration(seconds: 60),
));

final pipeline = ResiliencePipelineBuilder()
    .addStrategy(circuitBreaker)
    .build();
```

### Aggressive Circuit Breaker

```dart
final circuitBreaker = CircuitBreakerStrategy(CircuitBreakerStrategyOptions(
  failureRatio: 0.2, // Open at 20% failure rate
  minimumThroughput: 5, // With just 5 calls
  samplingDuration: Duration(seconds: 10),
  breakDuration: Duration(seconds: 30),
));
```

### Conservative Circuit Breaker

```dart
final circuitBreaker = CircuitBreakerStrategy(CircuitBreakerStrategyOptions(
  failureRatio: 0.8, // Open at 80% failure rate
  minimumThroughput: 50, // Need 50 calls minimum
  samplingDuration: Duration(minutes: 5),
  breakDuration: Duration(minutes: 10),
));
```

### Selective Failure Handling

```dart
final circuitBreaker = CircuitBreakerStrategy(CircuitBreakerStrategyOptions(
  failureRatio: 0.5,
  shouldHandle: (outcome) {
    if (!outcome.hasException) return false;
    
    final exception = outcome.exception;
    
    // Only count server errors, not client errors
    if (exception is HttpException) {
      return exception.statusCode >= 500;
    }
    
    // Count network and timeout errors
    return exception is SocketException || 
           exception is TimeoutException;
  },
));
```

### Circuit Breaker with Monitoring

```dart
final circuitBreaker = CircuitBreakerStrategy(CircuitBreakerStrategyOptions(
  failureRatio: 0.5,
  minimumThroughput: 10,
  onOpened: (context, args) {
    logger.error('Circuit breaker OPENED - Failure rate: ${args.failureRate}');
    metrics.incrementCounter('circuit_breaker_opened');
    
    // Alert operations team
    alertingService.sendAlert(
      'Circuit breaker opened for ${context.getProperty("service")}',
      severity: AlertSeverity.high,
    );
  },
  onClosed: (context, args) {
    logger.info('Circuit breaker CLOSED - Service recovered');
    metrics.incrementCounter('circuit_breaker_closed');
  },
  onHalfOpened: (context, args) {
    logger.info('Circuit breaker HALF-OPEN - Testing recovery');
    metrics.incrementCounter('circuit_breaker_half_opened');
  },
));
```

### Database Circuit Breaker

```dart
final dbCircuitBreaker = CircuitBreakerStrategy(CircuitBreakerStrategyOptions(
  failureRatio: 0.6, // Databases can handle more load
  minimumThroughput: 20,
  samplingDuration: Duration(minutes: 2),
  breakDuration: Duration(minutes: 5),
  shouldHandle: (outcome) {
    if (!outcome.hasException) return false;
    
    final exception = outcome.exception;
    
    // Don't count syntax errors as circuit breaker failures
    return exception is! SqlSyntaxException &&
           exception is! ArgumentException;
  },
));
```

### HTTP Service Circuit Breaker

```dart
final httpCircuitBreaker = CircuitBreakerStrategy(CircuitBreakerStrategyOptions(
  failureRatio: 0.4,
  minimumThroughput: 15,
  samplingDuration: Duration(seconds: 45),
  breakDuration: Duration(seconds: 90),
  shouldHandle: (outcome) {
    if (!outcome.hasException) return false;
    
    final exception = outcome.exception;
    
    if (exception is HttpException) {
      // Only 5xx errors trigger circuit breaker
      return exception.statusCode >= 500;
    }
    
    return exception is SocketException || 
           exception is TimeoutException;
  },
  onOpened: (context, args) {
    final service = context.getProperty<String>('serviceName') ?? 'unknown';
    logger.warn('HTTP service circuit breaker opened for $service');
  },
));
```

### Circuit Breaker State Monitoring

```dart
final circuitBreaker = CircuitBreakerStrategy(CircuitBreakerStrategyOptions(
  failureRatio: 0.5,
  minimumThroughput: 10,
));

// Check state before important operations
if (circuitBreaker.isOpen) {
  // Circuit breaker is open, use cached data or alternative service
  return getCachedData();
}

// Or check state in context
context.setProperty('circuitBreakerState', circuitBreaker.state.name);
```

### Multiple Circuit Breakers

```dart
// Different circuit breakers for different services
final userServiceCB = CircuitBreakerStrategy(CircuitBreakerStrategyOptions(
  failureRatio: 0.3,
  minimumThroughput: 10,
  breakDuration: Duration(minutes: 1),
));

final paymentServiceCB = CircuitBreakerStrategy(CircuitBreakerStrategyOptions(
  failureRatio: 0.1, // Payment service needs higher reliability
  minimumThroughput: 5,
  breakDuration: Duration(minutes: 5),
));

// Use in different pipelines
final userPipeline = ResiliencePipelineBuilder()
    .addStrategy(userServiceCB)
    .build();

final paymentPipeline = ResiliencePipelineBuilder()
    .addStrategy(paymentServiceCB)
    .build();
```

## Best Practices

### Configure Thresholds Appropriately

```dart
// For critical services - lower threshold
CircuitBreakerStrategyOptions(
  failureRatio: 0.2,
  minimumThroughput: 5,
)

// For non-critical services - higher threshold
CircuitBreakerStrategyOptions(
  failureRatio: 0.7,
  minimumThroughput: 20,
)
```

### Set Appropriate Timeouts

```dart
CircuitBreakerStrategyOptions(
  samplingDuration: Duration(seconds: 30), // Don't make too short
  breakDuration: Duration(minutes: 2), // Give service time to recover
)
```

### Handle Different Error Types

```dart
CircuitBreakerStrategyOptions(
  shouldHandle: (outcome) {
    if (!outcome.hasException) return false;
    
    final exception = outcome.exception;
    
    // Don't trigger circuit breaker for client errors
    if (exception is ValidationException ||
        exception is AuthenticationException) {
      return false;
    }
    
    // Trigger for server/infrastructure errors
    return true;
  },
)
```

### Monitor Circuit Breaker Events

```dart
CircuitBreakerStrategyOptions(
  onOpened: (context, args) {
    // Log and alert
    logger.error('Circuit breaker opened');
    alertService.notify('Service degradation detected');
    
    // Update health check
    healthCheck.markUnhealthy('Circuit breaker open');
  },
  onClosed: (context, args) {
    // Log recovery
    logger.info('Circuit breaker closed - service recovered');
    healthCheck.markHealthy();
  },
)
```
