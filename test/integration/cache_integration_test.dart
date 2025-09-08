import 'package:polly_dart/polly_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Cache Integration Tests', () {
    late MemoryCacheProvider cacheProvider;
    late ResiliencePipeline pipeline;

    setUp(() {
      cacheProvider = MemoryCacheProvider(
        maxSize: 100,
        defaultTtl: Duration(minutes: 5),
      );
    });

    tearDown(() async {
      await cacheProvider.clear();
    });

    test('basic cache functionality', () async {
      pipeline = ResiliencePipelineBuilder()
          .addCache(CacheStrategyOptions(
            cache: cacheProvider,
            keyGenerator: (context) => 'basic-test',
          ))
          .build();

      var callCount = 0;

      // First call - should execute and cache
      final result1 = await pipeline.execute<String>((context) async {
        callCount++;
        return 'result-$callCount';
      });

      expect(result1, equals('result-1'));
      expect(callCount, equals(1));

      // Second call - should use cache
      final result2 = await pipeline.execute<String>((context) async {
        callCount++;
        return 'result-$callCount';
      });

      expect(result2, equals('result-1')); // Same result from cache
      expect(callCount, equals(1)); // Callback not called again
    });

    test('cache with custom key generation', () async {
      pipeline = ResiliencePipelineBuilder()
          .addCache(CacheStrategyOptions(
            cache: cacheProvider,
            keyGenerator: (context) {
              final userId = context.getProperty<String>('userId');
              return 'user:$userId';
            },
          ))
          .build();

      // Create contexts with different user IDs
      final context1 = ResilienceContext()..setProperty('userId', '123');
      final context2 = ResilienceContext()..setProperty('userId', '456');

      var callCount = 0;

      // First call with user 123
      final result1 = await pipeline.execute<String>((context) async {
        callCount++;
        final userId = context.getProperty<String>('userId');
        return 'data-for-$userId';
      }, context: context1);

      expect(result1, equals('data-for-123'));
      expect(callCount, equals(1));

      // Second call with user 456 - different key, should execute
      final result2 = await pipeline.execute<String>((context) async {
        callCount++;
        final userId = context.getProperty<String>('userId');
        return 'data-for-$userId';
      }, context: context2);

      expect(result2, equals('data-for-456'));
      expect(callCount, equals(2));

      // Third call with user 123 again - should use cache
      final result3 = await pipeline.execute<String>((context) async {
        callCount++;
        final userId = context.getProperty<String>('userId');
        return 'fresh-data-for-$userId';
      }, context: context1);

      expect(result3, equals('data-for-123')); // From cache
      expect(callCount, equals(2)); // Callback not called
    });

    test('cache with TTL expiration', () async {
      pipeline = ResiliencePipelineBuilder()
          .addCache(CacheStrategyOptions(
            cache: cacheProvider,
            keyGenerator: (context) => 'ttl-test',
            ttl: Duration(milliseconds: 100),
          ))
          .build();

      var callCount = 0;

      // First call
      final result1 = await pipeline.execute<String>((context) async {
        callCount++;
        return 'result-$callCount';
      });

      expect(result1, equals('result-1'));
      expect(callCount, equals(1));

      // Wait for TTL to expire
      await Future.delayed(Duration(milliseconds: 150));

      // Second call - cache should be expired, execute again
      final result2 = await pipeline.execute<String>((context) async {
        callCount++;
        return 'result-$callCount';
      });

      expect(result2, equals('result-2'));
      expect(callCount, equals(2));
    });
  });
}
