import 'package:polly_dart/src/caching/cache_metrics.dart';
import 'package:polly_dart/src/caching/memory_cache_provider.dart';
import 'package:test/test.dart';

void main() {
  group('CacheMetrics', () {
    late CacheMetrics metrics;

    setUp(() {
      metrics = CacheMetrics();
    });

    test('should start with zero metrics', () {
      expect(metrics.hits, equals(0));
      expect(metrics.misses, equals(0));
      expect(metrics.sets, equals(0));
      expect(metrics.totalOperations, equals(0));
      expect(metrics.hitRatio, equals(0.0));
    });

    test('should record hits correctly', () {
      metrics.recordHit();
      metrics.recordHit(Duration(microseconds: 100));

      expect(metrics.hits, equals(2));
      expect(metrics.misses, equals(0));
      expect(metrics.totalOperations, equals(2));
      expect(metrics.hitRatio, equals(1.0));
      expect(metrics.averageHitTime.inMicroseconds, equals(50));
    });

    test('should record misses correctly', () {
      metrics.recordMiss();
      metrics.recordMiss(Duration(microseconds: 200));

      expect(metrics.hits, equals(0));
      expect(metrics.misses, equals(2));
      expect(metrics.totalOperations, equals(2));
      expect(metrics.hitRatio, equals(0.0));
      expect(metrics.averageMissTime.inMicroseconds, equals(100));
    });

    test('should calculate hit ratio correctly', () {
      metrics.recordHit();
      metrics.recordHit();
      metrics.recordMiss();

      expect(metrics.hits, equals(2));
      expect(metrics.misses, equals(1));
      expect(metrics.totalOperations, equals(3));
      expect(metrics.hitRatio, closeTo(0.667, 0.001));
    });

    test('should record sets correctly', () {
      metrics.recordSet();
      metrics.recordSet();

      expect(metrics.sets, equals(2));
    });

    test('should reset all metrics', () {
      metrics.recordHit();
      metrics.recordMiss();
      metrics.recordSet();

      metrics.reset();

      expect(metrics.hits, equals(0));
      expect(metrics.misses, equals(0));
      expect(metrics.sets, equals(0));
      expect(metrics.totalOperations, equals(0));
      expect(metrics.hitRatio, equals(0.0));
    });

    test('should provide meaningful toString', () {
      metrics.recordHit(Duration(microseconds: 50));
      metrics.recordMiss(Duration(microseconds: 150));
      metrics.recordSet();

      final str = metrics.toString();
      expect(str, contains('hits: 1'));
      expect(str, contains('misses: 1'));
      expect(str, contains('sets: 1'));
      expect(str, contains('hitRatio: 50.0%'));
    });
  });

  group('MetricsCollectingCacheProvider', () {
    late MemoryCacheProvider baseProvider;
    late MetricsCollectingCacheProvider metricsProvider;

    setUp(() {
      baseProvider = MemoryCacheProvider();
      metricsProvider = MetricsCollectingCacheProvider(baseProvider);
    });

    test('should collect metrics on get operations', () async {
      // Cache miss
      final result1 = await metricsProvider.get<String>('key1');
      expect(result1, isNull);
      expect(metricsProvider.metrics.misses, equals(1));
      expect(metricsProvider.metrics.hits, equals(0));

      // Set value
      await metricsProvider.set('key1', 'value1');
      expect(metricsProvider.metrics.sets, equals(1));

      // Cache hit
      final result2 = await metricsProvider.get<String>('key1');
      expect(result2, equals('value1'));
      expect(metricsProvider.metrics.hits, equals(1));
      expect(metricsProvider.metrics.misses, equals(1));
    });

    test('should track timing information', () async {
      await metricsProvider.get<String>('missing-key');
      await metricsProvider.set('key1', 'value1');
      await metricsProvider.get<String>('key1');

      final metrics = metricsProvider.metrics;
      expect(metrics.averageHitTime.inMicroseconds, greaterThan(0));
      expect(metrics.averageMissTime.inMicroseconds, greaterThan(0));
    });

    test('should delegate all operations to inner provider', () async {
      await metricsProvider.set('key1', 'value1');
      await metricsProvider.set('key2', 'value2');

      expect(await metricsProvider.get<String>('key1'), equals('value1'));
      expect(await metricsProvider.get<String>('key2'), equals('value2'));
      expect(metricsProvider.size, equals(2));

      await metricsProvider.remove('key1');
      expect(await metricsProvider.get<String>('key1'), isNull);
      expect(metricsProvider.size, equals(1));

      await metricsProvider.clear();
      expect(await metricsProvider.get<String>('key2'), isNull);
      expect(metricsProvider.size, equals(0));
    });

    test('should handle TTL correctly', () async {
      await metricsProvider.set('key1', 'value1',
          ttl: Duration(milliseconds: 50));

      // Immediate read should hit
      expect(await metricsProvider.get<String>('key1'), equals('value1'));
      expect(metricsProvider.metrics.hits, equals(1));

      // Wait for TTL to expire
      await Future.delayed(Duration(milliseconds: 100));

      // Should be a miss due to expiration
      expect(await metricsProvider.get<String>('key1'), isNull);
      expect(metricsProvider.metrics.misses, equals(1));
    });

    test('should maintain separate metrics instances', () async {
      final provider2 = MetricsCollectingCacheProvider(MemoryCacheProvider());

      await metricsProvider.get<String>('key1');
      await provider2.get<String>('key1');

      expect(metricsProvider.metrics.misses, equals(1));
      expect(provider2.metrics.misses, equals(1));

      // Metrics should be independent
      expect(metricsProvider.metrics, isNot(same(provider2.metrics)));
    });
  });
}
