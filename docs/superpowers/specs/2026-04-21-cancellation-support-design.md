# Cancellation Support Design

**Date:** 2026-04-21  
**Branch:** feature/cancellation-support  
**Status:** Draft

---

## Problem Statement

`polly_dart` strategies (Timeout, Hedging) already signal cancellation by calling `context.cancel()`, but this only sets an internal flag — it does not actually abort in-flight HTTP requests. The missing bridge is: how does the pipeline's cancellation signal reach the underlying network layer?

The package is deliberately HTTP-agnostic (zero runtime dependencies). Any solution must preserve that contract while providing excellent DX for users who want real request cancellation.

---

## Decision: Monorepo with Core CancellationToken Enhancement

### What we're building

1. **Core enhancement (non-breaking):** Promote `CancellationToken` to a proper public class extracted from `ResilienceContext`. This becomes the typed bridge between the pipeline and any HTTP client.

2. **Monorepo structure:** The existing repo root stays the core package. A new `extensions/` folder holds separate packages (`polly_dart_http`, `polly_dart_dio`) managed by `melos`.

3. **First extension:** `polly_dart_http` — a cancellation-aware wrapper around `package:http`.

4. **Second extension:** `polly_dart_dio` — a thin bridge that converts `CancellationToken` to Dio's `CancelToken`.

### Why monorepo over monolithic

| Concern | Monorepo | Monolithic |
|---|---|---|
| Core zero-deps | ✅ Preserved | ❌ Broken the moment we add `package:http` |
| DX for Dio users | ✅ `polly_dart_dio` | ❌ Must wire manually every time |
| DX for http users | ✅ `polly_dart_http` | ❌ Same |
| Community extensibility | ✅ `polly_dart_retrofit`, etc. | ❌ Core becomes a kitchen sink |
| Release cadence | ✅ Independent per package | ❌ Coupled |
| Precedent | FlutterFire, bloc, Flame | — |

### Why monorepo over separate repos

- Developing core + extension in tandem requires atomic changes across repos
- `melos` (mature, widely used in the Dart ecosystem) makes a monorepo feel like separate repos for contributors
- Single PR can touch both core and extension when a new feature requires both

---

## Architecture

### Repository Layout

```
polly_dart/                      ← root (IS the published polly_dart core)
├── melos.yaml                   ← NEW: monorepo tooling config
├── pubspec.yaml                 ← core package (unchanged name/identity, melos dev dep added)
├── lib/                         ← core library
├── test/                        ← core tests
└── extensions/
    ├── polly_dart_http/         ← package:http adapter
    │   ├── pubspec.yaml
    │   ├── lib/
    │   │   └── polly_dart_http.dart
    │   └── test/
    └── polly_dart_dio/          ← dio adapter
        ├── pubspec.yaml
        ├── lib/
        │   └── polly_dart_dio.dart
        └── test/
```

The root itself is the core package. `melos.yaml` discovers it (`.`) plus all `extensions/*` packages. This avoids migrating existing files.

### `melos.yaml` (standalone, alongside existing `pubspec.yaml`)

We use a standalone `melos.yaml` rather than Dart pub workspaces — this keeps the SDK constraint at `^3.5.0` and avoids conflating the workspace root with the published core package. The existing root `pubspec.yaml` (name: `polly_dart`, published) is untouched.

```yaml
# melos.yaml (new file at repo root)
name: polly_dart_workspace

packages:
  - .                       # root = polly_dart core package
  - extensions/*            # all extension packages

command:
  bootstrap:
    usePubspecOverrides: true   # links local packages during development

scripts:
  test:
    description: Run tests in all packages
    exec: dart test
  analyze:
    description: Analyze all packages
    exec: dart analyze
  format:
    description: Format all packages
    exec: dart format .
  publish:check:
    description: Dry-run publish check
    exec: dart pub publish --dry-run
```

**Dev dependency added to root `pubspec.yaml`:**
```yaml
dev_dependencies:
  melos: ^6.0.0   # v6 supports standalone melos.yaml; v7 requires Dart 3.6
  lints: ^4.0.0
  test: ^1.24.0
```

> **Future:** When the project adopts Dart 3.6+, migrate to pub workspaces (`workspace:` in pubspec.yaml) and melos v7. The extension pubspecs would add a `resolution: workspace` field and the root would declare members. No structural change to files needed.

---

## Core Package Changes (polly_dart)

### 1. New: `CancellationToken` class

A standalone, publicly exported class that can be passed around independently of `ResilienceContext`. Extension packages depend only on this type.

```dart
// lib/src/cancellation_token.dart

class CancellationToken {
  bool _cancelled = false;
  final _completer = Completer<void>();

  bool get isCancelled => _cancelled;

  // Completes when cancelled — useful for racing against HTTP futures
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_cancelled) {
      _cancelled = true;
      _completer.complete();
    }
  }

  void throwIfCancelled() {
    if (_cancelled) throw OperationCancelledException();
  }
}
```

