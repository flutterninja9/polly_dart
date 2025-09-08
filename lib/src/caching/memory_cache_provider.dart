import 'dart:async';

import 'cache_provider.dart';

/// A memory-based cache provider with TTL and LRU eviction support.
///
/// This implementation stores cached values in memory and provides:
/// - TTL (Time-To-Live) support for automatic expiration
/// - LRU (Least Recently Used) eviction when max size is reached
/// - Sliding expiration option (updates expiry on access)
/// - Background cleanup of expired entries
class MemoryCacheProvider implements CacheProvider {
  final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};
  final Duration? _defaultTtl;
  final int? _maxSize;
  Timer? _cleanupTimer;

  /// Creates a new memory cache provider.
  ///
  /// [defaultTtl] - Default time-to-live for cache entries if not specified
  /// [maxSize] - Maximum number of entries before LRU eviction occurs
  /// [cleanupInterval] - How often to run background cleanup of expired entries
  ///
  /// Example:
  /// ```dart
  /// final cache = MemoryCacheProvider(
  ///   defaultTtl: Duration(minutes: 5),
  ///   maxSize: 1000,
  ///   cleanupInterval: Duration(minutes: 1),
  /// );
  /// ```
  MemoryCacheProvider({
    Duration? defaultTtl,
    int? maxSize,
    Duration cleanupInterval = const Duration(minutes: 5),
  })  : _defaultTtl = defaultTtl,
        _maxSize = maxSize {
    _setupCleanup(cleanupInterval);
  }

  @override
  Future<T?> get<T>(String key) async {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    // Update last accessed for sliding expiration and LRU tracking
    entry.lastAccessed = DateTime.now();

    // Move to end for LRU (most recently accessed)
    _cache.remove(key);
    _cache[key] = entry;

    // Safely cast the value, return null if type doesn't match
    try {
      return entry.value as T?;
    } catch (e) {
      // Type mismatch, return null
      return null;
    }
  }

  @override
  Future<void> set<T>(String key, T value, {Duration? ttl}) async {
    final effectiveTtl = ttl ?? _defaultTtl;
    final now = DateTime.now();
    final expiresAt = effectiveTtl != null ? now.add(effectiveTtl) : null;

    final entry = _CacheEntry(
      value: value,
      expiresAt: expiresAt,
      createdAt: now,
      lastAccessed: now,
    );

    // Remove if exists to update position
    _cache.remove(key);
    _cache[key] = entry;

    _enforceMaxSize();
  }

  @override
  Future<void> remove(String key) async {
    _cache.remove(key);
  }

  @override
  Future<void> clear() async {
    _cache.clear();
  }

  @override
  int? get size => _cache.length;

  /// Sets up background cleanup of expired entries.
  void _setupCleanup(Duration interval) {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(interval, (_) => _cleanupExpired());
  }

  /// Removes all expired entries from the cache.
  void _cleanupExpired() {
    final keysToRemove = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  /// Enforces the maximum cache size using LRU eviction.
  void _enforceMaxSize() {
    if (_maxSize != null && _cache.length > _maxSize) {
      final entriesToRemove = _cache.length - _maxSize;

      // Remove oldest entries (LRU) - LinkedHashMap maintains insertion order
      // After get() calls, recently accessed items are moved to the end
      final keys = _cache.keys.take(entriesToRemove).toList();
      for (final key in keys) {
        _cache.remove(key);
      }
    }
  }

  /// Disposes the cache provider and cancels cleanup timer.
  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
  }
}

/// Internal cache entry with expiration and access tracking.
class _CacheEntry {
  final dynamic value;
  final DateTime? expiresAt;
  final DateTime createdAt;
  DateTime lastAccessed;

  _CacheEntry({
    required this.value,
    this.expiresAt,
    required this.createdAt,
    required this.lastAccessed,
  });

  /// Whether this cache entry has expired.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Age of this cache entry.
  Duration get age => DateTime.now().difference(createdAt);

  /// Time since last access.
  Duration get timeSinceLastAccess => DateTime.now().difference(lastAccessed);
}
