import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import '../outcome.dart';
import '../resilience_context.dart';
import '../strategy.dart';

/// Configuration options for the rate limiter strategy.
class RateLimiterStrategyOptions {
  /// The type of rate limiter to use.
  final RateLimiterType type;

  /// For token bucket: Number of tokens per window.
  /// For concurrency limiter: Maximum concurrent executions.
  final int permitLimit;

  /// For token bucket: Time window for permit replenishment.
  /// For concurrency limiter: Not used.
  final Duration? window;

  /// For concurrency limiter: Maximum number of queued requests.
  final int queueLimit;

  /// For token bucket: Number of segments per window (for sliding window).
  final int segmentsPerWindow;

  /// Callback invoked when a request is rejected.
  final OnRateLimiterRejected? onRejected;

  /// Creates rate limiter options for a token bucket limiter.
  const RateLimiterStrategyOptions.tokenBucket({
    required this.permitLimit,
    required this.window,
    this.segmentsPerWindow = 1,
    this.onRejected,
  })  : type = RateLimiterType.tokenBucket,
        queueLimit = 0;

  /// Creates rate limiter options for a sliding window limiter.
  const RateLimiterStrategyOptions.slidingWindow({
    required this.permitLimit,
    required this.window,
    this.segmentsPerWindow = 4,
    this.onRejected,
  })  : type = RateLimiterType.slidingWindow,
        queueLimit = 0;

  /// Creates rate limiter options for a concurrency limiter (bulkhead).
  const RateLimiterStrategyOptions.concurrencyLimiter({
    required this.permitLimit,
    required this.queueLimit,
    this.onRejected,
  })  : type = RateLimiterType.concurrencyLimiter,
        window = null,
        segmentsPerWindow = 1;

  /// Creates rate limiter options for a fixed window limiter.
  const RateLimiterStrategyOptions.fixedWindow({
    required this.permitLimit,
    required this.window,
    this.onRejected,
  })  : type = RateLimiterType.fixedWindow,
        queueLimit = 0,
        segmentsPerWindow = 1;
}

/// Types of rate limiters.
enum RateLimiterType {
  /// Token bucket rate limiter.
  tokenBucket,

  /// Sliding window rate limiter.
  slidingWindow,

  /// Fixed window rate limiter.
  fixedWindow,

  /// Concurrency limiter (bulkhead pattern).
  concurrencyLimiter,
}

/// Signature for rate limiter rejection callback.
typedef OnRateLimiterRejected = Future<void> Function(
    OnRateLimiterRejectedArguments args);

/// Arguments passed to rate limiter rejection callbacks.
class OnRateLimiterRejectedArguments {
  /// The resilience context.
  final ResilienceContext context;

  /// The reason for rejection.
  final String reason;

  const OnRateLimiterRejectedArguments({
    required this.context,
    required this.reason,
  });
}

/// Exception thrown when rate limiter rejects an execution.
class RateLimiterRejectedException implements Exception {
  final String message;
  final String reason;

  const RateLimiterRejectedException(this.reason,
      [this.message = 'Rate limiter rejected the execution']);

  @override
  String toString() =>
      'RateLimiterRejectedException: $message (reason: $reason)';
}

/// Base interface for rate limiter implementations.
abstract class _RateLimiter {
  Future<bool> tryAcquirePermit(ResilienceContext context);
  void releasePermit();
}

/// Token bucket rate limiter implementation.
class _TokenBucketRateLimiter implements _RateLimiter {
  final int _permitLimit;
  final Duration _window;
  final int _segmentsPerWindow;

  int _availableTokens;
  DateTime _lastRefill;

  _TokenBucketRateLimiter(
      this._permitLimit, this._window, this._segmentsPerWindow)
      : _availableTokens = _permitLimit,
        _lastRefill = DateTime.now();

  @override
  Future<bool> tryAcquirePermit(ResilienceContext context) async {
    _refillTokens();

    if (_availableTokens > 0) {
      _availableTokens--;
      return true;
    }

    return false;
  }

  @override
  void releasePermit() {
    // Token bucket doesn't need to release permits
  }

  void _refillTokens() {
    final now = DateTime.now();
    final timeSinceLastRefill = now.difference(_lastRefill);
    final segmentDuration =
        Duration(milliseconds: _window.inMilliseconds ~/ _segmentsPerWindow);

    if (timeSinceLastRefill >= segmentDuration) {
      final segmentsPassed =
          timeSinceLastRefill.inMilliseconds ~/ segmentDuration.inMilliseconds;
      final tokensToAdd =
          (segmentsPassed * (_permitLimit / _segmentsPerWindow)).floor();

      _availableTokens = math.min(_permitLimit, _availableTokens + tokensToAdd);
      _lastRefill = now;
    }
  }
}

/// Sliding window rate limiter implementation.
class _SlidingWindowRateLimiter implements _RateLimiter {
  final int _permitLimit;
  final Duration _window;
  final Queue<DateTime> _requests = Queue<DateTime>();

  _SlidingWindowRateLimiter(
      this._permitLimit, this._window, int segmentsPerWindow);

