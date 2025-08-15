---
sidebar_position: 5
---

# Fallback Strategy

The **Fallback Strategy** provides alternative responses when primary operations fail, enabling graceful degradation instead of complete failure. It's your safety net for maintaining user experience even when services are unavailable.

## When to Use Fallback

Fallback is perfect for:

- 🎯 **Graceful degradation** when services are temporarily unavailable
- 💾 **Cached responses** when fresh data can't be retrieved
- 🔧 **Default values** when configuration services fail
- 📱 **Offline functionality** in mobile applications
- 🎨 **Placeholder content** when content services are down
- 🛡️ **Last resort responses** when all other strategies fail

:::tip Perfect as the Last Strategy
Fallback works excellently as the final strategy in a pipeline, catching any failures that other strategies couldn't handle.
:::

## Basic Usage

### Simple Fallback with Value
```dart
import 'package:polly_dart/polly_dart.dart';

final pipeline = ResiliencePipelineBuilder()
    .addFallback(FallbackStrategyOptions.withValue('Default response'))
    .build();

final result = await pipeline.execute((context) async {
  // This might fail
  return await riskyOperation();
});
// If riskyOperation() fails, returns 'Default response'
```

### Fallback with Custom Action
```dart
final pipeline = ResiliencePipelineBuilder()
    .addFallback(FallbackStrategyOptions(
      fallbackAction: (args) async {
        // Custom fallback logic
        return Outcome.fromResult(await getCachedData());
      },
    ))
    .build();
```

## Configuration Options

### FallbackStrategyOptions

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `fallbackAction` | `FallbackAction<T>` | Required | Function to execute when fallback is triggered |
| `shouldHandle` | `ShouldHandlePredicate<T>?` | `null` | Predicate to determine which failures trigger fallback |
| `onFallback` | `OnFallbackCallback<T>?` | `null` | Callback invoked when fallback is activated |

### Type Definitions

```dart
typedef FallbackAction<T> = Future<Outcome<T>> Function(FallbackActionArguments<T> args);
typedef OnFallbackCallback<T> = Future<void> Function(OnFallbackArguments<T> args);
```

## Fallback Patterns

### Static Value Fallback
Perfect for configuration values or default responses:

```dart
final configPipeline = ResiliencePipelineBuilder()
    .addFallback(FallbackStrategyOptions.withValue({
      'theme': 'light',
      'timeout': 30,
      'retries': 3,
    }))
    .build();

final config = await configPipeline.execute((context) async {
  return await configService.getConfiguration();
});
```

### Cached Data Fallback
Return cached data when live services are unavailable:

```dart
final apiPipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 2))
    .addFallback(FallbackStrategyOptions(
      fallbackAction: (args) async {
        final cachedData = await cache.get('user_data');
        if (cachedData != null) {
          return Outcome.fromResult(cachedData);
        }
        // No cached data available
        throw FallbackException('No cached data available');
      },
      onFallback: (args) async {
        logger.info('Using cached data due to service failure');
      },
    ))
    .build();
```

### Computed Fallback
Generate fallback responses based on the failure:

```dart
final smartFallbackPipeline = ResiliencePipelineBuilder()
    .addFallback(FallbackStrategyOptions(
      fallbackAction: (args) async {
        final exception = args.outcome.exception;
        
        if (exception is TimeoutException) {
          // For timeouts, return partial data
          return Outcome.fromResult(await getPartialData());
        } else if (exception is HttpException) {
          // For HTTP errors, return error-specific response
          return Outcome.fromResult(createErrorResponse(exception));
        } else {
          // For other failures, return generic fallback
          return Outcome.fromResult(getDefaultResponse());
        }
      },
    ))
    .build();
```

### Conditional Fallback
Only trigger fallback for specific types of failures:

