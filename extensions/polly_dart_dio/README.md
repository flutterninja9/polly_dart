# polly_dart_dio

[![Pub Version](https://img.shields.io/pub/v/polly_dart_dio.svg)](https://pub.dev/packages/polly_dart_dio)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

A [Dio](https://pub.dev/packages/dio) adapter for [polly_dart](https://pub.dev/packages/polly_dart) that bridges `CancellationToken` to Dio's native `CancelToken`. One method call — `context.cancellationToken.toDioCancelToken()` — and Dio closes the socket automatically when the pipeline cancels.

📚 **[Full documentation](https://polly.anirudhsingh.in/extensions/polly-dart-dio)**

## Installation

```yaml
dependencies:
  polly_dart: ^0.0.8
  polly_dart_dio: ^0.0.1
  dio: ^5.0.0
```

## Quick start

```dart
import 'package:dio/dio.dart';
import 'package:polly_dart/polly_dart.dart';
import 'package:polly_dart_dio/polly_dart_dio.dart';

final dio = Dio();

final pipeline = ResiliencePipelineBuilder()
    .addTimeout(Duration(seconds: 5))
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 3))
    .build();

final data = await pipeline.execute((context) async {
  final response = await dio.get(
    'https://api.example.com/data',
    cancelToken: context.cancellationToken.toDioCancelToken(),
  );
  return response.data;
});
```

## Features

- **Socket-level cancellation** — Dio closes the connection through its own `HttpClientAdapter` when cancelled
- **Extension method** — `toDioCancelToken()` on `CancellationToken`; no wrapper class required
- **Multiple tokens** — each call returns a distinct `CancelToken`, so parallel Dio requests all cancel together
- **One-way propagation** — cancelling a Dio token directly does not affect the polly token

## How it works

```
TimeoutStrategy fires
  └── context.cancel()
        └── CancellationToken.whenCancelled completes
              └── dio.CancelToken.cancel() called
                    └── Dio closes socket via HttpClientAdapter
```

## Parallel requests

Each call to `toDioCancelToken()` returns a distinct token, all linked to the same polly token. This makes it straightforward to cancel multiple parallel Dio requests at once:

```dart
await pipeline.execute((context) async {
  final token = context.cancellationToken;

  final results = await Future.wait([
    dio.get('/users', cancelToken: token.toDioCancelToken()),
    dio.get('/posts', cancelToken: token.toDioCancelToken()),
  ]);

  return results;
});
```

## Handling `DioException`

When Dio cancels a request it throws `DioException` with `type == DioExceptionType.cancel`. If you use Retry or Circuit Breaker, exclude cancellations from the `shouldHandle` predicate so they are not retried:

```dart
final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      shouldHandle: PredicateBuilder()
          .handleOutcome((outcome) {
            if (outcome.hasException &&
                outcome.exception is DioException &&
                (outcome.exception as DioException).type ==
                    DioExceptionType.cancel) {
              return false; // don't retry cancellations
            }
            return outcome.hasException;
          })
          .build(),
    ))
    .build();
```

## License

BSD-3-Clause — see [LICENSE](LICENSE).
