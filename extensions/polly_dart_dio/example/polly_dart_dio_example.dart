import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:polly_dart/polly_dart.dart';
import 'package:polly_dart_dio/polly_dart_dio.dart';

/// polly_dart_dio cancellation examples.
///
/// All examples use a fake Dio [HttpClientAdapter] that simulates a slow
/// server and properly honours the cancel signal, so they run offline and
/// produce deterministic output.
void main() async {
  print('polly_dart_dio — Cancellation Examples');
  print('========================================\n');

  await timeoutCancellationExample();
  await manualCancellationExample();
  await parallelRequestsExample();
  await retryExcludesCancellationsExample();
}

// ---------------------------------------------------------------------------
// 1. TimeoutStrategy automatically cancels the Dio request
// ---------------------------------------------------------------------------

Future<void> timeoutCancellationExample() async {
  print('1. Timeout Cancellation');
  print('-----------------------');
  print('Pipeline: 2 s timeout. Simulated server: 5 s response time.\n');

  final dio = _slowDio(delay: Duration(seconds: 5));

  final pipeline = ResiliencePipelineBuilder()
      .addTimeout(Duration(seconds: 2))
      .build();

  try {
    await pipeline.execute((context) async {
      print('  [→] GET /data  (waiting up to 2 s before timeout fires)');
      final response = await dio.get(
        'https://api.example.com/data',
        // toDioCancelToken() links Dio's socket-level abort to the polly token.
        // When TimeoutStrategy calls context.cancel(), the Dio socket closes.
        cancelToken: context.cancellationToken.toDioCancelToken(),
      );
      return response.data;
    });
  } on TimeoutRejectedException catch (e) {
    // TimeoutStrategy's timer branch wins the internal Future.any race and
    // throws TimeoutRejectedException before Dio's DioException surfaces.
    print('  [✗] $e');
    print('  [✓] Timeout fired — Dio socket closed via CancelToken.\n');
  }
}

// ---------------------------------------------------------------------------
// 2. External signal cancels a Dio request while it is in flight
// ---------------------------------------------------------------------------

Future<void> manualCancellationExample() async {
  print('2. Manual Cancellation');
  print('----------------------');
  print(
      'Request starts. Caller cancels after 1 s. Simulated server takes 5 s.\n');

  final context = ResilienceContext();
  final dio = _slowDio(delay: Duration(seconds: 5));

  // Simulates a UI widget disposal, user navigating away, etc.
  Timer(Duration(seconds: 1), () {
    print('  [signal] External cancellation requested.');
    context.cancel();
  });

  final pipeline = ResiliencePipelineBuilder().build();

  try {
    await pipeline.execute((ctx) async {
      print('  [→] GET /data  (will be interrupted at ~1 s)');
      await dio.get(
        'https://api.example.com/data',
        cancelToken: ctx.cancellationToken.toDioCancelToken(),
      );
    }, context: context);
  } on DioException catch (e) {
    if (e.type == DioExceptionType.cancel) {
      // With no TimeoutStrategy, context.cancel() propagates through
      // CancelToken → adapter → DioException.cancel.
      print('  [✓] DioException.cancel — Dio socket closed cleanly.\n');
    } else {
      rethrow;
    }
  }
}

// ---------------------------------------------------------------------------
// 3. One timeout signal cancels all parallel Dio requests simultaneously
// ---------------------------------------------------------------------------

Future<void> parallelRequestsExample() async {
  print('3. Parallel Requests — One Timeout Cancels All');
  print('-----------------------------------------------');
  print('Three Dio requests in parallel. 2 s timeout. Each takes 5 s.\n');

  final dio = _slowDio(delay: Duration(seconds: 5));

  final pipeline = ResiliencePipelineBuilder()
      .addTimeout(Duration(seconds: 2))
      .build();

  try {
    await pipeline.execute((context) async {
      final token = context.cancellationToken;
      print('  [→] GET /users, /posts, /comments  (3 parallel requests)');

      // Each call to toDioCancelToken() returns a distinct CancelToken, all
      // linked to the same polly token — one cancel signal closes all sockets.
      await Future.wait([
        dio.get('/users', cancelToken: token.toDioCancelToken()),
        dio.get('/posts', cancelToken: token.toDioCancelToken()),
        dio.get('/comments', cancelToken: token.toDioCancelToken()),
      ]);
    });
  } on TimeoutRejectedException {
    print('\n  [✓] All 3 requests cancelled by the same timeout signal.');
  } on DioException catch (e) {
    if (e.type == DioExceptionType.cancel) {
      print('\n  [✓] All 3 requests cancelled by the same timeout signal.');
    } else {
      rethrow;
    }
  }

  print('');
}

// ---------------------------------------------------------------------------
// 4. Retry pipeline — exclude DioException.cancel so cancellations are never
//    retried (retrying a cancelled request would silently re-open a connection
//    the caller already gave up on).
// ---------------------------------------------------------------------------

Future<void> retryExcludesCancellationsExample() async {
  print('4. Retry Excludes Cancellations');
  print('--------------------------------');
  print('Timeout cancels the first attempt — Retry must NOT fire.\n');

  final dio = _slowDio(delay: Duration(seconds: 5));
  var attempts = 0;

  final pipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions(
        maxRetryAttempts: 5,
        onRetry: (args) async =>
            print('  [retry] attempt ${args.attemptNumber + 1} — should not happen'),
        shouldHandle: PredicateBuilder()
            .handleOutcome((outcome) {
              if (!outcome.hasException) return false;
              final e = outcome.exception;
              // Never retry a cancellation or a timeout — these are intentional
              // terminal signals, not transient failures worth retrying.
              if (e is TimeoutRejectedException) return false;
              if (e is DioException && e.type == DioExceptionType.cancel) {
                return false;
              }
              if (e is OperationCancelledException) return false;
              return true;
            })
            .build(),
      ))
      .addTimeout(Duration(seconds: 2))
      .build();

  try {
    await pipeline.execute((context) async {
      attempts++;
      print('  [→] attempt $attempts — GET /data  (server takes 5 s)');
      await dio.get(
        'https://api.example.com/data',
        cancelToken: context.cancellationToken.toDioCancelToken(),
      );
    });
  } on TimeoutRejectedException {
    print(
        '  [✓] Timed out after $attempts attempt(s) — Retry correctly did not fire.');
  } on DioException catch (e) {
    if (e.type == DioExceptionType.cancel) {
      print(
          '  [✓] Cancelled after $attempts attempt(s) — Retry correctly did not fire.');
    } else {
      rethrow;
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [Dio] instance backed by a fake adapter that simulates a slow
/// server. The adapter races the response delay against [cancelFuture],
/// mirroring the behaviour of a real [HttpClientAdapter].
Dio _slowDio({required Duration delay}) {
  return Dio()..httpClientAdapter = _SlowAdapter(delay: delay);
}

class _SlowAdapter implements HttpClientAdapter {
  final Duration delay;
  _SlowAdapter({required this.delay});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final futures = <Future<bool>>[
      Future.delayed(delay, () => true),
    ];
    if (cancelFuture != null) {
      futures.add(cancelFuture.then((_) => false));
    }

    final completed = await Future.any(futures);

    if (!completed) {
      throw DioException(
        type: DioExceptionType.cancel,
        requestOptions: options,
        message: 'Request cancelled by polly_dart',
      );
    }

    return ResponseBody.fromString('{"data":"ok"}', 200);
  }

  @override
  void close({bool force = false}) {}
}
