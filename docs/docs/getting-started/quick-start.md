---
sidebar_position: 2
---

# Quick Start

Learn the basics of Polly Dart with hands-on examples. In 5 minutes, you'll understand how to build resilient applications with minimal code changes.

## Your First Resilience Pipeline

Let's start with a simple example that demonstrates the core concepts:

```dart
import 'package:polly_dart/polly_dart.dart';

void main() async {
  // 1. Create a resilience pipeline
  final pipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions(maxRetryAttempts: 3))
      .addTimeout(Duration(seconds: 10))
      .build();

  // 2. Execute your code with resilience
  try {
    final result = await pipeline.execute((context) async {
      // Your potentially failing operation
      return await simulateApiCall();
    });
    
    print('Success: $result');
  } catch (e) {
    print('Final failure: $e');
  }
}

// Simulate an API call that might fail
Future<String> simulateApiCall() async {
  // Simulate network delay
  await Future.delayed(Duration(milliseconds: 500));
  
  // Simulate random failures (30% success rate)
  if (DateTime.now().millisecond % 10 < 3) {
    return 'API response data';
  } else {
    throw Exception('Network error');
  }
}
```

### What Just Happened?

1. **Pipeline Creation**: We built a resilience pipeline with retry and timeout strategies
2. **Execution**: We wrapped our potentially failing operation with resilience handling
3. **Automatic Handling**: Polly automatically retried failures and applied timeouts

## The Builder Pattern

Polly Dart uses the builder pattern for creating pipelines. This allows you to:

- **Chain strategies** in a fluent, readable way
- **Combine multiple strategies** for comprehensive resilience
- **Configure each strategy** with specific options

```dart
final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 3,
      delay: Duration(seconds: 1),
      backoffType: DelayBackoffType.exponential,
    ))
    .addCircuitBreaker(CircuitBreakerStrategyOptions(
      failureRatio: 0.5,
      breakDuration: Duration(seconds: 5),
    ))
    .addTimeout(Duration(seconds: 30))
    .build(); // Creates the final pipeline
```

## Working with Different Return Types

Polly Dart works with any return type using Dart's generics:

```dart
// String return type
final stringPipeline = ResiliencePipelineBuilder()
    .addRetry()
    .build();

final message = await stringPipeline.execute<String>((context) async {
  return 'Hello World';
});

// Custom object return type
class User {
  final String name;
  final int id;
  User(this.name, this.id);
}

final userPipeline = ResiliencePipelineBuilder()
    .addRetry()
    .addTimeout(Duration(seconds: 5))
    .build();

final user = await userPipeline.execute<User>((context) async {
  return await fetchUser(123);
});
```

## HTTP Client Example

Here's a real-world example using Polly Dart with HTTP requests:

```dart
import 'dart:io';
import 'package:polly_dart/polly_dart.dart';

class ResilientHttpClient {
  final HttpClient _httpClient = HttpClient();
  late final ResiliencePipeline _pipeline;

  ResilientHttpClient() {
    _pipeline = ResiliencePipelineBuilder()
        .addRetry(RetryStrategyOptions(
          maxRetryAttempts: 3,
          delay: Duration(seconds: 1),
          backoffType: DelayBackoffType.exponential,
          shouldHandle: (outcome) {
            // Only retry on network errors
            return outcome.hasException && 
                   outcome.exception is SocketException;
          },
          onRetry: (args) async {
            print('Retrying request... Attempt ${args.attemptNumber + 1}');
          },
        ))
        .addTimeout(Duration(seconds: 30))
        .addFallback(FallbackStrategyOptions.withValue('Cached data'))
        .build();
  }

  Future<String> get(String url) async {
    return await _pipeline.execute((context) async {
      final request = await _httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      
      return await response.transform(utf8.decoder).join();
    });
  }

  void dispose() {
    _httpClient.close();
  }
}

// Usage
void main() async {
  final client = ResilientHttpClient();
  
  try {
    final data = await client.get('https://api.example.com/data');
    print('Response: $data');
  } finally {
    client.dispose();
  }
}
```

## Handling Different Types of Failures

Polly Dart allows you to specify which failures should trigger each strategy:

```dart
final smartPipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 3,
      shouldHandle: (outcome) {
        // Only retry transient failures
        if (!outcome.hasException) return false;
        
        final exception = outcome.exception;
        return exception is SocketException ||
               exception is TimeoutException ||
               (exception is HttpException && 
                exception.message.contains('503'));
      },
    ))
    .addFallback(FallbackStrategyOptions(
      fallbackAction: (args) async {
        // Provide fallback for any failure
        return Outcome.fromResult('Fallback response');
      },
      shouldHandle: (outcome) => outcome.hasException,
    ))
    .build();
```

## Error Handling and Outcomes

Polly Dart provides two ways to handle execution results:

### 1. Traditional Exception Handling
```dart
try {
  final result = await pipeline.execute((context) async {
    return await someOperation();
  });
  // Use result
} catch (e) {
  // Handle final failure
}
```

### 2. Outcome-Based Handling
```dart
final outcome = await pipeline.executeAndCapture((context) async {
  return await someOperation();
});

if (outcome.hasResult) {
  print('Success: ${outcome.result}');
} else {
  print('Failed: ${outcome.exception}');
}
```

## Context and Metadata

The `ResilienceContext` provides information about the execution:

```dart
final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      onRetry: (args) async {
        print('Attempt ${args.context.attemptNumber + 1}');
        print('Operation key: ${args.context.operationKey}');
      },
    ))
    .build();

// Execute with custom context
final context = ResilienceContext(operationKey: 'user-data-fetch');
context.setProperty('userId', 123);

final result = await pipeline.execute(
  (ctx) async {
    final userId = ctx.getProperty<int>('userId');
    return await fetchUserData(userId!);
  },
  context: context,
);
```

## Next Steps

Now that you understand the basics, explore specific strategies:

- **[🔄 Retry Strategy](../strategies/retry)** - Handle transient failures
- **[⚡ Circuit Breaker](../strategies/circuit-breaker)** - Prevent cascading failures  
- **[⏱️ Timeout Strategy](../strategies/timeout)** - Control operation duration
- **[🎯 Fallback Strategy](../strategies/fallback)** - Provide alternative responses

Or dive deeper into advanced topics:

- **[🧠 Basic Concepts](./basic-concepts)** - Understand the theory
- **[🔧 Combining Strategies](../advanced/combining-strategies)** - Build complex pipelines
- **[📊 Monitoring](../advanced/monitoring)** - Track pipeline performance

## Common Patterns

### Database Operations
```dart
final dbPipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 3,
      delay: Duration(milliseconds: 100),
    ))
    .addTimeout(Duration(seconds: 10))
    .build();

final user = await dbPipeline.execute((context) async {
  return await database.getUser(userId);
});
```

### File Operations
```dart
final filePipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 2))
    .addFallback(FallbackStrategyOptions.withValue('default content'))
    .build();

final content = await filePipeline.execute((context) async {
  return await File('config.json').readAsString();
});
```

### External Service Calls
```dart
final servicePipeline = ResiliencePipelineBuilder()
    .addHedging(HedgingStrategyOptions(
      maxHedgedAttempts: 2,
      delay: Duration(milliseconds: 100),
      actionProvider: (args) => (context) async {
        return await callExternalService();
      },
    ))
    .addTimeout(Duration(seconds: 5))
    .build();
```

You're now ready to build resilient Dart applications! 🎉
