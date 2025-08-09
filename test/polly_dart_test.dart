import 'dart:async';

import 'package:polly_dart/polly_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Polly Dart Tests', () {
    group('Outcome', () {
      test('should create result outcome', () {
        final outcome = Outcome.fromResult('test');

        expect(outcome.hasResult, isTrue);
        expect(outcome.hasException, isFalse);
        expect(outcome.result, equals('test'));
        expect(() => outcome.exception, throwsStateError);
      });

      test('should create exception outcome', () {
        final exception = Exception('test error');
        final outcome = Outcome.fromException(exception);

        expect(outcome.hasResult, isFalse);
        expect(outcome.hasException, isTrue);
        expect(outcome.exception, equals(exception));
        expect(() => outcome.result, throwsStateError);
      });

      test('should throw exception when requested', () {
        final exception = Exception('test error');
        final outcome = Outcome.fromException(exception);

        expect(() => outcome.throwIfException(), throwsA(equals(exception)));
      });

      test('should convert to future correctly', () async {
        final resultOutcome = Outcome.fromResult('test');
        final result = await resultOutcome.asFuture();
        expect(result, equals('test'));

        final exception = Exception('test error');
        final exceptionOutcome = Outcome.fromException(exception);
        expect(() => exceptionOutcome.asFuture(), throwsA(equals(exception)));
      });
    });

    group('ResilienceContext', () {
      test('should track attempt number', () {
        final context = ResilienceContext();

        expect(context.attemptNumber, equals(0));

        context.incrementAttemptNumber();
        expect(context.attemptNumber, equals(1));

        context.setAttemptNumber(5);
        expect(context.attemptNumber, equals(5));
      });

      test('should handle cancellation', () {
        final context = ResilienceContext();

        expect(context.isCancellationRequested, isFalse);

        context.cancel();
        expect(context.isCancellationRequested, isTrue);
        expect(() => context.throwIfCancellationRequested(),
            throwsA(isA<OperationCancelledException>()));
      });

      test('should handle properties', () {
        final context = ResilienceContext();

        context.setProperty('key1', 'value1');
        context.setProperty('key2', 42);

        expect(context.getProperty<String>('key1'), equals('value1'));
        expect(context.getProperty<int>('key2'), equals(42));
        expect(context.getProperty<String>('nonexistent'), isNull);
        expect(context.hasProperty('key1'), isTrue);
        expect(context.hasProperty('nonexistent'), isFalse);

        context.removeProperty('key1');
        expect(context.hasProperty('key1'), isFalse);
      });

      test('should copy context correctly', () {
        final original = ResilienceContext(operationKey: 'test');
        original.setProperty('key', 'value');
        original.setAttemptNumber(3);

        final copy = original.copy();

        expect(copy.operationKey, equals('test'));
        expect(copy.getProperty<String>('key'), equals('value'));
        expect(copy.attemptNumber, equals(3));
        expect(copy.isCancellationRequested, isFalse);
      });
    });

    group('RetryStrategy', () {
      test('should retry on exceptions', () async {
        var attempts = 0;
        final strategy = RetryStrategy(RetryStrategyOptions(
          maxRetryAttempts: 3,
          delay: Duration.zero,
        ));

        final outcome = await strategy.executeCore<String>((context) async {
          attempts++;
          if (attempts < 3) {
            throw Exception('Failed attempt $attempts');
          }
          return 'Success';
        }, ResilienceContext());

        expect(attempts, equals(3));
        expect(outcome.hasResult, isTrue);
        expect(outcome.result, equals('Success'));
      });

      test('should respect maximum retry attempts', () async {
        var attempts = 0;
        final strategy = RetryStrategy(RetryStrategyOptions(
          maxRetryAttempts: 2,
          delay: Duration.zero,
        ));

        final outcome = await strategy.executeCore<String>((context) async {
          attempts++;
          throw Exception('Always fails');
        }, ResilienceContext());

        expect(attempts, equals(3)); // Initial + 2 retries
        expect(outcome.hasException, isTrue);
      });

      test('should call onRetry callback', () async {
        var retryCallbackCount = 0;
        final strategy = RetryStrategy(RetryStrategyOptions(
          maxRetryAttempts: 2,
          delay: Duration.zero,
          onRetry: (args) async {
            retryCallbackCount++;
          },
        ));

        await strategy.executeCore<String>((context) async {
          throw Exception('Always fails');
        }, ResilienceContext());

        expect(retryCallbackCount, equals(2));
      });
    });

    group('TimeoutStrategy', () {
      test('should timeout long-running operations', () async {
        final strategy = TimeoutStrategy(TimeoutStrategyOptions(
          timeout: Duration(milliseconds: 100),
        ));

        final outcome = await strategy.executeCore<String>((context) async {
          await Future.delayed(Duration(milliseconds: 200));
          return 'Should not complete';
        }, ResilienceContext());

        expect(outcome.hasException, isTrue);
        expect(outcome.exception, isA<TimeoutRejectedException>());
      });

      test('should complete fast operations', () async {
        final strategy = TimeoutStrategy(TimeoutStrategyOptions(
          timeout: Duration(milliseconds: 200),
        ));

        final outcome = await strategy.executeCore<String>((context) async {
          await Future.delayed(Duration(milliseconds: 50));
          return 'Completed';
        }, ResilienceContext());

        expect(outcome.hasResult, isTrue);
        expect(outcome.result, equals('Completed'));
      });
    });

    group('CircuitBreakerStrategy', () {
      test('should open circuit after failure threshold', () async {
        final stateProvider = CircuitBreakerStateProvider();
        final strategy = CircuitBreakerStrategy(CircuitBreakerStrategyOptions(
          failureRatio: 0.5,
          minimumThroughput: 2,
          samplingDuration: Duration(seconds: 1),
          breakDuration: Duration(milliseconds: 100),
          stateProvider: stateProvider,
        ));

        expect(stateProvider.circuitState, equals(CircuitState.closed));

        // Execute failing operations to trigger circuit breaker
        for (int i = 0; i < 3; i++) {
          await strategy.executeCore<String>((context) async {
            throw Exception('Failure');
          }, ResilienceContext());
        }

        expect(stateProvider.circuitState, equals(CircuitState.open));

        // Next call should be rejected
        final outcome = await strategy.executeCore<String>((context) async {
          return 'Should be rejected';
        }, ResilienceContext());

        expect(outcome.hasException, isTrue);
        expect(outcome.exception, isA<CircuitBreakerRejectedException>());
      });
    });

    group('FallbackStrategy', () {
      test('should use fallback on failure', () async {
        final strategy = FallbackStrategy(FallbackStrategyOptions<String>(
          fallbackAction: (args) async => Outcome.fromResult('Fallback result'),
        ));

        final outcome = await strategy.executeCore<String>((context) async {
          throw Exception('Primary failed');
        }, ResilienceContext());

        expect(outcome.hasResult, isTrue);
        expect(outcome.result, equals('Fallback result'));
      });

      test('should not use fallback on success', () async {
        final strategy = FallbackStrategy(FallbackStrategyOptions<String>(
          fallbackAction: (args) async => Outcome.fromResult('Fallback result'),
        ));

        final outcome = await strategy.executeCore<String>((context) async {
          return 'Primary result';
        }, ResilienceContext());

        expect(outcome.hasResult, isTrue);
        expect(outcome.result, equals('Primary result'));
      });
    });

    group('RateLimiterStrategy', () {
      test('should reject requests exceeding limit', () async {
        final strategy =
            RateLimiterStrategy(RateLimiterStrategyOptions.fixedWindow(
          permitLimit: 2,
          window: Duration(seconds: 1),
        ));

        final futures = <Future<Outcome<String>>>[];

        // Submit 3 requests, expect 1 to be rejected
        for (int i = 0; i < 3; i++) {
          futures.add(strategy.executeCore<String>((context) async {
            return 'Request $i';
          }, ResilienceContext()));
        }

        final results = await Future.wait(futures);
        final rejectedCount = results
            .where((r) =>
                r.hasException && r.exception is RateLimiterRejectedException)
            .length;

        expect(rejectedCount, equals(1));
      });
    });

    group('ResiliencePipelineBuilder', () {
      test('should build pipeline with multiple strategies', () {
        final pipeline = ResiliencePipelineBuilder()
            .addRetry()
            .addTimeout(Duration(seconds: 1))
            .addCircuitBreaker()
            .build();

        expect(pipeline.strategyCount, equals(3));
        expect(pipeline.isNotEmpty, isTrue);
      });

      test('should execute through pipeline', () async {
        final pipeline = ResiliencePipelineBuilder()
            .addRetry(RetryStrategyOptions(
              maxRetryAttempts: 1,
              delay: Duration.zero,
            ))
            .build();

        var attempts = 0;
        final result = await pipeline.execute<String>((context) async {
          attempts++;
          if (attempts == 1) {
            throw Exception('First attempt fails');
          }
          return 'Success on attempt $attempts';
        });

        expect(result, equals('Success on attempt 2'));
        expect(attempts, equals(2));
      });
    });

    group('PredicateBuilder', () {
      test('should handle specific exception types', () {
        final predicate =
            PredicateBuilder<String>().handle<ArgumentError>().build();

        final argErrorOutcome = Outcome<String>.fromException(ArgumentError());
        final stateErrorOutcome =
            Outcome<String>.fromException(StateError('test'));
        final resultOutcome = Outcome.fromResult('test');

        expect(predicate(argErrorOutcome), isTrue);
        expect(predicate(stateErrorOutcome), isFalse);
        expect(predicate(resultOutcome), isFalse);
      });

      test('should handle result conditions', () {
        final predicate = PredicateBuilder<int>()
            .handleResult((result) => result < 0)
            .build();

        final negativeResult = Outcome.fromResult(-1);
        final positiveResult = Outcome.fromResult(1);
        final exceptionOutcome = Outcome<int>.fromException(Exception());

        expect(predicate(negativeResult), isTrue);
        expect(predicate(positiveResult), isFalse);
        expect(predicate(exceptionOutcome), isFalse);
      });
    });
  });
}
