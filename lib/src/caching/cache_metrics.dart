import 'dart:async';

import 'cache_provider.dart';

/// Basic cache metrics collector
///
/// Tracks cache hits, misses, and timing information for performance monitoring.
class CacheMetrics {
  int _hits = 0;
  int _misses = 0;
  int _sets = 0;
  Duration _totalHitTime = Duration.zero;
  Duration _totalMissTime = Duration.zero;

  /// Number of cache hits
  int get hits => _hits;

  /// Number of cache misses
  int get misses => _misses;

  /// Number of cache sets
  int get sets => _sets;

  /// Total operations (hits + misses)
  int get totalOperations => _hits + _misses;

  /// Cache hit ratio (0.0 to 1.0)
  double get hitRatio => totalOperations > 0 ? _hits / totalOperations : 0.0;

  /// Average time for cache hits
  Duration get averageHitTime => _hits > 0
      ? Duration(microseconds: _totalHitTime.inMicroseconds ~/ _hits)
      : Duration.zero;

  /// Average time for cache misses
  Duration get averageMissTime => _misses > 0
      ? Duration(microseconds: _totalMissTime.inMicroseconds ~/ _misses)
      : Duration.zero;

  /// Record a cache hit
  void recordHit([Duration? responseTime]) {
    _hits++;
    if (responseTime != null) {
      _totalHitTime += responseTime;
    }
  }

  /// Record a cache miss
  void recordMiss([Duration? responseTime]) {
    _misses++;
    if (responseTime != null) {
      _totalMissTime += responseTime;
    }
  }

  /// Record a cache set
  void recordSet() {
    _sets++;
  }

  /// Reset all metrics
  void reset() {
    _hits = 0;
    _misses = 0;
    _sets = 0;
    _totalHitTime = Duration.zero;
    _totalMissTime = Duration.zero;
  }

  @override
  String toString() {
    return 'CacheMetrics(hits: $hits, misses: $misses, sets: $sets, '
        'hitRatio: ${(hitRatio * 100).toStringAsFixed(1)}%, '
        'avgHitTime: ${averageHitTime.inMicroseconds}μs, '
        'avgMissTime: ${averageMissTime.inMicroseconds}μs)';
  }
}

/// Cache provider wrapper that collects metrics
///
/// Wraps any cache provider to automatically track performance metrics.
class MetricsCollectingCacheProvider implements CacheProvider {
  final CacheProvider _inner;
  final CacheMetrics _metrics = CacheMetrics();

  /// Creates a metrics-collecting wrapper around a cache provider
  MetricsCollectingCacheProvider(this._inner);

  /// Access to the collected metrics
  CacheMetrics get metrics => _metrics;

  @override
  Future<T?> get<T>(String key) async {
    final stopwatch = Stopwatch()..start();
    final result = await _inner.get<T>(key);
    stopwatch.stop();

    if (result != null) {
      _metrics.recordHit(stopwatch.elapsed);
    } else {
      _metrics.recordMiss(stopwatch.elapsed);
    }

    return result;
  }

  @override
  Future<void> set<T>(String key, T value, {Duration? ttl}) async {
    await _inner.set<T>(key, value, ttl: ttl);
    _metrics.recordSet();
  }

  @override
  Future<void> remove(String key) async {
    await _inner.remove(key);
  }

  @override
  Future<void> clear() async {
    await _inner.clear();
  }

  @override
  int? get size => _inner.size;
}
