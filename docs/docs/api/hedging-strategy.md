---
sidebar_position: 9
---

# HedgingStrategy

The `HedgingStrategy` improves performance by executing multiple parallel attempts and returning the first successful result, reducing latency caused by slow responses.

## Overview

The hedging strategy executes the primary operation and, after a delay, starts additional parallel attempts. The first successful result is returned, while other attempts are cancelled. This is particularly useful for reducing tail latency in distributed systems.

```dart
class HedgingStrategy<T> extends ResilienceStrategy<T> {
  HedgingStrategy(HedgingStrategyOptions<T> options);
  
  Future<Outcome<T>> executeCore<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
    ResilienceCallback<T> next,
  );
}

class HedgingStrategyOptions<T> {
  const HedgingStrategyOptions({
    this.maxHedgedAttempts = 1,
    this.delay = const Duration(milliseconds: 100),
    this.shouldHandle,
    this.onHedging,
  });
}
```

## HedgingStrategyOptions Properties

### maxHedgedAttempts

Maximum number of additional hedged attempts to execute.

**Type:** `int`  
**Default:** `1`

```dart
HedgingStrategyOptions(
  maxHedgedAttempts: 2, // Total of 3 attempts (1 primary + 2 hedged)
)
```

### delay

Delay before starting each hedged attempt.

**Type:** `Duration`  
**Default:** `Duration(milliseconds: 100)`

```dart
HedgingStrategyOptions(
  delay: Duration(milliseconds: 50),
)
```

### shouldHandle

Predicate to determine which outcomes should trigger hedging.

**Type:** `ShouldHandlePredicate<T>?`  
**Default:** `null` (hedges for all outcomes)

```dart
HedgingStrategyOptions(
  shouldHandle: (outcome) => 
    outcome.hasException || 
    isSlowResponse(outcome),
)
```

### onHedging

Callback invoked when a hedged attempt is started.

**Type:** `OnHedgingCallback<T>?`  
**Default:** `null`

```dart
HedgingStrategyOptions(
  onHedging: (context, args) {
    logger.debug('Started hedged attempt ${args.attemptNumber}');
  },
)
```

## Callback Types

### ShouldHandlePredicate&lt;T&gt;

```dart
typedef ShouldHandlePredicate<T> = bool Function(Outcome<T> outcome);
```

Determines whether hedging should be triggered for a given outcome.

### OnHedgingCallback&lt;T&gt;

```dart
typedef OnHedgingCallback<T> = void Function(
  ResilienceContext context,
  OnHedgingArgs args,
);
```

Called when a hedged attempt is started.

**OnHedgingArgs Properties:**
- `attemptNumber` - The number of the hedged attempt (1, 2, 3...)
- `delay` - The delay that was applied before starting this attempt

## Usage Examples

### Basic Hedging

```dart
final hedgingStrategy = HedgingStrategy(HedgingStrategyOptions(
  maxHedgedAttempts: 2,
  delay: Duration(milliseconds: 100),
));

final pipeline = ResiliencePipelineBuilder()
    .addStrategy(hedgingStrategy)
    .build();
```

### Aggressive Hedging for Low Latency

```dart
final hedgingStrategy = HedgingStrategy(HedgingStrategyOptions(
  maxHedgedAttempts: 3,
  delay: Duration(milliseconds: 50), // Quick hedging
));

// Use for time-critical operations
final result = await pipeline.execute((context) async {
  return await criticalApiCall();
});
```

### Conservative Hedging

```dart
final hedgingStrategy = HedgingStrategy(HedgingStrategyOptions(
  maxHedgedAttempts: 1,
  delay: Duration(milliseconds: 200), // Wait longer before hedging
));
```

### Conditional Hedging

```dart
final hedgingStrategy = HedgingStrategy(HedgingStrategyOptions(
  maxHedgedAttempts: 2,
  delay: Duration(milliseconds: 100),
  shouldHandle: (outcome) {
    // Only hedge if the primary request is taking too long
    // (This would need custom logic to track timing)
    return true; // Simplified example
  },
));
```

### Hedging with Monitoring

