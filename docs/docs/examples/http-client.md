---
sidebar_position: 1
---

# HTTP Client with Resilience

This example demonstrates how to build a robust HTTP client using Polly Dart resilience strategies. We'll create a client that handles network failures, service outages, and slow responses gracefully.

## The Problem

Standard HTTP clients are fragile:

```dart
// ❌ Fragile HTTP client
class BasicHttpClient {
  final HttpClient _client = HttpClient();
  
  Future<ApiResponse> get(String url) async {
    final request = await _client.getUrl(Uri.parse(url));
    final response = await request.close();
    
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    
    final body = await response.transform(utf8.decoder).join();
    return ApiResponse.fromJson(json.decode(body));
  }
}

// What happens when:
// - Network is slow or unstable?
// - Server returns 503 (temporary unavailability)?
// - Request takes too long?
// - Service is completely down?
```

## The Solution: Resilient HTTP Client

Let's build a production-ready HTTP client with comprehensive resilience:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:polly_dart/polly_dart.dart';

class ResilientHttpClient {
  final HttpClient _httpClient = HttpClient();
  late final ResiliencePipeline _pipeline;
  final String _baseUrl;
  final Map<String, dynamic> _defaultHeaders;

  ResilientHttpClient({
    required String baseUrl,
    Map<String, dynamic>? defaultHeaders,
    Duration? globalTimeout,
  }) : _baseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
       _defaultHeaders = defaultHeaders ?? {} {
    
    _pipeline = ResiliencePipelineBuilder()
        // 1. Retry transient failures with exponential backoff
        .addRetry(RetryStrategyOptions(
          maxRetryAttempts: 3,
          delay: Duration(seconds: 1),
          backoffType: DelayBackoffType.exponential,
          useJitter: true,
          maxDelay: Duration(seconds: 30),
          shouldHandle: _shouldRetryRequest,
          onRetry: _onRetryAttempt,
        ))
        
        // 2. Circuit breaker to fail fast when service is down
        .addCircuitBreaker(CircuitBreakerStrategyOptions(
          failureRatio: 0.5,
          samplingDuration: Duration(seconds: 30),
          minimumThroughput: 5,
          breakDuration: Duration(seconds: 30),
          shouldHandle: _shouldCountAsFailure,
          onOpened: _onCircuitOpened,
          onClosed: _onCircuitClosed,
        ))
        
        // 3. Timeout to prevent hanging requests
        .addTimeout(globalTimeout ?? Duration(seconds: 30))
        
        // 4. Fallback to cached data when all else fails
        .addFallback(FallbackStrategyOptions(
          shouldHandle: (outcome) => outcome.hasException,
          fallbackAction: _getFallbackResponse,
          onFallback: _onFallbackActivated,
        ))
        .build();
  }

