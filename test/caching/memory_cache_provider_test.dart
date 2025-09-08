import 'dart:async';

import 'package:polly_dart/src/caching/memory_cache_provider.dart';
import 'package:test/test.dart';

void main() {
  group('MemoryCacheProvider', () {
    late MemoryCacheProvider cache;

    setUp(() {
      cache = MemoryCacheProvider();
    });

    tearDown(() {
      cache.dispose();
    });

    group('Basic operations', () {
      test('should store and retrieve values', () async {
        await cache.set('key1', 'value1');
        final result = await cache.get<String>('key1');
        expect(result, equals('value1'));
      });

      test('should return null for non-existent keys', () async {
        final result = await cache.get<String>('non-existent');
        expect(result, isNull);
      });

      test('should remove values', () async {
        await cache.set('key1', 'value1');
        await cache.remove('key1');
        final result = await cache.get<String>('key1');
        expect(result, isNull);
      });

      test('should clear all values', () async {
        await cache.set('key1', 'value1');
        await cache.set('key2', 'value2');
        await cache.clear();

        expect(await cache.get<String>('key1'), isNull);
        expect(await cache.get<String>('key2'), isNull);
        expect(cache.size, equals(0));
      });

      test('should track cache size', () async {
        expect(cache.size, equals(0));

        await cache.set('key1', 'value1');
        expect(cache.size, equals(1));

        await cache.set('key2', 'value2');
        expect(cache.size, equals(2));

        await cache.remove('key1');
        expect(cache.size, equals(1));
      });
    });

    group('TTL (Time-To-Live)', () {
      test('should expire entries after TTL', () async {
        cache = MemoryCacheProvider(defaultTtl: Duration(milliseconds: 100));

        await cache.set('key1', 'value1');
        expect(await cache.get<String>('key1'), equals('value1'));

        // Wait for expiration
        await Future.delayed(Duration(milliseconds: 150));
        expect(await cache.get<String>('key1'), isNull);
      });

      test('should use custom TTL over default', () async {
        cache = MemoryCacheProvider(defaultTtl: Duration(seconds: 10));

        await cache.set('key1', 'value1', ttl: Duration(milliseconds: 100));
        expect(await cache.get<String>('key1'), equals('value1'));

        // Wait for custom TTL expiration
        await Future.delayed(Duration(milliseconds: 150));
        expect(await cache.get<String>('key1'), isNull);
      });

      test('should not expire when no TTL is set', () async {
        await cache.set('key1', 'value1');

        // Wait a bit
        await Future.delayed(Duration(milliseconds: 50));
        expect(await cache.get<String>('key1'), equals('value1'));
      });
    });

    group('LRU eviction', () {
      test('should evict least recently used entries when max size is reached',
          () async {
        cache = MemoryCacheProvider(maxSize: 2);

        await cache.set('key1', 'value1');
        await cache.set('key2', 'value2');
        expect(cache.size, equals(2));

        // Access key1 to make it more recently used
        await cache.get<String>('key1');

        // Add a third item, should evict key2 (least recently used)
        await cache.set('key3', 'value3');
        expect(cache.size, equals(2));

        expect(await cache.get<String>('key1'),
            equals('value1')); // Should still exist
        expect(await cache.get<String>('key2'), isNull); // Should be evicted
        expect(
            await cache.get<String>('key3'), equals('value3')); // Should exist
      });

      test('should maintain LRU order correctly', () async {
        cache = MemoryCacheProvider(maxSize: 3);

        // Add three items
        await cache.set('key1', 'value1');
        await cache.set('key2', 'value2');
        await cache.set('key3', 'value3');

        // Access key1 to make it most recent
        await cache.get<String>('key1');

        // Add fourth item, should evict key2
        await cache.set('key4', 'value4');

        expect(
            await cache.get<String>('key1'), equals('value1')); // Most recent
        expect(await cache.get<String>('key2'), isNull); // Evicted
        expect(
            await cache.get<String>('key3'), equals('value3')); // Still there
        expect(await cache.get<String>('key4'), equals('value4')); // New item
      });
    });

    group('Background cleanup', () {
      test('should clean up expired entries periodically', () async {
        cache = MemoryCacheProvider(
          defaultTtl: Duration(milliseconds: 50),
          cleanupInterval: Duration(milliseconds: 100),
        );

        await cache.set('key1', 'value1');
        await cache.set('key2', 'value2');
        expect(cache.size, equals(2));

        // Wait for items to expire and cleanup to run
        await Future.delayed(Duration(milliseconds: 200));

        // Items should be cleaned up
        expect(cache.size, equals(0));
      });
    });

    group('Type safety', () {
      test('should handle different value types', () async {
        await cache.set('string', 'text');
        await cache.set('int', 42);
        await cache.set('list', [1, 2, 3]);
        await cache.set('map', {'key': 'value'});

        expect(await cache.get<String>('string'), equals('text'));
        expect(await cache.get<int>('int'), equals(42));
        expect(await cache.get<List<int>>('list'), equals([1, 2, 3]));
        expect(await cache.get<Map<String, String>>('map'),
            equals({'key': 'value'}));
      });

      test('should return null for wrong type cast', () async {
        await cache.set('string', 'text');

        // This should return null due to type mismatch
        final result = await cache.get<int>('string');
        expect(result, isNull);
      });
    });
  });
}
