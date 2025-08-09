import 'dart:async';
import 'dart:math';

import 'package:polly_dart/polly_dart.dart';

/// Example demonstrating various Polly resilience strategies.
void main() async {
  print('Polly Dart Examples');
  print('===================\n');

  await retryExample();
  await timeoutExample();
  await circuitBreakerExample();
  await fallbackExample();
  await hedgingExample();
  await rateLimiterExample();
  await combinedStrategiesExample();
}

/// Demonstrates retry strategy with exponential backoff.
Future<void> retryExample() async {
  print('1. Retry Strategy Example');
  print('-------------------------');

  final pipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions(
        maxRetryAttempts: 3,
        delay: Duration(milliseconds: 500),
        backoffType: DelayBackoffType.exponential,
        useJitter: true,
        onRetry: (args) async {
          print(
              '  Retry attempt ${args.attemptNumber + 1} after ${args.delay.inMilliseconds}ms delay');
        },
      ))
      .build();

  try {
    final result = await pipeline.execute((context) async {
      print('  Executing potentially failing operation...');

      // Simulate a flaky operation (70% failure rate)
      if (Random().nextDouble() < 0.7) {
        throw Exception('Simulated transient failure');
      }

      return 'Success!';
    });

    print('  Result: $result');
  } catch (e) {
    print('  Final failure: $e');
  }

  print('');
}

/// Demonstrates timeout strategy.
Future<void> timeoutExample() async {
  print('2. Timeout Strategy Example');
  print('---------------------------');

  final pipeline =
      ResiliencePipelineBuilder().addTimeout(Duration(seconds: 2)).build();

  try {
    final result = await pipeline.execute((context) async {
      print('  Starting slow operation...');

      // Simulate a slow operation
      await Future.delayed(Duration(seconds: 3));

      return 'This should timeout';
    });

    print('  Result: $result');
  } catch (e) {
    print('  Timeout occurred: ${e.runtimeType}');
  }

  print('');
}

/// Demonstrates circuit breaker strategy.
Future<void> circuitBreakerExample() async {
  print('3. Circuit Breaker Strategy Example');
  print('-----------------------------------');

  final stateProvider = CircuitBreakerStateProvider();
  final pipeline = ResiliencePipelineBuilder()
      .addCircuitBreaker(CircuitBreakerStrategyOptions(
        failureRatio: 0.5,
        minimumThroughput: 3,
        samplingDuration: Duration(seconds: 10),
        breakDuration: Duration(seconds: 2),
        stateProvider: stateProvider,
        onOpened: (args) async {
          print('  Circuit breaker opened!');
        },
        onClosed: (args) async {
          print('  Circuit breaker closed.');
        },
      ))
      .build();

  print('  Circuit state: ${stateProvider.circuitState}');

  // Execute several failing operations to trigger circuit breaker
  for (int i = 0; i < 5; i++) {
    try {
      await pipeline.execute((context) async {
        print('  Attempt ${i + 1}...');
        throw Exception('Simulated failure');
      });
    } catch (e) {
      print('  Failed: ${e.runtimeType}');
    }

    print('  Circuit state: ${stateProvider.circuitState}');
    await Future.delayed(Duration(milliseconds: 100));
  }

  print('');
}

/// Demonstrates fallback strategy.
Future<void> fallbackExample() async {
  print('4. Fallback Strategy Example');
  print('----------------------------');

  final pipeline = TypedResiliencePipelineBuilder<String>()
      .addFallback(FallbackStrategyOptions<String>(
        fallbackAction: (args) async {
          print('  Executing fallback action...');
          return Outcome.fromResult('Fallback result');
        },
        onFallback: (args) async {
          print('  Primary operation failed, using fallback');
        },
      ))
      .build();

  try {
    final result = await pipeline.execute((context) async {
      print('  Executing primary operation...');
      throw Exception('Primary operation failed');
    });

    print('  Result: $result');
  } catch (e) {
    print('  Unexpected error: $e');
  }

  print('');
}

/// Demonstrates hedging strategy.
Future<void> hedgingExample() async {
  print('5. Hedging Strategy Example');
  print('---------------------------');

  final pipeline = TypedResiliencePipelineBuilder<String>()
      .addHedging(HedgingStrategyOptions<String>(
        maxHedgedAttempts: 2,
        delay: Duration(milliseconds: 500),
        onHedging: (args) async {
          print('  Starting hedged attempt ${args.attemptNumber + 1}...');
        },
      ))
      .build();

  final stopwatch = Stopwatch()..start();

  try {
    final result = await pipeline.execute((context) async {
      final delay = Duration(milliseconds: 800 + Random().nextInt(400));
      print(
          '  Attempt ${context.attemptNumber + 1} will take ${delay.inMilliseconds}ms');

      await Future.delayed(delay);
      return 'Result from attempt ${context.attemptNumber + 1}';
    });

    stopwatch.stop();
    print('  Result: $result');
    print('  Total time: ${stopwatch.elapsedMilliseconds}ms');
  } catch (e) {
    print('  Error: $e');
  }

  print('');
}

/// Demonstrates rate limiter strategy.
Future<void> rateLimiterExample() async {
  print('6. Rate Limiter Strategy Example');
  print('--------------------------------');

  final pipeline = ResiliencePipelineBuilder()
      .addRateLimiter(RateLimiterStrategyOptions.slidingWindow(
        permitLimit: 3,
        window: Duration(seconds: 2),
        onRejected: (args) async {
          print('  Request rejected: ${args.reason}');
        },
      ))
      .build();

  // Try to execute 5 requests rapidly
  final futures = <Future>[];
  for (int i = 0; i < 5; i++) {
    futures.add(pipeline.execute((context) async {
      print('  Request ${i + 1} executing...');
      await Future.delayed(Duration(milliseconds: 100));
      return 'Response ${i + 1}';
    }).catchError((e) {
      return 'Rejected';
    }));
  }

  final results = await Future.wait(futures);
  for (int i = 0; i < results.length; i++) {
    print('  Request ${i + 1} result: ${results[i]}');
  }

  print('');
}

/// Demonstrates combining multiple strategies.
Future<void> combinedStrategiesExample() async {
  print('7. Combined Strategies Example');
  print('------------------------------');

  final pipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions(
        maxRetryAttempts: 2,
        delay: Duration(milliseconds: 200),
      ))
      .addTimeout(Duration(seconds: 5))
      .addCircuitBreaker(CircuitBreakerStrategyOptions(
        failureRatio: 0.8,
        minimumThroughput: 2,
      ))
      .build();

  for (int i = 0; i < 3; i++) {
    try {
      final result = await pipeline.execute((context) async {
        print('  Execution ${i + 1}, attempt ${context.attemptNumber + 1}');

        // Simulate occasional failures
        if (Random().nextDouble() < 0.6) {
          throw Exception('Simulated failure');
        }

        return 'Success on execution ${i + 1}';
      });

      print('  Result: $result');
    } catch (e) {
      print('  Failed: ${e.runtimeType}');
    }

    await Future.delayed(Duration(milliseconds: 100));
  }

  print('');
  print('Examples completed!');
}
