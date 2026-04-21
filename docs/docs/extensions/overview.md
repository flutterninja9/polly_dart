---
sidebar_position: 1
---

# Extensions Overview

Polly Dart's core package is deliberately HTTP-agnostic — it has zero runtime dependencies and works with any async Dart code. Extensions are separate packages that bridge the core's `CancellationToken` to specific HTTP clients, so you only pay for what you use.

## Why extensions?

When a `TimeoutStrategy` fires or `HedgingStrategy` picks a winner, the pipeline calls `context.cancel()`. Without an extension, that signal stays inside the pipeline — the underlying HTTP socket keeps running until it resolves on its own. Extensions wire the cancellation signal directly into your HTTP client so the connection is actually aborted.

## Available extensions

| Package | HTTP client | Cancellation mechanism | pub.dev |
|---|---|---|---|
| [`polly_dart_http`](./polly-dart-http) | `package:http` | `AbortableRequest` (socket-level) + `Future.any` | coming soon |
| [`polly_dart_dio`](./polly-dart-dio) | `dio` | `CancelToken` (socket-level via Dio adapter) | coming soon |

## How cancellation flows

```
ResiliencePipeline
  └── TimeoutStrategy fires after 5s
        └── context.cancel()
              └── CancellationToken.whenCancelled completes
                    ├── CancellableHttpClient → Future.any wins → throws OperationCancelledException
                    └── toDioCancelToken()  → dio CancelToken.cancel() → socket closed
```

## The CancellationToken

Every `ResilienceContext` exposes a `CancellationToken` via `context.cancellationToken`. This is the object you pass to an extension:

```dart
final pipeline = ResiliencePipelineBuilder()
    .addTimeout(Duration(seconds: 5))
    .build();

await pipeline.execute((context) async {
  // Pass context.cancellationToken to your HTTP client adapter
  final token = context.cancellationToken;

  // token.isCancelled      — sync check
  // token.whenCancelled    — Future<void> that completes on cancel
  // token.throwIfCancelled() — throws OperationCancelledException if cancelled
});
```

You can also wire it manually without an extension package:

```dart
await pipeline.execute((context) async {
  final client = http.Client();
  // Close the client when the pipeline cancels
  context.cancellationFuture.then((_) => client.close());
  try {
    return await client.get(Uri.parse('https://api.example.com/data'));
  } finally {
    client.close();
  }
});
```

## Installation

Each extension is a separate pub package. Add only what you need:

```yaml
dependencies:
  polly_dart: ^0.0.8

  # Add one or both:
  polly_dart_http: ^0.0.1   # for package:http
  polly_dart_dio: ^0.0.1    # for dio
```
