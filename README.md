# Polly Dart

[![Pub Version](https://img.shields.io/pub/v/polly_dart.svg)](https://pub.dev/packages/polly_dart)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

A Dart port of [Polly](https://github.com/App-vNext/Polly), the .NET resilience and transient-fault-handling library. Polly Dart allows developers to express resilience strategies such as Retry, Circuit Breaker, Timeout, Rate Limiter, Hedging, and Fallback in a fluent and thread-safe manner.

## Documentation

📚 **[Complete Documentation](https://polly.anirudhsingh.in/)** - Comprehensive guides, API reference, and advanced usage patterns.

## Features

Polly Dart provides the following resilience strategies:

### Reactive Strategies
- **Retry**: Automatically retry failed operations with configurable backoff strategies
- **Circuit Breaker**: Prevent cascading failures by temporarily blocking calls to failing services  
- **Fallback**: Provide alternative responses when operations fail
- **Hedging**: Execute multiple parallel attempts and use the fastest successful response

### Proactive Strategies  
- **Timeout**: Cancel operations that take too long
- **Rate Limiter**: Control the rate of operations to prevent overload
- **Cache**: Store and reuse results of expensive operations to improve performance

## Quick Start

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  polly_dart: <latest>
```

### Basic Usage

```dart
import 'package:polly_dart/polly_dart.dart';

// Create a resilience pipeline
final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 3))
    .addTimeout(Duration(seconds: 10))
    .build();

// Execute with resilience
final result = await pipeline.execute((context) async {
  // Your code here
  return await someAsyncOperation();
});
```

## Examples

Check out the [example](example/polly_dart_example.dart) directory for comprehensive usage examples.

## Real-World Usage Scenarios

### Flutter Frontend Applications

Flutter apps often need resilience when calling APIs, loading images, or handling user interactions. Here are practical examples:

#### 1. API Client with Resilience

```dart
import 'package:polly_dart/polly_dart.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  static final _pipeline = ResiliencePipelineBuilder()
      // Retry transient HTTP errors
      .addRetry(RetryStrategyOptions<http.Response>(
        maxRetryAttempts: 3,
        delay: Duration(milliseconds: 500),
        backoffType: DelayBackoffType.exponential,
        shouldHandle: PredicateBuilder<http.Response>()
            .handleResultIf((response) => response.statusCode >= 500)
            .handleException<http.ClientException>()
            .build(),
        onRetry: (args) async {
          print('Retrying API call, attempt ${args.attemptNumber + 1}');
        },
      ))
      // Timeout for slow requests
      .addTimeout(Duration(seconds: 30))
      // Fallback to cached data
      .addFallback(FallbackStrategyOptions<http.Response>(
        fallbackAction: (args) async {
          // Return cached response or error response
          final cachedData = await getCachedResponse();
          return Outcome.fromResult(cachedData);
        },
        onFallback: (args) async {
          print('Using cached data due to API failure');
        },
      ))
      .build();

  static Future<Map<String, dynamic>> fetchUserData(String userId) async {
    final response = await _pipeline.execute((context) async {
      return await http.get(
        Uri.parse('https://api.example.com/users/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );
    });

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load user data');
    }
  }
}
```

#### 2. Image Loading with Circuit Breaker

```dart
class ImageService {
  static final _circuitBreaker = ResiliencePipelineBuilder()
      .addCircuitBreaker(CircuitBreakerStrategyOptions(
        failureRatio: 0.6,
        minimumThroughput: 5,
        samplingDuration: Duration(minutes: 1),
        breakDuration: Duration(seconds: 30),
        onOpened: (args) async {
          print('Image service circuit breaker opened - using placeholders');
        },
        onClosed: (args) async {
          print('Image service circuit breaker closed - service recovered');
        },
      ))
      .addTimeout(Duration(seconds: 10))
      .build();

  static Future<Widget> loadImage(String imageUrl) async {
    try {
      await _circuitBreaker.execute((context) async {
        // Simulate image loading
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode != 200) {
          throw Exception('Failed to load image');
        }
        return response.bodyBytes;
      });
      
      return Image.network(imageUrl);
    } catch (e) {
      // Return placeholder image on failure
      return Icon(Icons.image_not_supported, size: 100);
    }
  }
}
```

#### 3. User Action Rate Limiting

```dart
class LikeButton extends StatefulWidget {
  final String postId;
  
  const LikeButton({Key? key, required this.postId}) : super(key: key);
  
  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  static final _rateLimiter = ResiliencePipelineBuilder()
      .addRateLimiter(RateLimiterStrategyOptions(
        limiterType: RateLimiterType.slidingWindow,
        permitLimit: 5, // Max 5 likes per minute
        window: Duration(minutes: 1),
        onRejected: (args) async {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please wait before liking again')),
          );
        },
      ))
      .build();

  Future<void> _handleLike() async {
    try {
      await _rateLimiter.execute((context) async {
        await ApiClient.likePost(widget.postId);
        setState(() {
          // Update UI
        });
      });
    } catch (e) {
      // Rate limited - feedback already shown via onRejected
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _handleLike,
      icon: Icon(Icons.favorite),
    );
  }
}
```

#### 4. API Response Caching

```dart
class UserProfileService {
  static final _pipeline = ResiliencePipelineBuilder()
      // Cache user profiles for 5 minutes
      .addMemoryCache<UserProfile>(
        ttl: Duration(minutes: 5),
        maxSize: 1000,
      )
      // Retry on network failures
      .addRetry(RetryStrategyOptions(
        maxRetryAttempts: 2,
        delay: Duration(milliseconds: 500),
      ))
      // Timeout for slow requests
      .addTimeout(Duration(seconds: 10))
      .build();

