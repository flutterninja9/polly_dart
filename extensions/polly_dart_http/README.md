# polly_dart_http

[![Pub Version](https://img.shields.io/pub/v/polly_dart_http.svg)](https://pub.dev/packages/polly_dart_http)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

A [`package:http`](https://pub.dev/packages/http) adapter for [polly_dart](https://pub.dev/packages/polly_dart) that enables real HTTP request cancellation. When a polly_dart strategy cancels an operation (e.g. Timeout fires, Hedging picks a winner), `CancellableHttpClient` aborts the in-flight request immediately.

📚 **[Full documentation](https://polly.anirudhsingh.in/extensions/polly-dart-http)**

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

## Features

- **`send()`** — application-level cancellation via `Future.any`; the pipeline stops waiting immediately when the token is cancelled
- **`sendAbortable()`** — socket-level cancellation via `http.AbortableRequest`; the connection is closed as soon as the token is cancelled, saving bandwidth on large responses
- Drop-in `http.BaseClient` subclass — works anywhere `http.Client` is accepted
- Zero configuration — just pass `context.cancellationToken` and go

## How it works

Every `ResilienceContext` exposes a `CancellationToken` via `context.cancellationToken`. When a strategy cancels the context (e.g. `TimeoutStrategy` after 5 s), the token's `whenCancelled` future completes. `CancellableHttpClient` races your request against that future and throws `OperationCancelledException` the moment it fires.

```
TimeoutStrategy fires
  └── context.cancel()
        └── CancellationToken.whenCancelled completes
              └── CancellableHttpClient throws OperationCancelledException
```

## `send()` vs `sendAbortable()`

| Method | Cancellation level | When to use |
|---|---|---|
| `send(request)` | Application-level | You already have a `BaseRequest` object |
| `sendAbortable(method, url, ...)` | Socket-level | You're constructing the request here |

```dart
// Application-level — existing BaseRequest
final response = await client.send(existingRequest);

// Socket-level — new request (preferred for GET/POST/etc.)
final response = await client.sendAbortable(
  'POST',
  Uri.parse('https://api.example.com/users'),
  headers: {'Content-Type': 'application/json'},
  body: '{"name": "Alice"}',
);
```

## License

BSD-3-Clause — see [LICENSE](LICENSE).
