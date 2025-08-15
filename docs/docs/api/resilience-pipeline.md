---
sidebar_position: 1
---

# ResiliencePipeline

The `ResiliencePipeline` class is the core execution engine that combines multiple resilience strategies into a cohesive resilience solution.

## Overview

A resilience pipeline executes your code through a chain of strategies, each providing specific resilience capabilities. The pipeline ensures that strategies are applied in the correct order and manages the flow of execution and outcomes.

```dart
class ResiliencePipeline {
  const ResiliencePipeline(List<ResilienceStrategy> strategies);
  
  Future<T> execute<T>(ResilienceCallback<T> callback, {ResilienceContext? context});
  Future<Outcome<T>> executeAndCapture<T>(ResilienceCallback<T> callback, {ResilienceContext? context});
}
```

## Constructor

### ResiliencePipeline(List&lt;ResilienceStrategy&gt; strategies)

Creates a resilience pipeline with the specified strategies.

**Parameters:**
- `strategies` - List of resilience strategies to include in the pipeline

**Example:**
```dart
final strategies = [
  RetryStrategy(RetryStrategyOptions(maxRetryAttempts: 3)),
  TimeoutStrategy(TimeoutStrategyOptions(timeout: Duration(seconds: 30))),
];

final pipeline = ResiliencePipeline(strategies);
```

:::tip Use ResiliencePipelineBuilder
While you can create pipelines directly, it's recommended to use `ResiliencePipelineBuilder` for a more fluent API and better validation.
:::

## Methods

### execute&lt;T&gt;()

Executes a callback through the resilience pipeline with exception-based error handling.

```dart
Future<T> execute<T>(
  ResilienceCallback<T> callback, 
  {ResilienceContext? context}
)
```

**Parameters:**
- `callback` - The operation to execute with resilience
- `context` - Optional resilience context for the execution

**Returns:** `Future<T>` - The result of the operation

**Throws:** Exception if the operation fails after all resilience strategies are exhausted

**Example:**
```dart
final result = await pipeline.execute((context) async {
  return await httpClient.get('https://api.example.com/data');
});
```

### executeAndCapture&lt;T&gt;()

Executes a callback and returns the outcome without throwing exceptions.

```dart
Future<Outcome<T>> executeAndCapture<T>(
  ResilienceCallback<T> callback,
  {ResilienceContext? context}
)
```

**Parameters:**
- `callback` - The operation to execute with resilience
- `context` - Optional resilience context for the execution

**Returns:** `Future<Outcome<T>>` - An outcome representing either success or failure

**Example:**
```dart
final outcome = await pipeline.executeAndCapture((context) async {
  return await risky.operation();
});

if (outcome.hasResult) {
  print('Success: ${outcome.result}');
} else {
  print('Failed: ${outcome.exception}');
}
```

## Properties

### strategyCount

Gets the number of strategies in this pipeline.

```dart
int get strategyCount
```

**Example:**
```dart
print('Pipeline has ${pipeline.strategyCount} strategies');
```

### isEmpty

Checks if the pipeline is empty (has no strategies).

```dart
bool get isEmpty
```

### isNotEmpty

Checks if the pipeline has any strategies.

```dart
bool get isNotEmpty
```

## Type Definitions

### ResilienceCallback&lt;T&gt;

Signature for callbacks executed by the resilience pipeline.

```dart
typedef ResilienceCallback<T> = Future<T> Function(ResilienceContext context);
```

The callback receives a `ResilienceContext` that can be used to:
- Access execution metadata (attempt number, operation key, etc.)
- Store and retrieve custom properties
- Check for cancellation requests

**Example:**
```dart
Future<String> myCallback(ResilienceContext context) async {
  final attemptNumber = context.attemptNumber;
  final operationKey = context.operationKey;
  
  print('Executing $operationKey, attempt $attemptNumber');
  
  return await performOperation();
}
```

## Usage Patterns

### Basic Pipeline Creation

```dart
// Create pipeline with builder (recommended)
final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 3))
    .addTimeout(Duration(seconds: 30))
    .build();

// Use the pipeline
final result = await pipeline.execute((context) async {
  return await someOperation();
});
```

### Pipeline Reuse

Pipelines are stateless and should be reused across multiple operations:

```dart
class ApiService {
  // ✅ Good: Single pipeline instance
  static final _pipeline = ResiliencePipelineBuilder()
      .addRetry()
      .addTimeout(Duration(seconds: 30))
      .build();
  
  Future<User> getUser(int id) {
    return _pipeline.execute((context) async {
      return await httpClient.get('/users/$id');
    });
  }
  
  Future<List<Post>> getPosts() {
    return _pipeline.execute((context) async {
      return await httpClient.get('/posts');
    });
  }
}
```

### Context-Aware Execution

```dart
// Execute with custom context
final context = ResilienceContext(operationKey: 'user-fetch');
context.setProperty('userId', 123);
context.setProperty('timeout', Duration(seconds: 15));

final user = await pipeline.execute((ctx) async {
  final userId = ctx.getProperty<int>('userId')!;
  final timeout = ctx.getProperty<Duration>('timeout')!;
  
  return await fetchUserWithTimeout(userId, timeout);
}, context: context);
```