```dart
final selectiveFallbackPipeline = ResiliencePipelineBuilder()
    .addFallback(FallbackStrategyOptions(
      shouldHandle: (outcome) {
        if (!outcome.hasException) return false;
        
        final exception = outcome.exception;
        
        // Only fallback for service unavailability, not client errors
        return exception is SocketException ||
               exception is TimeoutException ||
               (exception is HttpException && 
                exception.message.contains('503'));
      },
      fallbackAction: (args) async {
        return Outcome.fromResult(await getServiceUnavailableResponse());
      },
    ))
    .build();
```

## Advanced Fallback Patterns

### Tiered Fallback System
Multiple layers of fallback responses:

```dart
class TieredFallbackService {
  final Cache _cache;
  final LocalStorage _localStorage;
  
  TieredFallbackService(this._cache, this._localStorage);

  Future<UserProfile> getUserProfile(int userId) async {
    final pipeline = ResiliencePipelineBuilder()
        .addRetry(RetryStrategyOptions(maxRetryAttempts: 2))
        .addFallback(FallbackStrategyOptions(
          fallbackAction: (args) => _getTieredFallback(userId),
        ))
        .build();

    return await pipeline.execute((context) async {
      return await apiService.getUserProfile(userId);
    });
  }

  Future<Outcome<UserProfile>> _getTieredFallback(int userId) async {
    // Tier 1: Try cache
    final cached = await _cache.get('user_$userId');
    if (cached != null) {
      logger.info('Using cached user profile for user $userId');
      return Outcome.fromResult(UserProfile.fromJson(cached));
    }

    // Tier 2: Try local storage
    final stored = await _localStorage.get('user_$userId');
    if (stored != null) {
      logger.info('Using stored user profile for user $userId');
      return Outcome.fromResult(UserProfile.fromJson(stored));
    }

    // Tier 3: Generate minimal profile
    logger.warning('Generating minimal user profile for user $userId');
    return Outcome.fromResult(UserProfile.minimal(userId));
  }
}
```

### Context-Aware Fallback
Fallback responses that consider execution context:

```dart
final contextAwarePipeline = ResiliencePipelineBuilder()
    .addFallback(FallbackStrategyOptions(
      fallbackAction: (args) async {
        final context = args.context;
        final userId = context.getProperty<int>('userId');
        final requestType = context.getProperty<String>('requestType');
        
        switch (requestType) {
          case 'profile':
            return Outcome.fromResult(await getFallbackProfile(userId!));
          case 'preferences':
            return Outcome.fromResult(await getDefaultPreferences());
          case 'notifications':
            return Outcome.fromResult(<Notification>[]);
          default:
            throw FallbackException('No fallback available for $requestType');
        }
      },
    ))
    .build();

// Usage with context
final context = ResilienceContext();
context.setProperty('userId', 123);
context.setProperty('requestType', 'profile');

final profile = await contextAwarePipeline.execute((ctx) async {
  return await userService.getProfile(123);
}, context: context);
```

### Fallback with State Validation
Ensure fallback data meets quality requirements:

```dart
final validatedFallbackPipeline = ResiliencePipelineBuilder()
    .addFallback(FallbackStrategyOptions(
      fallbackAction: (args) async {
        final fallbackData = await getCachedData();
        
        // Validate fallback data quality
        if (fallbackData != null && isDataFresh(fallbackData)) {
          logger.info('Using fresh cached data');
          return Outcome.fromResult(fallbackData);
        } else if (fallbackData != null && isDataUsable(fallbackData)) {
          logger.warning('Using stale cached data');
          return Outcome.fromResult(markAsStale(fallbackData));
        } else {
          logger.error('Cached data unusable, using default');
          return Outcome.fromResult(getDefaultData());
        }
      },
    ))
    .build();

bool isDataFresh(dynamic data) {
  if (data is Map && data['timestamp'] != null) {
    final timestamp = DateTime.parse(data['timestamp']);
    return DateTime.now().difference(timestamp).inMinutes < 5;
  }
  return false;
}

bool isDataUsable(dynamic data) {
  if (data is Map && data['timestamp'] != null) {
    final timestamp = DateTime.parse(data['timestamp']);
    return DateTime.now().difference(timestamp).inHours < 24;
  }
  return false;
}
```