  @override
  Future<bool> tryAcquirePermit(ResilienceContext context) async {
    final now = DateTime.now();
    final cutoff = now.subtract(_window);

    // Remove old requests
    while (_requests.isNotEmpty && _requests.first.isBefore(cutoff)) {
      _requests.removeFirst();
    }

    if (_requests.length < _permitLimit) {
      _requests.addLast(now);
      return true;
    }

    return false;
  }

  @override
  void releasePermit() {
    // Sliding window doesn't need to release permits
  }
}

/// Fixed window rate limiter implementation.
class _FixedWindowRateLimiter implements _RateLimiter {
  final int _permitLimit;
  final Duration _window;

  int _currentCount = 0;
  DateTime _windowStart;

  _FixedWindowRateLimiter(this._permitLimit, this._window)
      : _windowStart = DateTime.now();

  @override
  Future<bool> tryAcquirePermit(ResilienceContext context) async {
    final now = DateTime.now();

    // Check if we need to reset the window
    if (now.difference(_windowStart) >= _window) {
      _currentCount = 0;
      _windowStart = now;
    }

    if (_currentCount < _permitLimit) {
      _currentCount++;
      return true;
    }

    return false;
  }

  @override
  void releasePermit() {
    // Fixed window doesn't need to release permits
  }
}

/// Concurrency limiter (bulkhead) implementation.
class _ConcurrencyLimiter implements _RateLimiter {
  final int _permitLimit;
  final int _queueLimit;
  final Queue<Completer<bool>> _waitingQueue = Queue<Completer<bool>>();

  int _currentCount = 0;

  _ConcurrencyLimiter(this._permitLimit, this._queueLimit);

  @override
  Future<bool> tryAcquirePermit(ResilienceContext context) async {
    if (_currentCount < _permitLimit) {
      _currentCount++;
      return true;
    }

    // Check if we can queue the request
    if (_waitingQueue.length >= _queueLimit) {
      return false;
    }

    final completer = Completer<bool>();
    _waitingQueue.addLast(completer);

    // Wait for either permit availability or cancellation
    try {
      final result = await Future.any([
        completer.future,
        context.cancellationFuture.then((_) => false),
      ]);

      if (!result) {
        _waitingQueue.remove(completer);
      }

      return result;
    } catch (_) {
      _waitingQueue.remove(completer);
      return false;
    }
  }

  @override
  void releasePermit() {
    _currentCount--;

    // Notify waiting requests
    if (_waitingQueue.isNotEmpty) {
      final completer = _waitingQueue.removeFirst();
      _currentCount++;
      completer.complete(true);
    }
  }
}

/// Rate limiter resilience strategy implementation.
class RateLimiterStrategy extends ResilienceStrategy {
  final RateLimiterStrategyOptions _options;
  final _RateLimiter _rateLimiter;

  /// Creates a rate limiter strategy with the specified options.
  RateLimiterStrategy(this._options)
      : _rateLimiter = _createRateLimiter(_options);

  static _RateLimiter _createRateLimiter(RateLimiterStrategyOptions options) {
    switch (options.type) {
      case RateLimiterType.tokenBucket:
        return _TokenBucketRateLimiter(
          options.permitLimit,
          options.window!,
          options.segmentsPerWindow,
        );
      case RateLimiterType.slidingWindow:
        return _SlidingWindowRateLimiter(
          options.permitLimit,
          options.window!,
          options.segmentsPerWindow,
        );
      case RateLimiterType.fixedWindow:
        return _FixedWindowRateLimiter(
          options.permitLimit,
          options.window!,
        );
      case RateLimiterType.concurrencyLimiter:
        return _ConcurrencyLimiter(
          options.permitLimit,
          options.queueLimit,
        );
    }
  }

  @override
  Future<Outcome<T>> executeCore<T>(
    ResilienceCallback<T> callback,
    ResilienceContext context,
  ) async {
    // Try to acquire a permit
    final permitAcquired = await _rateLimiter.tryAcquirePermit(context);

    if (!permitAcquired) {
      final reason = _getRejectionReason();

      // Invoke rejection callback
      if (_options.onRejected != null) {
        await _options.onRejected!(OnRateLimiterRejectedArguments(
          context: context,
          reason: reason,
        ));
      }

      return Outcome.fromException(
        RateLimiterRejectedException(reason),
        StackTrace.current,
      );
    }

    try {
      // Execute the callback
      final result = await callback(context);
      return Outcome.fromResult(result);
    } catch (exception, stackTrace) {
      return Outcome.fromException(exception, stackTrace);
    } finally {
      // Release the permit
      _rateLimiter.releasePermit();
    }
  }

  String _getRejectionReason() {
    switch (_options.type) {
      case RateLimiterType.tokenBucket:
        return 'Token bucket limit exceeded';
      case RateLimiterType.slidingWindow:
        return 'Sliding window limit exceeded';
      case RateLimiterType.fixedWindow:
        return 'Fixed window limit exceeded';
      case RateLimiterType.concurrencyLimiter:
        return 'Concurrency limit exceeded';
    }
  }
}