  // GET request with full resilience
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? headers,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    return await _executeRequest<T>(
      'GET',
      endpoint,
      headers: headers,
      parser: parser,
    );
  }

  // POST request with resilience
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Object? body,
    Map<String, dynamic>? headers,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    return await _executeRequest<T>(
      'POST',
      endpoint,
      body: body,
      headers: headers,
      parser: parser,
    );
  }

  // PUT request with resilience
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Object? body,
    Map<String, dynamic>? headers,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    return await _executeRequest<T>(
      'PUT',
      endpoint,
      body: body,
      headers: headers,
      parser: parser,
    );
  }

  // DELETE request with resilience
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    Map<String, dynamic>? headers,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    return await _executeRequest<T>(
      'DELETE',
      endpoint,
      headers: headers,
      parser: parser,
    );
  }

  // Core request execution with resilience pipeline
  Future<ApiResponse<T>> _executeRequest<T>(
    String method,
    String endpoint, {
    Object? body,
    Map<String, dynamic>? headers,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    final context = ResilienceContext(operationKey: '$method:$endpoint');
    context.setProperty('method', method);
    context.setProperty('endpoint', endpoint);
    context.setProperty('hasBody', body != null);

    return await _pipeline.execute((ctx) async {
      return await _makeHttpRequest<T>(
        method,
        endpoint,
        body: body,
        headers: headers,
        parser: parser,
      );
    }, context: context);
  }

  // Raw HTTP request implementation
  Future<ApiResponse<T>> _makeHttpRequest<T>(
    String method,
    String endpoint, {
    Object? body,
    Map<String, dynamic>? headers,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    final uri = Uri.parse(_baseUrl + endpoint.replaceFirst(RegExp(r'^/'), ''));
    
    // Create request
    final request = await _httpClient.openUrl(method, uri);
    
    // Add headers
    _defaultHeaders.forEach((key, value) {
      request.headers.add(key, value.toString());
    });
    
    headers?.forEach((key, value) {
      request.headers.add(key, value.toString());
    });

    // Add body for POST/PUT requests
    if (body != null) {
      if (body is String) {
        request.headers.contentType = ContentType.text;
        request.write(body);
      } else {
        request.headers.contentType = ContentType.json;
        request.write(json.encode(body));
      }
    }

    // Send request and get response
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    // Handle HTTP errors
    if (response.statusCode >= 400) {
      throw HttpException(
        'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        uri: uri,
      );
    }

    // Parse response
    final responseData = responseBody.isNotEmpty 
        ? json.decode(responseBody) as Map<String, dynamic>
        : <String, dynamic>{};

    final parsedData = parser != null ? parser(responseData) : null;

    return ApiResponse<T>(
      statusCode: response.statusCode,
      data: parsedData,
      rawData: responseData,
      headers: response.headers.map((name, values) => MapEntry(name, values)),
    );
  }

  // Retry logic: only retry transient failures
  bool _shouldRetryRequest(Outcome outcome) {
    if (!outcome.hasException) return false;
    
    final exception = outcome.exception;
    
    // Always retry network-level issues
    if (exception is SocketException || exception is TimeoutException) {
      return true;
    }
    
    // Retry specific HTTP errors
    if (exception is HttpException) {
      final message = exception.message.toLowerCase();
      return message.contains('500') ||  // Internal server error
             message.contains('502') ||  // Bad gateway
             message.contains('503') ||  // Service unavailable
             message.contains('504') ||  // Gateway timeout
             message.contains('429');    // Rate limited
    }
    
    return false;
  }

  // Circuit breaker logic: count server errors, not client errors
  bool _shouldCountAsFailure(Outcome outcome) {
    if (!outcome.hasException) return false;
    
    final exception = outcome.exception;
    
    // Count network issues as failures
    if (exception is SocketException || exception is TimeoutException) {
      return true;
    }
    
    // Only count 5xx errors as circuit breaker failures
    if (exception is HttpException) {
      final message = exception.message.toLowerCase();
      return message.contains('5'); // 5xx server errors
    }
    
    return false;
  }

  // Retry callback for logging and metrics
  Future<void> _onRetryAttempt(OnRetryArguments args) async {
    final method = args.context.getProperty<String>('method') ?? 'UNKNOWN';
    final endpoint = args.context.getProperty<String>('endpoint') ?? 'unknown';
    final attemptNumber = args.attemptNumber + 1;
    
    print('🔄 Retrying $method $endpoint (attempt $attemptNumber)');
    
    // In a real app, you'd send this to your logging/metrics service
    _recordMetric('http_retry', {
      'method': method,
      'endpoint': endpoint,
      'attempt': attemptNumber.toString(),
      'error_type': args.outcome.exception.runtimeType.toString(),
    });
  }

  // Circuit breaker callbacks
  Future<void> _onCircuitOpened(OnCircuitOpenedArguments args) async {
    final method = args.context.getProperty<String>('method') ?? 'UNKNOWN';
    final endpoint = args.context.getProperty<String>('endpoint') ?? 'unknown';
    
    print('🔴 Circuit breaker opened for $method $endpoint');
    
    // Alert your monitoring system
    _sendAlert('Circuit Breaker Opened', '$method $endpoint is failing');
  }

  Future<void> _onCircuitClosed(OnCircuitClosedArguments args) async {
    final method = args.context.getProperty<String>('method') ?? 'UNKNOWN';
    final endpoint = args.context.getProperty<String>('endpoint') ?? 'unknown';
    
    print('🟢 Circuit breaker closed for $method $endpoint');
    
    _sendAlert('Circuit Breaker Closed', '$method $endpoint has recovered');
  }

  // Fallback response when all strategies are exhausted
  Future<Outcome<ApiResponse<T>>> _getFallbackResponse<T>(
    FallbackActionArguments args,
  ) async {
    final method = args.context.getProperty<String>('method') ?? 'UNKNOWN';
    final endpoint = args.context.getProperty<String>('endpoint') ?? 'unknown';
    
    print('🎯 Using fallback for $method $endpoint');

    // Try to get cached data
    final cachedData = await _getCachedResponse<T>(endpoint);
    if (cachedData != null) {
      return Outcome.fromResult(cachedData);
    }

    // Return a default error response
    return Outcome.fromResult(ApiResponse<T>(
      statusCode: 503,
      data: null,
      rawData: {
        'error': 'Service temporarily unavailable',
        'message': 'Please try again later',
        'fallback': true,
      },
      headers: {},
    ));
  }

  Future<void> _onFallbackActivated(OnFallbackArguments args) async {
    final method = args.context.getProperty<String>('method') ?? 'UNKNOWN';
    final endpoint = args.context.getProperty<String>('endpoint') ?? 'unknown';
    
    print('⚠️ Fallback activated for $method $endpoint');
    
    _recordMetric('http_fallback', {
      'method': method,
      'endpoint': endpoint,
    });
  }

  // Cache management (implement based on your needs)
  Future<ApiResponse<T>?> _getCachedResponse<T>(String endpoint) async {
    // Implement your caching logic here
    // This could use SharedPreferences, Hive, SQLite, etc.
    return null;
  }

  Future<void> _cacheResponse<T>(String endpoint, ApiResponse<T> response) async {
    // Implement response caching here
  }

  // Metrics and alerting (integrate with your monitoring system)
  void _recordMetric(String name, Map<String, String> tags) {
    // Send to your metrics service (Firebase Analytics, custom metrics, etc.)
    print('📊 Metric: $name with tags: $tags');
  }

  void _sendAlert(String title, String message) {
    // Send to your alerting system (Firebase Cloud Messaging, email, etc.)
    print('🚨 Alert: $title - $message');
  }

  // Cleanup
  void dispose() {
    _httpClient.close();
  }
}

// Response wrapper class
class ApiResponse<T> {
  final int statusCode;
  final T? data;
  final Map<String, dynamic> rawData;
  final Map<String, List<String>> headers;

  const ApiResponse({
    required this.statusCode,
    required this.data,
    required this.rawData,
    required this.headers,
  });

  bool get isSuccessful => statusCode >= 200 && statusCode < 300;
  bool get isFallback => rawData['fallback'] == true;
  
  // Convert to JSON for caching
  Map<String, dynamic> toJson() => {
    'statusCode': statusCode,
    'data': data,
    'rawData': rawData,
    'headers': headers,
  };

  // Create from cached JSON
  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse<T>(
      statusCode: json['statusCode'],
      data: json['data'],
      rawData: json['rawData'],
      headers: Map<String, List<String>>.from(json['headers']),
    );
  }
}
```

## Usage Examples

### Basic API Client Usage

```dart
void main() async {
  final apiClient = ResilientHttpClient(
    baseUrl: 'https://api.example.com',
    defaultHeaders: {
      'User-Agent': 'MyApp/1.0',
      'Accept': 'application/json',
    },
    globalTimeout: Duration(seconds: 30),
  );

  try {
    // GET request
    final userResponse = await apiClient.get<User>(
      '/users/123',
      parser: (json) => User.fromJson(json),
    );
    
    print('User: ${userResponse.data?.name}');

    // POST request  
    final createResponse = await apiClient.post<User>(
      '/users',
      body: {
        'name': 'John Doe',
        'email': 'john@example.com',
      },
      parser: (json) => User.fromJson(json),
    );
    
    print('Created user: ${createResponse.data?.id}');

  } catch (e) {
    print('API call failed: $e');
  } finally {
    apiClient.dispose();
  }
}