## Real-World Examples

### E-commerce Product Service
```dart
class ProductService {
  final ApiClient _apiClient;
  final ProductCache _cache;
  final RecommendationEngine _recommendations;

  ProductService(this._apiClient, this._cache, this._recommendations);

  late final ResiliencePipeline _pipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions(maxRetryAttempts: 2))
      .addCircuitBreaker(CircuitBreakerStrategyOptions(
        failureRatio: 0.5,
        breakDuration: Duration(seconds: 30),
      ))
      .addFallback(FallbackStrategyOptions(
        fallbackAction: _getProductFallback,
        onFallback: _onProductFallback,
      ))
      .build();

  Future<Product> getProduct(int productId) async {
    final context = ResilienceContext(operationKey: 'get-product');
    context.setProperty('productId', productId);

    return await _pipeline.execute((ctx) async {
      return await _apiClient.getProduct(productId);
    }, context: context);
  }

  Future<List<Product>> getRecommendations(int userId) async {
    final context = ResilienceContext(operationKey: 'get-recommendations');
    context.setProperty('userId', userId);

    return await _pipeline.execute((ctx) async {
      return await _apiClient.getRecommendations(userId);
    }, context: context);
  }

  Future<Outcome<dynamic>> _getProductFallback(FallbackActionArguments args) async {
    final operationKey = args.context.operationKey;
    
    switch (operationKey) {
      case 'get-product':
        return await _handleProductFallback(args);
      case 'get-recommendations':
        return await _handleRecommendationsFallback(args);
      default:
        throw FallbackException('Unknown operation: $operationKey');
    }
  }

  Future<Outcome<Product>> _handleProductFallback(FallbackActionArguments args) async {
    final productId = args.context.getProperty<int>('productId')!;
    
    // Try cache first
    final cachedProduct = await _cache.getProduct(productId);
    if (cachedProduct != null) {
      logger.info('Returning cached product $productId');
      return Outcome.fromResult(cachedProduct.markAsCached());
    }

    // Generate placeholder product
    logger.warning('Generating placeholder for product $productId');
    return Outcome.fromResult(Product.placeholder(
      id: productId,
      name: 'Product $productId',
      description: 'Product information temporarily unavailable',
      price: 0.0,
      available: false,
    ));
  }

  Future<Outcome<List<Product>>> _handleRecommendationsFallback(
    FallbackActionArguments args,
  ) async {
    final userId = args.context.getProperty<int>('userId')!;
    
    // Try local recommendation engine
    try {
      final localRecommendations = await _recommendations.getLocalRecommendations(userId);
      if (localRecommendations.isNotEmpty) {
        logger.info('Using local recommendations for user $userId');
        return Outcome.fromResult(localRecommendations);
      }
    } catch (e) {
      logger.warning('Local recommendations failed: $e');
    }

    // Return popular products
    final popularProducts = await _cache.getPopularProducts();
    logger.info('Using popular products as fallback recommendations');
    return Outcome.fromResult(popularProducts);
  }

  Future<void> _onProductFallback(OnFallbackArguments args) async {
    final operationKey = args.context.operationKey;
    
    // Emit metrics
    metrics.incrementCounter('product_service_fallback', tags: {
      'operation': operationKey ?? 'unknown',
      'exception_type': args.outcome.exception.runtimeType.toString(),
    });

    // Log for analysis
    logger.warning(
      'Product service fallback activated for $operationKey: ${args.outcome.exception}',
    );
  }
}
```

