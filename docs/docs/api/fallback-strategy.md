---
sidebar_position: 8
---

# FallbackStrategy

The `FallbackStrategy` provides alternative responses when operations fail, ensuring graceful degradation and improved user experience.

## Overview

The fallback strategy executes alternative logic when the primary operation fails. This enables graceful degradation by providing cached data, default values, or alternative service responses.

```dart
class FallbackStrategy<T> extends ResilienceStrategy<T> {
  FallbackStrategy(FallbackStrategyOptions<T> options);
  
  Future<Outcome<T>> executeCore<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
    ResilienceCallback<T> next,
  );
}

class FallbackStrategyOptions<T> {
  const FallbackStrategyOptions({
    required this.fallbackAction,
    this.shouldHandle,
    this.onFallback,
  });
}
```

## FallbackStrategyOptions Properties

### fallbackAction

The action to execute when the primary operation fails.

**Type:** `FallbackAction<T>`  
**Required:** Yes

```dart
FallbackStrategyOptions<String>(
  fallbackAction: (context, args) async => 'fallback-value',
)
```

### shouldHandle

Predicate to determine which outcomes should trigger the fallback.

**Type:** `ShouldHandlePredicate<T>?`  
**Default:** `null` (handles all exceptions)

```dart
FallbackStrategyOptions<String>(
  shouldHandle: (outcome) => 
    outcome.hasException && 
    outcome.exception is SocketException,
  fallbackAction: (context, args) async => 'offline-mode',
)
```

### onFallback

Callback invoked when the fallback action is executed.

**Type:** `OnFallbackCallback<T>?`  
**Default:** `null`

```dart
FallbackStrategyOptions<String>(
  fallbackAction: (context, args) async => 'fallback',
  onFallback: (context, args) {
    logger.info('Fallback executed due to: ${args.outcome.exception}');
  },
)
```

## Callback Types

### FallbackAction&lt;T&gt;

```dart
typedef FallbackAction<T> = Future<T> Function(
  ResilienceContext context,
  FallbackActionArgs<T> args,
);
```

Defines the fallback logic to execute when the primary operation fails.

**FallbackActionArgs Properties:**
- `outcome` - The failed outcome that triggered the fallback
- `cancellationToken` - Token for cancellation support

### ShouldHandlePredicate&lt;T&gt;

```dart
typedef ShouldHandlePredicate<T> = bool Function(Outcome<T> outcome);
```

Determines whether an outcome should trigger the fallback action.

### OnFallbackCallback&lt;T&gt;

```dart
typedef OnFallbackCallback<T> = void Function(
  ResilienceContext context,
  OnFallbackArgs<T> args,
);
```

Called when the fallback action is executed.

**OnFallbackArgs Properties:**
- `outcome` - The failed outcome that triggered the fallback

## Usage Examples

### Basic Fallback

```dart
final fallbackStrategy = FallbackStrategy(FallbackStrategyOptions<String>(
  fallbackAction: (context, args) async => 'Service temporarily unavailable',
));

final pipeline = ResiliencePipelineBuilder()
    .addStrategy(fallbackStrategy)
    .build();
```

### Cached Data Fallback

```dart
final fallbackStrategy = FallbackStrategy(FallbackStrategyOptions<UserData>(
  shouldHandle: (outcome) => outcome.hasException,
  fallbackAction: (context, args) async {
    final userId = context.getProperty<String>('userId');
    final cachedData = await cache.get('user_$userId');
    
    if (cachedData != null) {
      return UserData.fromJson(cachedData);
    }
    
    // Return default user data if no cache
    return UserData.defaultUser();
  },
  onFallback: (context, args) {
    logger.info('Using cached user data due to service failure');
  },
));
```

### Network Fallback to Local Storage

```dart
final fallbackStrategy = FallbackStrategy(FallbackStrategyOptions<List<Article>>(
  shouldHandle: (outcome) {
    if (!outcome.hasException) return false;
    
    final exception = outcome.exception;
    return exception is SocketException || 
           exception is TimeoutException ||
           (exception is HttpException && exception.statusCode >= 500);
  },
  fallbackAction: (context, args) async {
    logger.warn('Network failed, loading from local storage');
    return await localStorage.getArticles();
  },
  onFallback: (context, args) {
    metrics.incrementCounter('fallback_to_local_storage');
  },
));
```

### Multi-Level Fallback

```dart
final fallbackStrategy = FallbackStrategy(FallbackStrategyOptions<String>(
  fallbackAction: (context, args) async {
    // Try secondary service first
    try {
      return await secondaryService.getData();
    } catch (e) {
      logger.warn('Secondary service also failed, using cache');
      
      // Fall back to cache
      final cached = await cache.get('data');
      if (cached != null) {
        return cached;
      }
      
      // Final fallback to default value
      return 'Default data - all services unavailable';
    }
  },
  onFallback: (context, args) {
    final primaryError = args.outcome.exception;
    logger.error('Primary service failed: $primaryError');
  },
));
```

### Conditional Fallback

```dart
final fallbackStrategy = FallbackStrategy(FallbackStrategyOptions<PaymentResult>(
  shouldHandle: (outcome) {
    if (!outcome.hasException) return false;
    
    final exception = outcome.exception;
    
    // Only fallback for network issues, not validation errors
    return exception is SocketException || 
           exception is TimeoutException;
  },
  fallbackAction: (context, args) async {
    // Queue payment for later processing
    final paymentData = context.getProperty<PaymentData>('paymentData');
    await paymentQueue.add(paymentData);
    
    return PaymentResult.queued('Payment queued for processing');
  },
  onFallback: (context, args) {
    logger.info('Payment queued due to network issues');
    notificationService.notifyUser('Payment will be processed shortly');
  },
));
```

### Degraded Service Fallback

