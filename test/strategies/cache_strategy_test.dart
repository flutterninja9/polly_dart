import 'dart:async';

import 'package:polly_dart/src/caching/cache_callbacks.dart';
import 'package:polly_dart/src/caching/cache_provider.dart';
import 'package:polly_dart/src/caching/memory_cache_provider.dart';
import 'package:polly_dart/src/resilience_context.dart';
import 'package:polly_dart/src/strategies/cache_strategy.dart';
import 'package:test/test.dart';

/// Mock cache provider for testing
class MockCacheProvider implements CacheProvider {
  final Map<String, dynamic> _storage = {};
  final List<String> _getKeys = [];
  final List<String> _setKeys = [];
  final List<String> _removeKeys = [];
  bool _throwOnSet = false;

  @override
  Future<T?> get<T>(String key) async {
    _getKeys.add(key);
    final value = _storage[key];
    try {
      return value as T?;
    } catch (e) {
      // Type casting failed, return null
      return null;
    }
  }

  @override
  Future<void> set<T>(String key, T value, {Duration? ttl}) async {
    _setKeys.add(key);
    if (_throwOnSet) throw Exception('Cache set failed');
    _storage[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _removeKeys.add(key);
    _storage.remove(key);
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  int? get size => _storage.length;

  // Test helpers
  List<String> get getKeys => List.unmodifiable(_getKeys);
  List<String> get setKeys => List.unmodifiable(_setKeys);
  List<String> get removeKeys => List.unmodifiable(_removeKeys);

  void setThrowOnSet(bool value) => _throwOnSet = value;
  void reset() {
    _storage.clear();
    _getKeys.clear();
    _setKeys.clear();
    _removeKeys.clear();
    _throwOnSet = false;
  }

  void resetCounters() {
    _getKeys.clear();
    _setKeys.clear();
    _removeKeys.clear();
  }
}

void main() {
  group('CacheStrategy', () {
    late MockCacheProvider mockCache;
    late CacheStrategy<String> strategy;
    late ResilienceContext context;

    setUp(() {
      mockCache = MockCacheProvider();
      strategy = CacheStrategy<String>(CacheStrategyOptions(cache: mockCache));
      context = ResilienceContext(operationKey: 'test-operation');
    });

    group('Cache miss scenarios', () {
      test('should execute callback and cache result on cache miss', () async {
        var callbackExecuted = false;

        final outcome = await strategy.executeCore<String>(
          (context) async {
            callbackExecuted = true;
            return 'test-result';
          },
          context,
        );

        expect(callbackExecuted, isTrue);
        expect(outcome.hasResult, isTrue);
        expect(outcome.result, equals('test-result'));

        // Verify cache operations
        expect(mockCache.getKeys, contains('test-operation'));
        expect(mockCache.setKeys, contains('test-operation'));
        expect(mockCache._storage['test-operation'], equals('test-result'));
      });

      test('should handle callback exceptions properly', () async {
        final outcome = await strategy.executeCore<String>(
          (context) async {
            throw Exception('Callback failed');
          },
          context,
        );

        expect(outcome.hasException, isTrue);
        expect(outcome.exception.toString(), contains('Callback failed'));

        // Should not try to cache exceptions
        expect(mockCache.setKeys, isEmpty);
      });
    });

    group('Cache hit scenarios', () {
      test('should return cached value on cache hit', () async {
        // Pre-populate cache
        await mockCache.set('test-operation', 'cached-result');
        mockCache.resetCounters(); // Reset counters but keep storage

        var callbackExecuted = false;

        final outcome = await strategy.executeCore<String>(
          (context) async {
            callbackExecuted = true;
            return 'fresh-result';
          },
          context,
        );

        expect(callbackExecuted, isFalse); // Callback should not be executed
        expect(outcome.hasResult, isTrue);
        expect(outcome.result, equals('cached-result'));

        // Verify cache operations
        expect(mockCache.getKeys, contains('test-operation'));
        expect(mockCache.setKeys, isEmpty); // Should not set on cache hit
      });
    });

    group('Key generation', () {
      test('should use default key generator when none provided', () async {
        await strategy.executeCore<String>(
          (context) async => 'result',
          context,
        );

        expect(mockCache.getKeys, contains('test-operation'));
      });

      test('should use custom key generator when provided', () async {
        final customStrategy = CacheStrategy<String>(
          CacheStrategyOptions(
            cache: mockCache,
            keyGenerator: (context) => 'custom-${context.operationKey}',
          ),
        );

        await customStrategy.executeCore<String>(
          (context) async => 'result',
          context,
        );

        expect(mockCache.getKeys, contains('custom-test-operation'));
      });

      test('should bypass caching for empty keys', () async {
        final emptyKeyStrategy = CacheStrategy<String>(
          CacheStrategyOptions(
            cache: mockCache,
            keyGenerator: (context) => '',
          ),
        );

        var callbackExecuted = false;

        final outcome = await emptyKeyStrategy.executeCore<String>(
          (context) async {
            callbackExecuted = true;
            return 'result';
          },
          context,
        );

        expect(callbackExecuted, isTrue);
        expect(outcome.result, equals('result'));

        // Should not perform any cache operations for empty keys
        expect(mockCache.getKeys, isEmpty);
        expect(mockCache.setKeys, isEmpty);
      });

      test('should bypass caching for null operation key', () async {
        final contextWithoutKey = ResilienceContext();

        var callbackExecuted = false;

        final outcome = await strategy.executeCore<String>(
          (context) async {
            callbackExecuted = true;
            return 'result';
          },
          contextWithoutKey,
        );

        expect(callbackExecuted, isTrue);
        expect(outcome.result, equals('result'));

        // Should not perform any cache operations for null keys
        expect(mockCache.getKeys, isEmpty);
        expect(mockCache.setKeys, isEmpty);
      });
    });

    group('Should cache predicate', () {
      test('should cache when should cache predicate returns true', () async {
        final customStrategy = CacheStrategy<String>(
          CacheStrategyOptions(
            cache: mockCache,
            shouldCache: (outcome) =>
                outcome.hasResult && outcome.result.isNotEmpty,
          ),
        );

        await customStrategy.executeCore<String>(
          (context) async => 'result',
          context,
        );

        expect(mockCache.setKeys, contains('test-operation'));
      });

      test('should not cache when should cache predicate returns false',
          () async {
        final customStrategy = CacheStrategy<String>(
          CacheStrategyOptions(
            cache: mockCache,
            shouldCache: (outcome) => false,
          ),
        );

        await customStrategy.executeCore<String>(
          (context) async => 'result',
          context,
        );

        expect(mockCache.setKeys, isEmpty);
      });

      test('should not cache empty results when using custom predicate',
          () async {
        final customStrategy = CacheStrategy<String>(
          CacheStrategyOptions(
            cache: mockCache,
            shouldCache: (outcome) =>
                outcome.hasResult && outcome.result.isNotEmpty,
          ),
        );

        await customStrategy.executeCore<String>(
          (context) async => '',
          context,
        );

        expect(mockCache.setKeys, isEmpty);
      });
    });

    group('Error handling', () {
      test('should continue operation when cache set fails', () async {
        mockCache.setThrowOnSet(true);

        var callbackExecuted = false;

        final outcome = await strategy.executeCore<String>(
          (context) async {
            callbackExecuted = true;
            return 'result';
          },
          context,
        );

        expect(callbackExecuted, isTrue);
        expect(outcome.result, equals('result'));
        // Operation should succeed even if caching fails
      });
    });

    group('Callbacks', () {
      test('should invoke onHit callback on cache hit', () async {
        await mockCache.set('test-operation', 'cached-result');

        var hitCallbackCalled = false;
        OnCacheHitArguments<String>? hitArgs;

        final callbackStrategy = CacheStrategy<String>(
          CacheStrategyOptions(
            cache: mockCache,
            onHit: (args) async {
              hitCallbackCalled = true;
              hitArgs = args;
            },
          ),
        );

        await callbackStrategy.executeCore<String>(
          (context) async => 'fresh-result',
          context,
        );

        expect(hitCallbackCalled, isTrue);
        expect(hitArgs?.key, equals('test-operation'));
        expect(hitArgs?.value, equals('cached-result'));
        expect(hitArgs?.context, equals(context));
      });

      test('should invoke onMiss callback on cache miss', () async {
        var missCallbackCalled = false;
        OnCacheMissArguments<String>? missArgs;

        final callbackStrategy = CacheStrategy<String>(
          CacheStrategyOptions(
            cache: mockCache,
            onMiss: (args) async {
              missCallbackCalled = true;
              missArgs = args;
            },
          ),
        );

        await callbackStrategy.executeCore<String>(
          (context) async => 'result',
          context,
        );

        expect(missCallbackCalled, isTrue);
        expect(missArgs?.key, equals('test-operation'));
        expect(missArgs?.context, equals(context));
      });

      test('should invoke onSet callback when caching result', () async {
        var setCallbackCalled = false;
        OnCacheSetArguments<String>? setArgs;

        final callbackStrategy = CacheStrategy<String>(
          CacheStrategyOptions(
            cache: mockCache,
            ttl: Duration(minutes: 5),
            onSet: (args) async {
              setCallbackCalled = true;
              setArgs = args;
            },
          ),
        );

        await callbackStrategy.executeCore<String>(
          (context) async => 'result',
          context,
        );

        expect(setCallbackCalled, isTrue);
        expect(setArgs?.key, equals('test-operation'));
        expect(setArgs?.value, equals('result'));
        expect(setArgs?.ttl, equals(Duration(minutes: 5)));
        expect(setArgs?.context, equals(context));
      });
    });

    group('TTL handling', () {
      test('should pass TTL to cache provider', () async {
        final ttlStrategy = CacheStrategy<String>(
          CacheStrategyOptions(
            cache: mockCache,
            ttl: Duration(minutes: 10),
          ),
        );

        await ttlStrategy.executeCore<String>(
          (context) async => 'result',
          context,
        );

        // We can't directly verify TTL was passed to mock, but we can test with real cache
        final realCache = MemoryCacheProvider();
        final realStrategy = CacheStrategy<String>(
          CacheStrategyOptions(
            cache: realCache,
            ttl: Duration(milliseconds: 100),
          ),
        );

        await realStrategy.executeCore<String>(
          (context) async => 'result',
          context,
        );

        // Verify item is cached
        expect(await realCache.get<String>('test-operation'), equals('result'));

        // Wait for expiration
        await Future.delayed(Duration(milliseconds: 150));

        // Item should be expired
        expect(await realCache.get<String>('test-operation'), isNull);
      });
    });
  });
}