### Error Handling Patterns

#### Traditional Exception Handling
```dart
try {
  final result = await pipeline.execute((context) async {
    return await riskyOperation();
  });
  
  // Use result
  processResult(result);
} on TimeoutRejectedException {
  // Handle timeout specifically
  showTimeoutMessage();
} on CircuitBreakerOpenException {
  // Handle circuit breaker
  showServiceUnavailableMessage();
} catch (e) {
  // Handle other failures
  showGenericErrorMessage();
}
```

#### Outcome-Based Handling
```dart
final outcome = await pipeline.executeAndCapture((context) async {
  return await riskyOperation();
});

switch (outcome) {
  case ResultOutcome(result: final value):
    processResult(value);
    break;
  case ExceptionOutcome(exception: final error):
    if (error is TimeoutRejectedException) {
      showTimeoutMessage();
    } else if (error is CircuitBreakerOpenException) {
      showServiceUnavailableMessage();
    } else {
      showGenericErrorMessage();
    }
    break;
}
```

### Generic Type Handling

The pipeline supports any return type through Dart's generics:

```dart
// String result
final message = await pipeline.execute<String>((context) async {
  return await getMessage();
});

// Custom object result
final user = await pipeline.execute<User>((context) async {
  return await fetchUser();
});

// Void operations
await pipeline.execute<void>((context) async {
  await sendNotification();
});

// List results
final users = await pipeline.execute<List<User>>((context) async {
  return await fetchAllUsers();
});
```

## Best Practices

### ✅ Do

**Reuse Pipeline Instances**
```dart
class DatabaseService {
  static final _pipeline = ResiliencePipelineBuilder()
      .addRetry()
      .addTimeout(Duration(seconds: 15))
      .build();
  
  // Reuse _pipeline for all operations
}
```

**Use Descriptive Operation Keys**
```dart
final context = ResilienceContext(operationKey: 'payment-processing');
await pipeline.execute(paymentOperation, context: context);
```

**Handle Specific Exceptions**
```dart
try {
  await pipeline.execute(operation);
} on TimeoutRejectedException {
  // Specific timeout handling
} on RetryExhaustedException {
  // Specific retry exhausted handling
}
```

### ❌ Don't

**Create Pipelines Per Operation**
```dart
// ❌ Bad: Creates new pipeline every time
Future<String> fetchData() async {
  final pipeline = ResiliencePipelineBuilder().addRetry().build();
  return await pipeline.execute(operation);
}
```

**Ignore Pipeline Context**
```dart
// ❌ Bad: Not using context information
await pipeline.execute((context) async {
  // Context contains useful information - use it!
  return await operation();
});
```

**Swallow All Exceptions**
```dart
// ❌ Bad: Hiding all errors
try {
  await pipeline.execute(operation);
} catch (e) {
  // Don't just ignore all exceptions
}
```

## Thread Safety

`ResiliencePipeline` instances are **thread-safe** and can be safely used concurrently from multiple isolates or asynchronous operations.

```dart
// Safe to use the same pipeline concurrently
final pipeline = ResiliencePipelineBuilder()
    .addRetry()
    .build();

// Multiple concurrent executions
final futures = [
  pipeline.execute(() => operation1()),
  pipeline.execute(() => operation2()),
  pipeline.execute(() => operation3()),
];

final results = await Future.wait(futures);
```

## Performance Characteristics

- **Memory Usage**: Pipelines are lightweight and stateless
- **Execution Overhead**: Minimal overhead when strategies don't activate
- **Strategy Chaining**: Strategies are executed in sequence, not parallel
- **Garbage Collection**: No persistent state means easier garbage collection

## Integration Examples

### With HTTP Clients
```dart
class ResilientHttpClient {
  final _pipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions(maxRetryAttempts: 3))
      .addCircuitBreaker()
      .addTimeout(Duration(seconds: 30))
      .build();
  
  Future<Response> get(String url) {
    return _pipeline.execute((context) async {
      return await httpClient.get(url);
    });
  }
}
```

### With Database Operations
```dart
class ResilientRepository {
  final _pipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions(maxRetryAttempts: 2))
      .addTimeout(Duration(seconds: 10))
      .build();
  
  Future<User?> findUser(int id) {
    return _pipeline.execute((context) async {
      return await database.users.findById(id);
    });
  }
}
```

### With Business Logic
```dart
class PaymentProcessor {
  final _pipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions(
        shouldHandle: (outcome) => isTransientPaymentError(outcome),
      ))
      .addCircuitBreaker()
      .addFallback(FallbackStrategyOptions(
        fallbackAction: (args) => processOfflinePayment(args),
      ))
      .build();
  
  Future<PaymentResult> processPayment(PaymentRequest request) {
    return _pipeline.execute((context) async {
      return await paymentGateway.process(request);
    });
  }
}
```

## See Also

- **[ResiliencePipelineBuilder](./resilience-pipeline-builder)** - Fluent API for creating pipelines
- **[ResilienceContext](./resilience-context)** - Execution context and metadata
- **[Outcome](./outcome)** - Result and exception handling
- **[Resilience Strategies](./strategies)** - Available strategy implementations