  static Future<UserProfile> getUserProfile(String userId) async {
    return await _pipeline.execute(
      (context) async {
        print('Fetching user profile for $userId from API');
        
        final response = await http.get(
          Uri.parse('https://api.example.com/users/$userId'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return UserProfile.fromJson(data);
        } else {
          throw Exception('Failed to load user profile');
        }
      },
      context: ResilienceContext(operationKey: 'user-profile-$userId'),
    );
  }

  // This will hit the cache if called within 5 minutes
  static Future<UserProfile> getCachedUserProfile(String userId) async {
    return await getUserProfile(userId); // Same operation key = cache hit
  }
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  
  UserProfile({required this.id, required this.name, required this.email});
  
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}
```

### Backend Applications

Server applications need resilience for database calls, external service integrations, and handling high load scenarios:

#### 1. Database Operations with Retry

```dart
import 'package:postgres/postgres.dart';
import 'package:polly_dart/polly_dart.dart';

class DatabaseService {
  static final _dbPipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions(
        maxRetryAttempts: 3,
        delay: Duration(milliseconds: 100),
        backoffType: DelayBackoffType.exponential,
        shouldHandle: PredicateBuilder()
            .handleException<PostgreSQLException>()
            .handleException<SocketException>()
            .build(),
        onRetry: (args) async {
          print('Database operation failed, retrying... (${args.attemptNumber + 1}/3)');
        },
      ))
      .addTimeout(Duration(seconds: 30))
      .build();

  static final Connection _connection = // ... initialize connection

  static Future<List<Map<String, dynamic>>> getUsers() async {
    return await _dbPipeline.execute((context) async {
      final result = await _connection.execute('SELECT * FROM users');
      return result.map((row) => row.toColumnMap()).toList();
    });
  }

  static Future<void> createUser(Map<String, dynamic> userData) async {
    await _dbPipeline.execute((context) async {
      await _connection.execute(
        'INSERT INTO users (name, email) VALUES (@name, @email)',
        parameters: userData,
      );
    });
  }
}
```

#### 2. External Service Integration with Circuit Breaker

```dart
class PaymentService {
  static final _paymentPipeline = ResiliencePipelineBuilder()
      .addCircuitBreaker(CircuitBreakerStrategyOptions(
        failureRatio: 0.5,
        minimumThroughput: 10,
        samplingDuration: Duration(minutes: 5),
        breakDuration: Duration(minutes: 2),
        onOpened: (args) async {
          // Notify monitoring system
          await NotificationService.alertOps('Payment service circuit breaker opened');
        },
      ))
      .addRetry(RetryStrategyOptions(
        maxRetryAttempts: 2,
        delay: Duration(seconds: 1),
      ))
      .addTimeout(Duration(seconds: 45))
      .addFallback(FallbackStrategyOptions(
        fallbackAction: (args) async {
          // Queue payment for later processing
          await PaymentQueue.enqueue(args.context.properties['payment']);
          return Outcome.fromResult({'status': 'queued', 'id': 'pending'});
        },
      ))
      .build();

  static Future<Map<String, dynamic>> processPayment(PaymentRequest request) async {
    return await _paymentPipeline.execute((context) async {
      // Store payment in context for fallback
      context.properties['payment'] = request;
      
      final response = await http.post(
        Uri.parse('https://payment-gateway.com/charge'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw PaymentException('Payment failed: ${response.statusCode}');
      }
    });
  }
}
```

#### 3. API Rate Limiting and Load Management

```dart
class ApiController {
  // Global rate limiter for API endpoints
  static final _globalRateLimiter = ResiliencePipelineBuilder()
      .addRateLimiter(RateLimiterStrategyOptions(
        limiterType: RateLimiterType.concurrency,
        permitLimit: 100, // Max 100 concurrent requests
        onRejected: (args) async {
          print('Request rejected due to high load');
        },
      ))
      .build();

  // User-specific rate limiter
  static final _userRateLimiter = ResiliencePipelineBuilder()
      .addRateLimiter(RateLimiterStrategyOptions(
        limiterType: RateLimiterType.tokenBucket,
        permitLimit: 1000, // 1000 requests
        replenishmentPeriod: Duration(hours: 1), // per hour
        tokensPerPeriod: 1000,
      ))
      .build();

  static Future<Response> handleApiRequest(Request request) async {
    final userId = extractUserId(request);
    
    try {
      // Apply global rate limiting
      await _globalRateLimiter.execute((context) async {
        // Apply user-specific rate limiting
        await _userRateLimiter.execute((userContext) async {
          return await processRequest(request);
        });
      });
      
      return Response.ok('Success');
    } on RateLimitExceededException {
      return Response(429, body: 'Rate limit exceeded');
    } catch (e) {
      return Response.internalServerError(body: 'Internal error');
    }
  }
}
```

#### 4. Microservice Communication with Hedging

```dart
class OrderService {
  static final _hedgingPipeline = ResiliencePipelineBuilder()
      .addHedging(HedgingStrategyOptions(
        maxHedgedAttempts: 2,
        delay: Duration(milliseconds: 500),
        onHedging: (args) async {
          print('Starting hedged attempt ${args.attemptNumber + 1} for order processing');
        },
      ))
      .addTimeout(Duration(seconds: 10))
      .build();

  static Future<OrderResult> processOrder(Order order) async {
    return await _hedgingPipeline.execute((context) async {
      // This will try multiple inventory services in parallel
      final inventoryResult = await InventoryService.reserveItems(order.items);
      final paymentResult = await PaymentService.processPayment(order.payment);
      
      return OrderResult(
        orderId: order.id,
        inventoryReservation: inventoryResult,
        paymentConfirmation: paymentResult,
      );
    });
  }
}
```

These examples show how Polly Dart can be integrated into real applications to handle common resilience scenarios in both frontend and backend contexts.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.