```dart
final hedgingStrategy = HedgingStrategy(HedgingStrategyOptions(
  maxHedgedAttempts: 2,
  delay: Duration(milliseconds: 75),
  onHedging: (context, args) {
    final operation = context.getProperty<String>('operation') ?? 'unknown';
    logger.debug('Hedging attempt ${args.attemptNumber} for $operation');
    
    // Track hedging metrics
    metrics.incrementCounter('hedging_attempts', {
      'operation': operation,
      'attempt': args.attemptNumber.toString(),
    });
  },
));
```

### Database Query Hedging

```dart
final dbHedgingStrategy = HedgingStrategy(HedgingStrategyOptions(
  maxHedgedAttempts: 1, // Conservative for databases
  delay: Duration(milliseconds: 200), // Allow time for primary query
  onHedging: (context, args) {
    final query = context.getProperty<String>('query');
    logger.warn('Database query is slow, starting hedged attempt: $query');
  },
));

final dbPipeline = ResiliencePipelineBuilder()
    .addStrategy(dbHedgingStrategy)
    .build();

// Usage with context
final context = ResilienceContext();
context.setProperty('query', 'SELECT * FROM users WHERE active = true');

final users = await dbPipeline.execute(
  (context) => database.query(query),
  context: context,
);
```

### HTTP Request Hedging

```dart
final httpHedgingStrategy = HedgingStrategy(HedgingStrategyOptions(
  maxHedgedAttempts: 2,
  delay: Duration(milliseconds: 100),
  onHedging: (context, args) {
    final url = context.getProperty<String>('url');
    logger.info('HTTP request hedging started for $url');
  },
));

final httpPipeline = ResiliencePipelineBuilder()
    .addStrategy(httpHedgingStrategy)
    .addTimeout(Duration(seconds: 5)) // Per-attempt timeout
    .build();

// Usage
final context = ResilienceContext();
context.setProperty('url', 'https://api.example.com/data');

final response = await httpPipeline.execute(
  (context) => httpClient.get('https://api.example.com/data'),
  context: context,
);
```

### Microservice Call Hedging

```dart
final serviceHedgingStrategy = HedgingStrategy(HedgingStrategyOptions(
  maxHedgedAttempts: 2,
  delay: Duration(milliseconds: 150),
  onHedging: (context, args) {
    final service = context.getProperty<String>('serviceName');
    final method = context.getProperty<String>('method');
    
    logger.info('Hedging $service.$method (attempt ${args.attemptNumber})');
    
    // Track which services need hedging most
    serviceMetrics.recordHedging(service, method);
  },
));

// Different hedging for different service types
final criticalServicePipeline = ResiliencePipelineBuilder()
    .addStrategy(HedgingStrategy(HedgingStrategyOptions(
      maxHedgedAttempts: 3, // More aggressive for critical services
      delay: Duration(milliseconds: 50),
    )))
    .build();

final normalServicePipeline = ResiliencePipelineBuilder()
    .addStrategy(HedgingStrategy(HedgingStrategyOptions(
      maxHedgedAttempts: 1, // Conservative for normal services
      delay: Duration(milliseconds: 200),
    )))
    .build();
```

### File Download Hedging

```dart
final downloadHedgingStrategy = HedgingStrategy(HedgingStrategyOptions(
  maxHedgedAttempts: 2,
  delay: Duration(seconds: 1), // Longer delay for downloads
  onHedging: (context, args) {
    final fileName = context.getProperty<String>('fileName');
    final fileSize = context.getProperty<int>('fileSize');
    
    logger.info('Download hedging: $fileName (${fileSize} bytes)');
  },
));

final downloadPipeline = ResiliencePipelineBuilder()
    .addStrategy(downloadHedgingStrategy)
    .addTimeout(Duration(minutes: 5)) // Long timeout for downloads
    .build();
```

### Search Query Hedging

```dart
final searchHedgingStrategy = HedgingStrategy(HedgingStrategyOptions(
  maxHedgedAttempts: 2,
  delay: Duration(milliseconds: 100),
  onHedging: (context, args) {
    final query = context.getProperty<String>('searchQuery');
    logger.debug('Search hedging: "$query" (attempt ${args.attemptNumber})');
  },
));

final searchPipeline = ResiliencePipelineBuilder()
    .addStrategy(searchHedgingStrategy)
    .addTimeout(Duration(seconds: 3))
    .build();

// Usage
final results = await searchPipeline.execute((context) async {
  context.setProperty('searchQuery', userQuery);
  return await searchService.search(userQuery);
});
```

