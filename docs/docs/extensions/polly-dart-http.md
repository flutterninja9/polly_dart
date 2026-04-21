---
sidebar_position: 2
---

# polly_dart_http

`polly_dart_http` integrates `package:http` with polly_dart's cancellation system. It provides `CancellableHttpClient` — a drop-in `http.BaseClient` wrapper that aborts in-flight requests when a `CancellationToken` is cancelled.

## Installation

```yaml
dependencies:
  polly_dart: ^0.0.8
  polly_dart_http: ^0.0.1
  http: ^1.2.0
```

## Quick start

```dart
import 'package:polly_dart/polly_dart.dart';
import 'package:polly_dart_http/polly_dart_http.dart';

final pipeline = ResiliencePipelineBuilder()
    .addTimeout(Duration(seconds: 5))
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 3))
    .build();

final body = await pipeline.execute((context) async {
  final client = CancellableHttpClient(token: context.cancellationToken);
  try {
    final response = await client.get(Uri.parse('https://api.example.com/data'));
    return response.body;
  } finally {
    client.close();
  }
});
```

When the `TimeoutStrategy` fires after 5 seconds, it cancels the context. `CancellableHttpClient` detects this and throws `OperationCancelledException` — the pipeline sees a timeout, not a hanging request.

## API

### `CancellableHttpClient`

```dart
CancellableHttpClient({
  http.Client? inner,      // optional inner client; defaults to http.Client()
  required CancellationToken token,
})
```

Extends `http.BaseClient`, so it works anywhere `http.Client` is accepted.

### `send()` — application-level cancellation

The overridden `send()` method races your request against `token.whenCancelled` using `Future.any`. The pipeline stops waiting immediately when cancelled; the underlying socket may still complete in the background (result is discarded).

```dart
final request = http.Request('GET', Uri.parse('https://api.example.com/data'));
final response = await client.send(request);
```

Use `send()` when you already have a `BaseRequest` object (e.g., from a middleware or interceptor chain).

### `sendAbortable()` — socket-level cancellation

For new request construction, `sendAbortable()` uses `http.AbortableRequest` internally, which closes the socket as soon as the token is cancelled. This saves bandwidth on large responses.

```dart
final response = await client.sendAbortable(
  'GET',
  Uri.parse('https://api.example.com/data'),
  headers: {'Authorization': 'Bearer $token'},
);
```

```dart
// POST with a body
final response = await client.sendAbortable(
  'POST',
  Uri.parse('https://api.example.com/users'),
  headers: {'Content-Type': 'application/json'},
  body: '{"name": "Alice"}',
);
```

**Supported `body` types:** `String`, `List<int>`, `Map<String, String>`.

## Cancellation behaviour

| Scenario | Result |
|---|---|
| Token not cancelled | Request completes normally |
| Token cancelled before `send()` | Throws `OperationCancelledException` synchronously |
| Token cancelled during `send()` | Throws `OperationCancelledException` immediately (background socket may finish) |
| Token cancelled during `sendAbortable()` | Socket is closed, throws `RequestAbortedException` from `package:http` |

## Real-world example

```dart
import 'dart:convert';
import 'package:polly_dart/polly_dart.dart';
import 'package:polly_dart_http/polly_dart_http.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  final ResiliencePipeline _pipeline;

  ApiClient()
      : _pipeline = ResiliencePipelineBuilder()
            .addTimeout(Duration(seconds: 10))
            .addRetry(RetryStrategyOptions(
              maxRetryAttempts: 3,
              delay: Duration(milliseconds: 500),
              backoffType: DelayBackoffType.exponential,
            ))
            .addCircuitBreaker()
            .build();

  Future<Map<String, dynamic>> get(String url) {
    return _pipeline.execute((context) async {
      final client = CancellableHttpClient(token: context.cancellationToken);
      try {
        // Use sendAbortable for socket-level cancellation on GET requests
        final response = await client.sendAbortable('GET', Uri.parse(url));

        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }

        final bytes = await response.stream.toBytes();
        return json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
      } finally {
        client.close();
      }
    });
  }

  Future<Map<String, dynamic>> post(String url, Map<String, dynamic> body) {
    return _pipeline.execute((context) async {
      final client = CancellableHttpClient(token: context.cancellationToken);
      try {
        final response = await client.sendAbortable(
          'POST',
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception('HTTP ${response.statusCode}');
        }

        final bytes = await response.stream.toBytes();
        return json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
      } finally {
        client.close();
      }
    });
  }
}
```

## With a custom inner client

You can supply your own `http.Client` — useful for testing or when you already have a configured client (e.g., one with custom SSL certificates):

```dart
final myClient = http.Client(); // or IOClient(HttpClient()..badCertificateCallback = ...)

final client = CancellableHttpClient(
  inner: myClient,
  token: context.cancellationToken,
);
```

## Testing

`CancellableHttpClient` is easy to test by supplying a fake inner client:

```dart
class FakeClient extends http.BaseClient {
  final Duration delay;
  FakeClient(this.delay);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future.delayed(delay);
    return http.StreamedResponse(Stream.value([]), 200, request: request);
  }
}

test('cancels mid-request', () async {
  final token = CancellationToken();
  final client = CancellableHttpClient(
    inner: FakeClient(Duration(milliseconds: 300)),
    token: token,
  );

  final future = client.send(http.Request('GET', Uri.parse('https://example.com')));

  await Future.delayed(Duration(milliseconds: 50));
  token.cancel();

  await expectLater(future, throwsA(isA<OperationCancelledException>()));
  client.close();
});
```

## Next steps

- [polly_dart_dio](./polly-dart-dio) — if you use Dio instead of `package:http`
- [Timeout Strategy](../strategies/timeout) — configure when cancellation is triggered
- [Hedging Strategy](../strategies/hedging) — parallel attempts that also cancel losers