### News Feed with Graceful Degradation
```dart
class NewsFeedService {
  final NewsApiClient _newsApi;
  final FeedCache _cache;
  final UserPreferences _preferences;

  NewsFeedService(this._newsApi, this._cache, this._preferences);

  late final ResiliencePipeline _pipeline = ResiliencePipelineBuilder()
      .addTimeout(Duration(seconds: 10))
      .addRetry(RetryStrategyOptions(maxRetryAttempts: 2))
      .addFallback(FallbackStrategyOptions(
        fallbackAction: _generateFallbackFeed,
        shouldHandle: (outcome) => outcome.hasException,
      ))
      .build();

  Future<NewsFeed> getFeed(int userId) async {
    final context = ResilienceContext(operationKey: 'get-news-feed');
    context.setProperty('userId', userId);

    return await _pipeline.execute((ctx) async {
      final preferences = await _preferences.get(userId);
      return await _newsApi.getPersonalizedFeed(userId, preferences);
    }, context: context);
  }

  Future<Outcome<NewsFeed>> _generateFallbackFeed(FallbackActionArguments args) async {
    final userId = args.context.getProperty<int>('userId')!;
    
    // Try cached personalized feed first
    var cachedFeed = await _cache.getPersonalizedFeed(userId);
    if (cachedFeed != null && cachedFeed.isRecentEnough()) {
      logger.info('Using cached personalized feed for user $userId');
      return Outcome.fromResult(cachedFeed.markAsCached());
    }

    // Try cached general feed
    cachedFeed = await _cache.getGeneralFeed();
    if (cachedFeed != null) {
      logger.info('Using cached general feed for user $userId');
      return Outcome.fromResult(cachedFeed.markAsGeneral());
    }

    // Generate minimal feed
    logger.warning('Generating minimal feed for user $userId');
    final minimalFeed = NewsFeed(
      articles: [
        Article.serviceMessage(
          title: 'News Service Temporarily Unavailable',
          content: 'We\'re experiencing technical difficulties. Please try again later.',
        ),
      ],
      isPersonalized: false,
      isCached: false,
      timestamp: DateTime.now(),
    );

    return Outcome.fromResult(minimalFeed);
  }
}
```

### Configuration Service with Defaults
```dart
class ConfigurationService {
  final ConfigApiClient _configApi;
  final Map<String, dynamic> _defaultConfig;

  ConfigurationService(this._configApi, this._defaultConfig);

  late final ResiliencePipeline _pipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions(maxRetryAttempts: 2))
      .addFallback(FallbackStrategyOptions(
        fallbackAction: (args) async {
          final configKey = args.context.getProperty<String>('configKey');
          
          if (configKey != null && _defaultConfig.containsKey(configKey)) {
            logger.info('Using default value for config key: $configKey');
            return Outcome.fromResult(_defaultConfig[configKey]);
          }
          
          logger.info('Using complete default configuration');
          return Outcome.fromResult(_defaultConfig);
        },
        onFallback: (args) async {
          final configKey = args.context.getProperty<String>('configKey');
          logger.warning('Config service fallback for key: $configKey');
        },
      ))
      .build();

  Future<T> get<T>(String key) async {
    final context = ResilienceContext(operationKey: 'get-config');
    context.setProperty('configKey', key);

    return await _pipeline.execute((ctx) async {
      return await _configApi.getValue<T>(key);
    }, context: context);
  }

  Future<Map<String, dynamic>> getAll() async {
    return await _pipeline.execute((context) async {
      return await _configApi.getAllValues();
    });
  }
}
```

## Testing Fallback Strategies

