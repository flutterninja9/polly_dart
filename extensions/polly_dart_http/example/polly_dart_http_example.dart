import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:polly_dart/polly_dart.dart';
import 'package:polly_dart_http/polly_dart_http.dart';

/// polly_dart_http cancellation examples.
///
/// All examples use a fake HTTP client that simulates slow servers, so they
/// run offline and produce deterministic output.
void main() async {
  print('polly_dart_http — Cancellation Examples');
  print('=========================================\n');

  await timeoutCancellationExample();
  await manualCancellationExample();
  await parallelRequestsExample();
}

// ---------------------------------------------------------------------------
// 1. TimeoutStrategy automatically cancels the in-flight request
// ---------------------------------------------------------------------------

Future<void> timeoutCancellationExample() async {
  print('1. Timeout Cancellation');
  print('-----------------------');
  print('Pipeline: 2 s timeout. Simulated server: 5 s response time.\n');

  final pipeline = ResiliencePipelineBuilder()
      .addTimeout(Duration(seconds: 2))
      .build();

  try {
    await pipeline.execute((context) async {
      final client = CancellableHttpClient(
        inner: _SlowClient(delay: Duration(seconds: 5)),
        token: context.cancellationToken,
      );
      try {
        print('  [→] GET /data  (waiting up to 2 s before timeout fires)');
        final response =
            await client.get(Uri.parse('https://api.example.com/data'));
        return response.body;
      } finally {
        client.close();
      }
    });
  } on TimeoutRejectedException catch (e) {
    print('  [✗] $e');
    print('  [✓] Timeout fired — request aborted before server responded.\n');
  }
}

// ---------------------------------------------------------------------------
// 2. External signal cancels a request while it is in flight
// ---------------------------------------------------------------------------

Future<void> manualCancellationExample() async {
  print('2. Manual Cancellation');
  print('----------------------');
  print(
      'Request starts. Caller cancels after 1 s. Simulated server takes 5 s.\n');

  final context = ResilienceContext();

  // Simulates a UI widget disposal, user navigating away, etc.
  Timer(Duration(seconds: 1), () {
    print('  [signal] External cancellation requested.');
    context.cancel();
  });

  final pipeline = ResiliencePipelineBuilder().build();

  try {
    await pipeline.execute((ctx) async {
      final client = CancellableHttpClient(
        inner: _SlowClient(delay: Duration(seconds: 5)),
        token: ctx.cancellationToken,
      );
      try {
        print('  [→] GET /data  (will be interrupted at ~1 s)');
        await client.get(Uri.parse('https://api.example.com/data'));
      } finally {
        client.close();
      }
    }, context: context);
  } on OperationCancelledException {
    print('  [✓] Request aborted — caller no longer needs the result.\n');
  }
}

// ---------------------------------------------------------------------------
// 3. One timeout signal cancels all parallel requests simultaneously
// ---------------------------------------------------------------------------

Future<void> parallelRequestsExample() async {
  print('3. Parallel Requests — One Timeout Cancels All');
  print('-----------------------------------------------');
  print('Three requests in parallel. 2 s timeout. Each server takes 5 s.\n');

  final pipeline = ResiliencePipelineBuilder()
      .addTimeout(Duration(seconds: 2))
      .build();

  try {
    await pipeline.execute((context) async {
      final token = context.cancellationToken;

      await Future.wait([
        _fetch('/users', token),
        _fetch('/posts', token),
        _fetch('/comments', token),
      ]);
    });
  } on TimeoutRejectedException {
    print('\n  [✓] All 3 requests aborted by the same timeout signal.');
  }
}

Future<String> _fetch(String path, CancellationToken token) async {
  final client = CancellableHttpClient(
    inner: _SlowClient(delay: Duration(seconds: 5)),
    token: token,
  );
  try {
    print('  [→] GET $path');
    final response =
        await client.get(Uri.parse('https://api.example.com$path'));
    return response.body;
  } finally {
    client.close();
  }
}

// ---------------------------------------------------------------------------
// Fake HTTP client — simulates a slow server without any real network I/O.
//
// CancellableHttpClient.send() races _inner.send() against
// CancellationToken.whenCancelled via Future.any, so this mock is all
// that is needed to demonstrate application-level cancellation.
// ---------------------------------------------------------------------------

class _SlowClient extends http.BaseClient {
  final Duration delay;
  _SlowClient({required this.delay});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future.delayed(delay);
    return http.StreamedResponse(const Stream.empty(), 200);
  }
}