**Design notes:**
- `CancellationToken` is write-capable intentionally — the strategy layer (Timeout, Hedging) needs to cancel it. Users who receive it from `context.cancellationToken` use it read-only in practice.
- Kept separate from `OperationCancelledException` (already in `resilience_context.dart`). `OperationCancelledException` will move to its own file.
- No `CancellationTokenSource` separation (unlike C#) — the token IS the source in this design, keeping the API surface minimal for a small library.

### 2. Refactor: `ResilienceContext`

`ResilienceContext` now owns a `CancellationToken` internally and delegates to it. All existing public API is preserved — **zero breaking changes**.

```dart
class ResilienceContext {
  final CancellationToken _token = CancellationToken();

  // NEW: exposes the token for passing to HTTP clients
  CancellationToken get cancellationToken => _token;

  // Existing API unchanged — delegates to token
  bool get isCancellationRequested => _token.isCancelled;
  Future<void> get cancellationFuture => _token.whenCancelled;
  void cancel() => _token.cancel();
  void throwIfCancellationRequested() => _token.throwIfCancelled();

  // copy() creates a new context with a linked token (if parent is cancelled, child is too)
  ResilienceContext copy() {
    final child = ResilienceContext(operationKey: operationKey);
    child._properties.addAll(_properties);
    child._attemptNumber = _attemptNumber;
    if (_token.isCancelled) child._token.cancel();
    // Link: parent cancellation propagates to child
    _token.whenCancelled.then((_) => child._token.cancel());
    return child;
  }
}
```

### 3. Exports

`polly_dart.dart` adds:
```dart
export 'src/cancellation_token.dart';
```

`OperationCancelledException` moves to `cancellation_token.dart` and stays exported.

---

## Extension: `polly_dart_http`

### pubspec.yaml

```yaml
name: polly_dart_http
description: package:http adapter for polly_dart with automatic cancellation support
version: 0.0.1

environment:
  sdk: ^3.5.0

dependencies:
  polly_dart: ^0.0.8
  http: ^1.2.0
```

### API surface

```dart
// extensions/polly_dart_http/lib/polly_dart_http.dart

import 'package:http/http.dart' as http;
import 'package:polly_dart/polly_dart.dart';

/// A [http.Client] wrapper that aborts in-flight requests when a
/// [CancellationToken] is cancelled.
///
/// Usage:
/// ```dart
/// pipeline.execute((context) async {
///   final client = CancellableHttpClient(token: context.cancellationToken);
///   try {
///     final response = await client.get(Uri.parse('https://api.example.com/data'));
///     return response.body;
///   } finally {
///     client.close();
///   }
/// });
/// ```
class CancellableHttpClient extends http.BaseClient {
  final http.Client _inner;
  final CancellationToken _token;

  CancellableHttpClient({
    http.Client? inner,
    required CancellationToken token,
  })  : _inner = inner ?? http.Client(),
        _token = token;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    _token.throwIfCancelled();

    final responseFuture = _inner.send(request);

    return Future.any([
      responseFuture,
      _token.whenCancelled.then<http.StreamedResponse>(
        (_) => throw OperationCancelledException('HTTP request was cancelled'),
      ),
    ]);
  }

  @override
  void close() => _inner.close();
}
```

**Two levels of cancellation in `polly_dart_http`:**

1. **Application-level (default):** `Future.any` races the request against `_token.whenCancelled`. The pipeline sees `OperationCancelledException` immediately; the underlying socket may still complete and its result is discarded. Zero extra setup required.

2. **Socket-level (opt-in):** `package:http` v1.1+ ships `AbortableRequest`, which accepts an `abortTrigger: Future<void>` — exactly what `CancellationToken.whenCancelled` returns. This aborts the socket connection before the response body is received. Because `AbortableRequest` must be constructed fresh (it cannot wrap an existing `BaseRequest`), `CancellableHttpClient` exposes a helper:

```dart
// In CancellableHttpClient — uses AbortableRequest for true socket abort
Future<http.StreamedResponse> sendAbortable(
  String method,
  Uri url, {
  Map<String, String>? headers,
  Object? body,
}) {
  _token.throwIfCancelled();
  final request = http.AbortableRequest(
    method,
    url,
    abortTrigger: _token.whenCancelled,
  );
  if (headers != null) request.headers.addAll(headers);
  return _inner.send(request);
}
```

Most users should prefer `sendAbortable` for HTTP GET/POST calls where socket closure matters; the `send()` override handles the fallback case when passing arbitrary `BaseRequest` objects.

---

## Extension: `polly_dart_dio`

### pubspec.yaml

```yaml
name: polly_dart_dio
description: Dio adapter for polly_dart — bridges CancellationToken to Dio's CancelToken
version: 0.0.1

