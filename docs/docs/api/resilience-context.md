---
sidebar_position: 3
---

# ResilienceContext

The `ResilienceContext` class provides contextual information and state management throughout the execution of a resilience pipeline.

## Overview

The resilience context is passed through the entire execution chain, allowing strategies to share state, cancel operations, and access execution metadata. It serves as the communication channel between different strategies and the application.

```dart
class ResilienceContext {
  ResilienceContext();
  ResilienceContext.withCancellationToken(CancellationToken cancellationToken);
  
  CancellationToken get cancellationToken;
  bool get isCancellationRequested;
  Map<String, dynamic> get properties;
  
  void setProperty(String key, dynamic value);
  T? getProperty<T>(String key);
  bool hasProperty(String key);
  void removeProperty(String key);
  void clearProperties();
}
```

## Constructors

### ResilienceContext()

Creates a new resilience context with a default cancellation token.

```dart
final context = ResilienceContext();
```

### ResilienceContext.withCancellationToken(CancellationToken cancellationToken)

Creates a new resilience context with the specified cancellation token.

**Parameters:**
- `cancellationToken` - The cancellation token for operation cancellation

```dart
final cancellationToken = CancellationToken();
final context = ResilienceContext.withCancellationToken(cancellationToken);
```

## Properties

### cancellationToken

Gets the cancellation token associated with this context.

**Type:** `CancellationToken`

```dart
final token = context.cancellationToken;
if (token.isCancellationRequested) {
  // Handle cancellation
}
```

### isCancellationRequested

Gets a value indicating whether cancellation has been requested.

**Type:** `bool`

```dart
if (context.isCancellationRequested) {
  throw OperationCancelledException();
}
```

### properties

Gets the properties dictionary for storing custom data.

**Type:** `Map<String, dynamic>`

```dart
final props = context.properties;
print('Total properties: ${props.length}');
```

## Methods

### setProperty(String key, dynamic value)

Sets a property value in the context.

**Parameters:**
- `key` - The property key
- `value` - The property value

```dart
context.setProperty('userId', '12345');
context.setProperty('retryCount', 0);
context.setProperty('startTime', DateTime.now());
```

### getProperty&lt;T&gt;(String key)

Gets a property value from the context with type casting.

**Parameters:**
- `key` - The property key

**Returns:** `T?` - The property value cast to type T, or null if not found

```dart
final userId = context.getProperty<String>('userId');
final retryCount = context.getProperty<int>('retryCount') ?? 0;
final startTime = context.getProperty<DateTime>('startTime');
```

### hasProperty(String key)

Checks if a property exists in the context.

**Parameters:**
- `key` - The property key

**Returns:** `bool` - True if the property exists, false otherwise

```dart
if (context.hasProperty('cacheKey')) {
  final cacheKey = context.getProperty<String>('cacheKey');
  // Use cached value
}
```

### removeProperty(String key)

Removes a property from the context.

**Parameters:**
- `key` - The property key to remove

```dart
context.removeProperty('temporaryData');
```

### clearProperties()

Removes all properties from the context.

```dart
context.clearProperties();
```

## Usage Examples

### Basic Context Usage

```dart
final context = ResilienceContext();

// Execute with context
final result = await pipeline.execute(
  (context) async {
    // Check for cancellation
    if (context.isCancellationRequested) {
      throw OperationCancelledException();
    }
    
    return await apiCall();
  },
  context: context,
);
```

### Context with Cancellation

```dart
final cancellationToken = CancellationToken();
final context = ResilienceContext.withCancellationToken(cancellationToken);

// Cancel after 10 seconds
Timer(Duration(seconds: 10), () {
  cancellationToken.cancel();
});

try {
  final result = await pipeline.execute(
    (context) async {
      context.cancellationToken.throwIfCancellationRequested();
      return await longRunningOperation();
    },
    context: context,
  );
} on OperationCancelledException {
  print('Operation was cancelled');
}
```

### Sharing State Between Strategies

```dart
final context = ResilienceContext();

final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      onRetry: (context, args) {
        // Track retry attempts
        final retryCount = context.getProperty<int>('retryCount') ?? 0;
        context.setProperty('retryCount', retryCount + 1);
      },
    ))
    .addCircuitBreaker(CircuitBreakerStrategyOptions(
      onOpened: (context, args) {
        // Access retry information
        final retryCount = context.getProperty<int>('retryCount') ?? 0;
        print('Circuit opened after $retryCount retries');
      },
    ))
    .build();
```

### Request Tracking

```dart
final context = ResilienceContext();
context.setProperty('requestId', 'req-12345');
context.setProperty('userId', 'user-67890');
context.setProperty('startTime', DateTime.now());

final result = await pipeline.execute(
  (context) async {
    final requestId = context.getProperty<String>('requestId');
    final userId = context.getProperty<String>('userId');
    
    print('Processing request $requestId for user $userId');
    
    return await processRequest(requestId, userId);
  },
  context: context,
);

final endTime = DateTime.now();
final startTime = context.getProperty<DateTime>('startTime')!;
final duration = endTime.difference(startTime);
print('Request completed in ${duration.inMilliseconds}ms');
```

### Caching with Context

```dart
final context = ResilienceContext();

final result = await pipeline.execute(
  (context) async {
    final cacheKey = 'data-${userId}';
    
    // Check cache first
    if (context.hasProperty(cacheKey)) {
      return context.getProperty<String>(cacheKey)!;
    }
    
    // Fetch from service
    final data = await fetchUserData(userId);
    
    // Cache for future use
    context.setProperty(cacheKey, data);
    
    return data;
  },
  context: context,
);
```

## Best Practices

### Property Naming

Use descriptive, namespaced property keys to avoid conflicts:

```dart
context.setProperty('app.userId', userId);
context.setProperty('retry.attemptCount', attemptCount);
context.setProperty('circuitBreaker.lastFailureTime', DateTime.now());
```

### Cleanup

Remove temporary properties when no longer needed:

```dart
// Set temporary data
context.setProperty('temp.calculationResult', result);

// Use the data
final temp = context.getProperty('temp.calculationResult');

// Clean up
context.removeProperty('temp.calculationResult');
```

### Type Safety

Always specify types when getting properties:

```dart
// Good
final count = context.getProperty<int>('retryCount') ?? 0;

// Avoid
final count = context.getProperty('retryCount') ?? 0; // Type is dynamic
```