### Hedging with Circuit Breaker

```dart
final pipeline = ResiliencePipelineBuilder()
    .addHedging(HedgingStrategyOptions(
      maxHedgedAttempts: 2,
      delay: Duration(milliseconds: 100),
    ))
    .addCircuitBreaker(CircuitBreakerStrategyOptions(
      failureRatio: 0.5,
      minimumThroughput: 10,
    ))
    .build();
```

### Load Balancer Simulation with Hedging

```dart
final hedgingStrategy = HedgingStrategy(HedgingStrategyOptions(
  maxHedgedAttempts: 2,
  delay: Duration(milliseconds: 100),
  onHedging: (context, args) {
    // Could implement server selection logic here
    final servers = context.getProperty<List<String>>('availableServers');
    final selectedServer = selectNextServer(servers, args.attemptNumber);
    context.setProperty('currentServer', selectedServer);
    
    logger.debug('Hedging to server: $selectedServer');
  },
));
```

## Best Practices

### Choose Appropriate Delays

```dart
// Fast operations - short delay
HedgingStrategyOptions(
  delay: Duration(milliseconds: 50),
  maxHedgedAttempts: 2,
)

// Network calls - medium delay
HedgingStrategyOptions(
  delay: Duration(milliseconds: 100),
  maxHedgedAttempts: 2,
)

// Heavy operations - longer delay
HedgingStrategyOptions(
  delay: Duration(milliseconds: 500),
  maxHedgedAttempts: 1,
)
```

### Limit Hedged Attempts

```dart
// Good - reasonable number of attempts
HedgingStrategyOptions(maxHedgedAttempts: 2) // Total: 3 attempts

// Avoid - too many attempts can overwhelm services
HedgingStrategyOptions(maxHedgedAttempts: 10) // Total: 11 attempts
```

### Monitor Hedging Effectiveness

```dart
HedgingStrategyOptions(
  onHedging: (context, args) {
    final startTime = context.getProperty<DateTime>('requestStart');
    final hedgingTime = DateTime.now().difference(startTime!);
    
    // Track how long it takes before hedging kicks in
    metrics.recordHistogram('hedging_trigger_time', hedgingTime.inMilliseconds);
    
    // Track hedging frequency
    metrics.incrementCounter('hedging_triggered');
  },
)
```

### Use with Timeouts

```dart
// Each attempt should have its own timeout
final pipeline = ResiliencePipelineBuilder()
    .addHedging(HedgingStrategyOptions(
      maxHedgedAttempts: 2,
      delay: Duration(milliseconds: 100),
    ))
    .addTimeout(Duration(seconds: 5)) // Timeout per attempt
    .build();
```

### Consider Resource Usage

```dart
// For expensive operations, use conservative hedging
HedgingStrategyOptions(
  maxHedgedAttempts: 1, // Only one extra attempt
  delay: Duration(milliseconds: 500), // Wait longer before hedging
)

// For cheap operations, can be more aggressive
HedgingStrategyOptions(
  maxHedgedAttempts: 3, // Multiple extra attempts
  delay: Duration(milliseconds: 50), // Hedge quickly
)
```

### Handle Cancellation Properly

```dart
// Ensure your operations respect cancellation tokens
Future<String> apiCall(CancellationToken cancellationToken) async {
  // Check cancellation before expensive operations
  cancellationToken.throwIfCancellationRequested();
  
  final response = await httpClient.get('/api/data');
  
  // Check cancellation before processing
  cancellationToken.throwIfCancellationRequested();
  
  return processResponse(response);
}
```

### Test Hedging Scenarios

```dart
test('should return first successful hedged result', () async {
  // Test that hedging works correctly
  when(mockService.call(any))
    .thenAnswer((_) async {
      await Future.delayed(Duration(seconds: 1)); // Slow primary
      return 'primary-result';
    });
  
  when(mockService.call(any))
    .thenAnswer((_) async => 'hedged-result'); // Fast hedged attempt
  
  final result = await pipeline.execute((context) => mockService.call());
  
  expect(result, equals('hedged-result')); // Should get the faster result
});
```