environment:
  sdk: ^3.5.0

dependencies:
  polly_dart: ^0.0.8
  dio: ^5.0.0
```

### API surface

```dart
// extensions/polly_dart_dio/lib/polly_dart_dio.dart

import 'package:dio/dio.dart' as dio;
import 'package:polly_dart/polly_dart.dart';

extension CancellationTokenDioExtension on CancellationToken {
  /// Converts this [CancellationToken] to a Dio [CancelToken].
  ///
  /// The returned token is cancelled when this token is cancelled.
  ///
  /// Usage:
  /// ```dart
  /// pipeline.execute((context) async {
  ///   final response = await dioClient.get(
  ///     '/data',
  ///     cancelToken: context.cancellationToken.toDioCancelToken(),
  ///   );
  ///   return response.data;
  /// });
  /// ```
  dio.CancelToken toDioCancelToken() {
    final dioToken = dio.CancelToken();
    whenCancelled.then((_) {
      if (!dioToken.isCancelled) {
        dioToken.cancel('Cancelled by polly_dart pipeline');
      }
    });
    return dioToken;
  }
}
```

This uses Dio's own `CancelToken` which properly closes the socket via Dio's `HttpClientAdapter`.

---

## Usage Examples

### With `polly_dart_http`

```dart
import 'package:polly_dart/polly_dart.dart';
import 'package:polly_dart_http/polly_dart_http.dart';

final pipeline = ResiliencePipelineBuilder()
    .addTimeout(Duration(seconds: 5))   // fires context.cancel() on timeout
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

### With `polly_dart_dio`

```dart
import 'package:polly_dart/polly_dart.dart';
import 'package:polly_dart_dio/polly_dart_dio.dart';

final dio = Dio();
final pipeline = ResiliencePipelineBuilder()
    .addTimeout(Duration(seconds: 5))
    .build();

final data = await pipeline.execute((context) async {
  final response = await dio.get(
    '/data',
    cancelToken: context.cancellationToken.toDioCancelToken(),
  );
  return response.data;
});
```

### Manual (no extension package)

```dart
// Users can always wire cancellation manually using cancellationFuture
final pipeline = ResiliencePipelineBuilder()
    .addTimeout(Duration(seconds: 5))
    .build();

final data = await pipeline.execute((context) async {
  final client = http.Client();
  context.cancellationFuture.then((_) => client.close());
  try {
    return await client.get(Uri.parse('https://api.example.com/data'));
  } finally {
    client.close();
  }
});
```

---

## Error Handling

- `CancellationToken.throwIfCancelled()` throws `OperationCancelledException`
- `OperationCancelledException` moves to `cancellation_token.dart` (still exported from `polly_dart.dart`)
- `polly_dart_dio`: Dio throws `DioException` with type `cancel` — extension packages map this to `OperationCancelledException` via error interceptor (optional, documented)
- `TimeoutStrategy` already calls `context.cancel()` → token is cancelled → `CancellableHttpClient` / `toDioCancelToken()` react immediately

---

## Testing Plan

### Core tests (existing + new)
- `CancellationToken`: unit test all state transitions
- `ResilienceContext`: verify `cancellationToken` property, verify `copy()` propagates cancellation from parent to child
- `TimeoutStrategy`: verify that cancellation token is cancelled when timeout fires (existing test coverage expands)

### `polly_dart_http` tests
- Mock `http.Client` to verify `send()` is raced against `whenCancelled`
- Verify `OperationCancelledException` is thrown when token is pre-cancelled before `send()`
- Integration: `CancellableHttpClient` + `TimeoutStrategy` pipeline

### `polly_dart_dio` tests
- Verify `toDioCancelToken()` is cancelled when `CancellationToken.cancel()` is called
- Verify the Dio token state matches polly token state at the moment of cancellation

---

## Versioning

| Package | Version |
|---|---|
| `polly_dart` (core) | `0.0.8` — `CancellationToken` extraction, `cancellationToken` on `ResilienceContext` |
| `polly_dart_http` | `0.0.1` — initial release |
| `polly_dart_dio` | `0.0.1` — initial release |

The core version bump is minor (non-breaking additions only).

---

## What We're NOT Doing

- **No `CancellationTokenSource` separation**: unnecessary complexity at this scale; the token is the source.
- **No new strategy**: Cancellation is a cross-cutting concern, not a strategy. It flows through the existing context.
- **No breaking changes to core**: All existing `ResilienceContext` API preserved.
- **No `polly_dart_chopper`**: Out of scope for v1. The extension pattern is established; community can add it.
- **No CI changes yet**: melos adds `melos bootstrap` and `melos run test:all` — CI update is a separate PR.