class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    name: json['name'],
    email: json['email'],
  );
}
```

### Advanced Usage with Custom Configuration

```dart
class UserService {
  final ResilientHttpClient _apiClient;

  UserService() : _apiClient = ResilientHttpClient(
    baseUrl: 'https://users-api.example.com',
    defaultHeaders: {
      'Authorization': 'Bearer ${getAuthToken()}',
    },
  );

  Future<List<User>> getUsers({int page = 1, int limit = 20}) async {
    final response = await _apiClient.get<List<User>>(
      '/users?page=$page&limit=$limit',
      parser: (json) {
        final users = json['users'] as List;
        return users.map((u) => User.fromJson(u)).toList();
      },
    );

    if (response.isFallback) {
      // Handle fallback response differently
      print('⚠️ Showing cached user data due to service issues');
    }

    return response.data ?? [];
  }

  Future<User> createUser(String name, String email) async {
    final response = await _apiClient.post<User>(
      '/users',
      body: {'name': name, 'email': email},
      parser: (json) => User.fromJson(json),
    );

    return response.data!;
  }

  Future<User> updateUser(int id, {String? name, String? email}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;

    final response = await _apiClient.put<User>(
      '/users/$id',
      body: body,
      parser: (json) => User.fromJson(json),
    );

    return response.data!;
  }

