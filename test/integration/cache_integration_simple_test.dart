import 'package:polly_dart/polly_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Cache Integration with Pipeline Builder', () {
    test('should add memory cache strategy using addMemoryCache', () async {
      final pipeline = ResiliencePipelineBuilder()
          .addMemoryCache<String>(
            ttl: Duration(seconds: 30),
            maxSize: 100,
          )
          .build();

      var executionCount = 0;

      // First execution - should execute callback and cache result
      final result1 = await pipeline.execute((context) async {
        executionCount++;
        return 'result-$executionCount';
      }, context: ResilienceContext(operationKey: 'test-key'));

      expect(result1, equals('result-1'));
      expect(executionCount, equals(1));

      // Second execution - should return cached result
      final result2 = await pipeline.execute((context) async {
        executionCount++;
        return 'result-$executionCount';
      }, context: ResilienceContext(operationKey: 'test-key'));

      expect(result2, equals('result-1')); // Same as first result
      expect(executionCount, equals(1)); // Callback not executed again
    });

    test('should add cache strategy using addCache', () async {
      final cache = MemoryCacheProvider();
      final options = CacheStrategyOptions<String>(cache: cache);

      final pipeline = ResiliencePipelineBuilder().addCache(options).build();

      var executionCount = 0;

      final result1 = await pipeline.execute((context) async {
        executionCount++;
        return 'cached-result';
      }, context: ResilienceContext(operationKey: 'cache-test'));

      expect(result1, equals('cached-result'));
      expect(executionCount, equals(1));

      // Verify value is in cache
      expect(await cache.get<String>('cache-test'), equals('cached-result'));

      // Second execution should use cache
      final result2 = await pipeline.execute((context) async {
        executionCount++;
        return 'new-result';
      }, context: ResilienceContext(operationKey: 'cache-test'));

      expect(result2, equals('cached-result'));
      expect(executionCount, equals(1));
    });

    test('should bypass cache for null operation keys', () async {
      final pipeline =
          ResiliencePipelineBuilder().addMemoryCache<String>().build();

      var executionCount = 0;

      // Execute without operation key
      final result1 = await pipeline.execute((context) async {
        executionCount++;
        return 'result-$executionCount';
      }, context: ResilienceContext()); // No operation key

      // Execute again without operation key
      final result2 = await pipeline.execute((context) async {
        executionCount++;
        return 'result-$executionCount';
      }, context: ResilienceContext()); // No operation key

      expect(result1, equals('result-1'));
      expect(result2, equals('result-2'));
      expect(executionCount, equals(2)); // Both executions should run
    });
  });
}