```dart
final fallbackStrategy = FallbackStrategy(FallbackStrategyOptions<SearchResults>(
  fallbackAction: (context, args) async {
    final query = context.getProperty<String>('searchQuery');
    
    // Use simpler search algorithm as fallback
    final results = await simplifiedSearch.search(query);
    
    return SearchResults(
      items: results,
      isLimitedResults: true,
      message: 'Limited search results due to service issues',
    );
  },
  onFallback: (context, args) {
    logger.warn('Using degraded search service');
    metrics.incrementCounter('degraded_search_fallback');
  },
));
```

### Fallback with User Context

```dart
final fallbackStrategy = FallbackStrategy(FallbackStrategyOptions<Recommendations>(
  fallbackAction: (context, args) async {
    final userId = context.getProperty<String>('userId');
    final userPreferences = context.getProperty<UserPreferences>('preferences');
    
    // Generate generic recommendations based on user preferences
    return await generateGenericRecommendations(userPreferences);
  },
  onFallback: (context, args) {
    final userId = context.getProperty<String>('userId');
    logger.info('Providing generic recommendations for user $userId');
  },
));

// Usage with context
final context = ResilienceContext();
context.setProperty('userId', 'user123');
context.setProperty('preferences', userPreferences);

final recommendations = await pipeline.execute(
  (context) => recommendationService.getPersonalizedRecommendations(userId),
  context: context,
);
```

### Error-Specific Fallbacks

```dart
final fallbackStrategy = FallbackStrategy(FallbackStrategyOptions<ApiResponse>(
  fallbackAction: (context, args) async {
    final exception = args.outcome.exception;
    
    if (exception is TimeoutException) {
      return ApiResponse.timeout('Request timed out, please try again');
    }
    
    if (exception is HttpException) {
      switch (exception.statusCode) {
        case 404:
          return ApiResponse.notFound('Resource not found');
        case 429:
          return ApiResponse.rateLimited('Too many requests, please wait');
        case 503:
          return ApiResponse.serviceUnavailable('Service temporarily unavailable');
        default:
          return ApiResponse.error('Service error occurred');
      }
    }
    
    return ApiResponse.error('An unexpected error occurred');
  },
  onFallback: (context, args) {
    final exception = args.outcome.exception;
    logger.warn('API fallback triggered by: ${exception.runtimeType}');
  },
));
```

### Circuit Breaker with Fallback

```dart
final pipeline = ResiliencePipelineBuilder()
    .addCircuitBreaker(CircuitBreakerStrategyOptions(
      failureRatio: 0.5,
      minimumThroughput: 10,
    ))
    .addFallback(FallbackStrategyOptions<String>(
      shouldHandle: (outcome) => 
        outcome.hasException && 
        outcome.exception is CircuitBreakerOpenException,
      fallbackAction: (context, args) async {
        return 'Service is currently experiencing issues. Please try again later.';
      },
      onFallback: (context, args) {
        logger.warn('Circuit breaker is open, using fallback response');
      },
    ))
    .build();
```

### Retry with Fallback

```dart
final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 3))
    .addFallback(FallbackStrategyOptions<String>(
      fallbackAction: (context, args) async {
        logger.error('All retry attempts failed, using fallback');
        return await getFromBackupService();
      },
    ))
    .build();
```

## Best Practices

### Provide Meaningful Fallbacks

```dart
// Good - Provides actual value
FallbackStrategyOptions<UserProfile>(
  fallbackAction: (context, args) async {
    return UserProfile.guest(); // Actual usable profile
  },
)

// Avoid - Just returns error message
FallbackStrategyOptions<UserProfile>(
  fallbackAction: (context, args) async {
    throw Exception('Service unavailable'); // Not helpful
  },
)
```

### Use Context for Personalized Fallbacks

```dart
FallbackStrategyOptions<String>(
  fallbackAction: (context, args) async {
    final userLevel = context.getProperty<String>('userLevel');
    final locale = context.getProperty<String>('locale');
    
    return getLocalizedFallbackMessage(locale, userLevel);
  },
)
```

### Handle Fallback Failures

```dart
FallbackStrategyOptions<String>(
  fallbackAction: (context, args) async {
    try {
      return await backupService.getData();
    } catch (e) {
      // Even fallback can fail - provide ultimate fallback
      logger.error('Backup service also failed: $e');
      return 'System temporarily unavailable';
    }
  },
)
```

### Monitor Fallback Usage

```dart
FallbackStrategyOptions<String>(
  onFallback: (context, args) {
    final operation = context.getProperty<String>('operation');
    final exception = args.outcome.exception;
    
    // Track fallback metrics
    metrics.incrementCounter('fallback_executed', {
      'operation': operation,
      'exception_type': exception.runtimeType.toString(),
    });
    
    // Alert if fallbacks are frequent
    if (fallbackRateExceeded(operation)) {
      alertService.sendAlert('High fallback rate for $operation');
    }
  },
)
```

### Keep Fallbacks Simple

```dart
// Good - Simple and fast
FallbackStrategyOptions<List<Item>>(
  fallbackAction: (context, args) async => <Item>[],
)

// Avoid - Complex fallback that might also fail
FallbackStrategyOptions<List<Item>>(
  fallbackAction: (context, args) async {
    // Complex logic that might introduce new failure points
    return await complexFallbackLogic();
  },
)
```

### Test Fallback Scenarios

```dart
// Ensure fallbacks are tested
test('should use cached data when service fails', () async {
  // Arrange
  when(mockService.getData()).thenThrow(SocketException('Network error'));
  when(mockCache.get('data')).thenReturn('cached-data');
  
  // Act
  final result = await pipeline.execute((context) => mockService.getData());
  
  // Assert
  expect(result, equals('cached-data'));
});
```