  Future<void> deleteUser(int id) async {
    await _apiClient.delete('/users/$id');
  }

  void dispose() {
    _apiClient.dispose();
  }
}
```

### Flutter Integration

```dart
class UserRepository extends ChangeNotifier {
  final UserService _userService = UserService();
  List<User> _users = [];
  bool _isLoading = false;
  String? _error;

  List<User> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _users = await _userService.getUsers();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createUser(String name, String email) async {
    try {
      final newUser = await _userService.createUser(name, email);
      _users.add(newUser);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _userService.dispose();
    super.dispose();
  }
}

// In your Flutter widget
class UserListWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<UserRepository>(
      builder: (context, repository, child) {
        if (repository.isLoading) {
          return CircularProgressIndicator();
        }

        if (repository.error != null) {
          return Column(
            children: [
              Text('Error: ${repository.error}'),
              ElevatedButton(
                onPressed: repository.loadUsers,
                child: Text('Retry'),
              ),
            ],
          );
        }

        return ListView.builder(
          itemCount: repository.users.length,
          itemBuilder: (context, index) {
            final user = repository.users[index];
            return ListTile(
              title: Text(user.name),
              subtitle: Text(user.email),
            );
          },
        );
      },
    );
  }
}
```

## Key Benefits

This resilient HTTP client provides:

1. **🔄 Automatic Retries**: Transient failures are handled automatically with intelligent backoff
2. **⚡ Circuit Breaker Protection**: Prevents cascading failures when services are down
3. **⏱️ Timeout Management**: Prevents hanging requests from degrading performance
4. **🎯 Graceful Fallbacks**: Users get cached data instead of error screens
5. **📊 Built-in Observability**: Comprehensive logging and metrics for monitoring
6. **🛡️ Production Ready**: Handles edge cases and provides clean error boundaries

## Testing the Resilient Client

```dart
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('ResilientHttpClient', () {
    test('should retry on transient failures', () async {
      // Test retry behavior
    });

    test('should open circuit breaker on persistent failures', () async {
      // Test circuit breaker behavior
    });

    test('should return cached data when service is down', () async {
      // Test fallback behavior
    });

    test('should timeout on slow requests', () async {
      // Test timeout behavior
    });
  });
}
```

This example demonstrates how Polly Dart transforms a basic HTTP client into a production-ready, resilient service that can handle the complexities of real-world networking while providing excellent user experience.

## Next Steps

- **[Database Example](./database)** - See how to apply resilience to database operations
- **[Flutter App Example](./flutter-app)** - Complete Flutter app with resilience
- **[Real-World Example](./real-world)** - Complex production scenarios