### Unit Testing Fallback Activation
```dart
import 'package:test/test.dart';
import 'package:polly_dart/polly_dart.dart';

void main() {
  group('Fallback Strategy Tests', () {
    test('should activate fallback on exception', () async {
      final pipeline = ResiliencePipelineBuilder()
          .addFallback(FallbackStrategyOptions.withValue('fallback'))
          .build();

      final result = await pipeline.execute((context) async {
        throw Exception('Primary operation failed');
      });

      expect(result, equals('fallback'));
    });

    test('should not activate fallback on success', () async {
      final pipeline = ResiliencePipelineBuilder()
          .addFallback(FallbackStrategyOptions.withValue('fallback'))
          .build();

      final result = await pipeline.execute((context) async {
        return 'success';
      });

      expect(result, equals('success'));
    });

    test('should respect shouldHandle predicate', () async {
      final pipeline = ResiliencePipelineBuilder()
          .addFallback(FallbackStrategyOptions(
            shouldHandle: (outcome) => 
                outcome.hasException && 
                outcome.exception.toString().contains('retryable'),
            fallbackAction: (args) => 
                Future.value(Outcome.fromResult('fallback')),
          ))
          .build();

      // Should not activate fallback for non-retryable exception
      expect(
        () => pipeline.execute((context) async {
          throw Exception('non-retryable error');
        }),
        throwsA(isA<Exception>()),
      );

      // Should activate fallback for retryable exception
      final result = await pipeline.execute((context) async {
        throw Exception('retryable error');
      });
      expect(result, equals('fallback'));
    });

    test('should call onFallback callback', () async {
      var fallbackCalled = false;
      final pipeline = ResiliencePipelineBuilder()
          .addFallback(FallbackStrategyOptions(
            fallbackAction: (args) => 
                Future.value(Outcome.fromResult('fallback')),
            onFallback: (args) async {
              fallbackCalled = true;
            },
          ))
          .build();

      await pipeline.execute((context) async {
        throw Exception('fail');
      });

      expect(fallbackCalled, isTrue);
    });
  });
}
```

## Best Practices

### ✅ Do

**Provide Meaningful Fallbacks**
```dart
// ✅ Good: Informative fallback
.addFallback(FallbackStrategyOptions.withValue(UserProfile(
  id: userId,
  name: 'User $userId',
  status: 'Profile temporarily unavailable',
  isPlaceholder: true,
)));
```

**Use Tiered Fallbacks**
```dart
// ✅ Good: Multiple fallback layers
Future<Outcome<Data>> fallbackAction(args) async {
  return await getCached() ?? 
         await getLocal() ?? 
         getDefault();
}
```

**Monitor Fallback Usage**
```dart
// ✅ Good: Track fallback patterns
.addFallback(FallbackStrategyOptions(
  onFallback: (args) async {
    metrics.incrementCounter('fallback_usage');
    logger.warning('Fallback activated: ${args.outcome.exception}');
  },
));
```

### ❌ Don't

**Return Null or Empty Fallbacks**
```dart
// ❌ Bad: Unhelpful fallback
.addFallback(FallbackStrategyOptions.withValue(null));
```

**Ignore Fallback Exceptions**
```dart
// ❌ Bad: Fallback that can fail
fallbackAction: (args) async {
  return await anotherRiskyOperation(); // Could also fail!
}
```

**Overuse Fallbacks**
```dart
// ❌ Bad: Masking real problems
.addFallback(FallbackStrategyOptions(
  shouldHandle: (outcome) => true, // Catches everything!
));
```

## Performance Considerations

- **Minimal Overhead**: Fallback only activates on failure
- **Memory Usage**: Keep fallback data lightweight
- **Cache Management**: Implement proper cache invalidation
- **Computation Cost**: Balance between computation and pre-computed fallbacks

## Common Patterns

### Repository Pattern with Fallback
```dart
abstract class Repository<T> {
  late final ResiliencePipeline _pipeline;
  
  Repository() {
    _pipeline = ResiliencePipelineBuilder()
        .addRetry()
        .addFallback(FallbackStrategyOptions(
          fallbackAction: getFallbackData,
        ))
        .build();
  }
  
  Future<Outcome<T>> getFallbackData(FallbackActionArguments args);
  
  Future<T> execute(Future<T> Function() operation) {
    return _pipeline.execute((context) => operation());
  }
}
```

## Next Steps

Fallback is often the final safety net in a resilience pipeline:

1. **[Learn Hedging Strategy](./hedging)** - Optimize for speed with parallel execution
2. **[Explore Rate Limiter](./rate-limiter)** - Control resource usage and concurrency
3. **[Combine Strategies](../advanced/combining-strategies)** - Build comprehensive resilience

Fallback ensures your application always provides value to users, even when everything else fails.
