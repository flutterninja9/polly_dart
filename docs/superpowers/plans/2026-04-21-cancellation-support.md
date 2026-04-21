# Cancellation Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real in-flight HTTP request cancellation to polly_dart by promoting `CancellationToken` to a public type, refactoring `ResilienceContext` to use it, converting the repo to a melos monorepo, and shipping two extension packages (`polly_dart_http`, `polly_dart_dio`).

**Architecture:** `CancellationToken` becomes a first-class public type in the core package — a tiny, dependency-free bridge between the pipeline's cancellation signal and any HTTP client. Extension packages (`polly_dart_http`, `polly_dart_dio`) live in `extensions/` and depend only on `polly_dart` core. The repo root stays the core package; melos discovers extensions via glob.

**Tech Stack:** Dart ^3.5.0, melos ^6.0.0, package:http ^1.2.0 (extension only), dio ^5.0.0 (extension only), package:test ^1.24.0

---

## File Map

| File | Status | Purpose |
|---|---|---|
| `lib/src/cancellation_token.dart` | **NEW** | `CancellationToken` + `OperationCancelledException` |
| `lib/src/resilience_context.dart` | **MODIFY** | Delegates to `CancellationToken`, adds `cancellationToken` getter, exports `cancellation_token.dart` |
| `lib/polly_dart.dart` | **MODIFY** | Adds direct export of `cancellation_token.dart` |
| `test/cancellation_token_test.dart` | **NEW** | Unit tests for `CancellationToken` |
| `melos.yaml` | **NEW** | Monorepo config |
| `pubspec.yaml` | **MODIFY** | Adds `melos: ^6.0.0` dev dependency |
| `extensions/polly_dart_http/pubspec.yaml` | **NEW** | Extension package manifest |
| `extensions/polly_dart_http/analysis_options.yaml` | **NEW** | Mirrors root lints |
| `extensions/polly_dart_http/lib/polly_dart_http.dart` | **NEW** | `CancellableHttpClient` |
| `extensions/polly_dart_http/test/cancellable_http_client_test.dart` | **NEW** | Tests for `CancellableHttpClient` |
| `extensions/polly_dart_dio/pubspec.yaml` | **NEW** | Extension package manifest |
| `extensions/polly_dart_dio/analysis_options.yaml` | **NEW** | Mirrors root lints |
| `extensions/polly_dart_dio/lib/polly_dart_dio.dart` | **NEW** | `toDioCancelToken()` extension |
| `extensions/polly_dart_dio/test/cancellation_token_dio_test.dart` | **NEW** | Tests for the Dio extension |

---

## Task 1: Create `CancellationToken` with tests

**Files:**
- Create: `lib/src/cancellation_token.dart`
- Create: `test/cancellation_token_test.dart`

- [ ] **Step 1: Create the test file**

```dart
// test/cancellation_token_test.dart
import 'package:polly_dart/polly_dart.dart';
import 'package:test/test.dart';

void main() {
  group('CancellationToken', () {
    test('starts not cancelled', () {
      final token = CancellationToken();
      expect(token.isCancelled, isFalse);
    });

    test('isCancelled is true after cancel()', () {
      final token = CancellationToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('cancel() is idempotent — calling twice does not throw', () {
      final token = CancellationToken();
      token.cancel();
      expect(() => token.cancel(), returnsNormally);
      expect(token.isCancelled, isTrue);
    });

    test('whenCancelled completes after cancel()', () async {
      final token = CancellationToken();
      var completed = false;
      token.whenCancelled.then((_) => completed = true);
      expect(completed, isFalse);
      token.cancel();
      await Future.microtask(() {});
      expect(completed, isTrue);
    });

    test('whenCancelled completes immediately when already cancelled', () async {
      final token = CancellationToken();
      token.cancel();
      var completed = false;
      token.whenCancelled.then((_) => completed = true);
      await Future.microtask(() {});
      expect(completed, isTrue);
    });

    test('throwIfCancelled() does nothing when not cancelled', () {
      final token = CancellationToken();
      expect(() => token.throwIfCancelled(), returnsNormally);
    });

    test('throwIfCancelled() throws OperationCancelledException when cancelled', () {
      final token = CancellationToken();
      token.cancel();
      expect(
        () => token.throwIfCancelled(),
        throwsA(isA<OperationCancelledException>()),
      );
    });

    test('OperationCancelledException has default message', () {
      const e = OperationCancelledException();
      expect(e.toString(), contains('cancelled'));
    });

    test('OperationCancelledException accepts custom message', () {
      const e = OperationCancelledException('custom reason');
      expect(e.toString(), contains('custom reason'));
    });
  });
}
```

- [ ] **Step 2: Run test to confirm it fails (class not found)**

```bash
dart test test/cancellation_token_test.dart
```

Expected: compile error — `CancellationToken` not defined.

- [ ] **Step 3: Create `lib/src/cancellation_token.dart`**

```dart
import 'dart:async';

class CancellationToken {
  bool _cancelled = false;
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _cancelled;

  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_cancelled) {
      _cancelled = true;
      _completer.complete();
    }
  }

  void throwIfCancelled() {
    if (_cancelled) throw const OperationCancelledException();
  }
}

class OperationCancelledException implements Exception {
  final String message;

  const OperationCancelledException(
      [this.message = 'The operation was cancelled']);

  @override
  String toString() => 'OperationCancelledException: $message';
}
```

- [ ] **Step 4: Export from `lib/polly_dart.dart`**

Open `lib/polly_dart.dart` and add after the existing `// Core types` exports block:

```dart
export 'src/cancellation_token.dart';
```

The full exports section at the top of the file should now look like:

```dart
// Cache components
export 'src/caching/cache_callbacks.dart';
export 'src/caching/cache_metrics.dart';
export 'src/caching/cache_provider.dart';
export 'src/caching/memory_cache_provider.dart';
// Core types
export 'src/cancellation_token.dart';
export 'src/outcome.dart';
export 'src/resilience_context.dart';
export 'src/resilience_pipeline.dart';
export 'src/resilience_pipeline_builder.dart';
// Strategies
export 'src/strategies/cache_strategy.dart';
export 'src/strategies/circuit_breaker_strategy.dart';
export 'src/strategies/fallback_strategy.dart';
export 'src/strategies/hedging_strategy.dart';
export 'src/strategies/rate_limiter_strategy.dart';
export 'src/strategies/retry_strategy.dart';
export 'src/strategies/timeout_strategy.dart';
export 'src/strategy.dart';
```

- [ ] **Step 5: Run the test**

```bash
dart test test/cancellation_token_test.dart
```

Expected: all 9 tests pass.

- [ ] **Step 6: Run the full test suite to verify no regressions**

```bash
dart test
```

Expected: all existing tests pass. Watch for duplicate-export warnings — they are fine but should not exist yet.

- [ ] **Step 7: Commit**

```bash
git add lib/src/cancellation_token.dart lib/polly_dart.dart test/cancellation_token_test.dart
git commit -m "feat: add CancellationToken as public core type"
```

---

## Task 2: Refactor `ResilienceContext` to use `CancellationToken`

**Files:**
- Modify: `lib/src/resilience_context.dart`
- Test coverage: existing tests in `test/polly_dart_test.dart` (no new test file needed — `ResilienceContext` tests already exist there)

- [ ] **Step 1: Run the existing ResilienceContext tests to establish baseline**

```bash
dart test test/polly_dart_test.dart --name "ResilienceContext"
```

Expected: all 4 `ResilienceContext` group tests pass.

- [ ] **Step 2: Rewrite `lib/src/resilience_context.dart`**

Replace the entire file with:

```dart
import 'dart:async';

import 'cancellation_token.dart';

export 'cancellation_token.dart';

class ResilienceContext {
  final Map<String, Object?> _properties = {};
  final CancellationToken _token = CancellationToken();
  int _attemptNumber = 0;

  String? operationKey;

  ResilienceContext({this.operationKey});

  CancellationToken get cancellationToken => _token;

  ResilienceContext copy() {
    final child = ResilienceContext(operationKey: operationKey);
    child._properties.addAll(_properties);
    child._attemptNumber = _attemptNumber;
    if (_token.isCancelled) {
      child._token.cancel();
    } else {
      _token.whenCancelled.then((_) => child._token.cancel());
    }
    return child;
  }

  int get attemptNumber => _attemptNumber;

  void incrementAttemptNumber() => _attemptNumber++;

  void setAttemptNumber(int value) => _attemptNumber = value;

  bool get isCancellationRequested => _token.isCancelled;

  Future<void> get cancellationFuture => _token.whenCancelled;

  void cancel() => _token.cancel();

  void throwIfCancellationRequested() => _token.throwIfCancelled();

  void setProperty<T>(String key, T value) => _properties[key] = value;

  T? getProperty<T>(String key) {
    final value = _properties[key];
    return value is T ? value : null;
  }

  bool hasProperty(String key) => _properties.containsKey(key);

  void removeProperty(String key) => _properties.remove(key);

  Iterable<String> get propertyKeys => _properties.keys;

  void clearProperties() => _properties.clear();

  @override
  String toString() {
    return 'ResilienceContext(operationKey: $operationKey, attemptNumber: $_attemptNumber, '
        'isCancelled: ${_token.isCancelled}, properties: ${_properties.length})';
  }
}
```

Note: `OperationCancelledException` is now in `cancellation_token.dart` and re-exported via `export 'cancellation_token.dart'` — strategies that import `resilience_context.dart` still get it for free.

- [ ] **Step 3: Remove the `dart:async` import from `resilience_context.dart`**

The new file above already omits `dart:async` since `CancellationToken` owns the `Completer` now. `cancellationFuture` returns `_token.whenCancelled` which is `Future<void>` — but `Future` is available without an import in Dart (it's in `dart:core`). However, `Completer` is not. Since `ResilienceContext` no longer creates a `Completer` directly, the `dart:async` import is not needed.

The file as written in step 2 does NOT import `dart:async`. Verify this is correct by running the analyzer.

- [ ] **Step 4: Run the full test suite**

```bash
dart test
```

Expected: all existing tests pass, including the 4 `ResilienceContext` group tests. If any test fails, check whether it references the old `_cancellationCompleter` or `_isCancelled` fields (those are now gone).

- [ ] **Step 5: Add a new test for `cancellationToken` property and copy() propagation**

Open `test/polly_dart_test.dart` and add these two tests inside the `group('ResilienceContext', ...)` block:

```dart
test('cancellationToken reflects context cancellation state', () {
  final context = ResilienceContext();
  expect(context.cancellationToken.isCancelled, isFalse);
  context.cancel();
  expect(context.cancellationToken.isCancelled, isTrue);
});

test('copy() propagates parent cancellation to child', () async {
  final parent = ResilienceContext();
  final child = parent.copy();

  expect(child.isCancellationRequested, isFalse);

  parent.cancel();
  await Future.microtask(() {});

  expect(child.isCancellationRequested, isTrue);
});

test('copy() propagates already-cancelled parent to child immediately', () {
  final parent = ResilienceContext();
  parent.cancel();
  final child = parent.copy();

  expect(child.isCancellationRequested, isTrue);
});
```

- [ ] **Step 6: Run to verify new tests pass**

```bash
dart test test/polly_dart_test.dart --name "ResilienceContext"
```

Expected: all 7 `ResilienceContext` tests pass (4 original + 3 new).

- [ ] **Step 7: Run full test suite and analyzer**

```bash
dart test && dart analyze
```

Expected: no failures, no warnings.

- [ ] **Step 8: Commit**

```bash
git add lib/src/resilience_context.dart test/polly_dart_test.dart
git commit -m "refactor: delegate ResilienceContext cancellation to CancellationToken, add cancellationToken getter"
```

---

## Task 3: Set up melos monorepo

**Files:**
- Create: `melos.yaml`
- Modify: `pubspec.yaml` (add melos dev dependency)
- Create: `extensions/` directory structure

- [ ] **Step 1: Add melos to `pubspec.yaml`**

Open `pubspec.yaml`. Change the `dev_dependencies` section to:

```yaml
dev_dependencies:
  lints: ^4.0.0
  melos: ^6.0.0
  test: ^1.24.0
```

- [ ] **Step 2: Create `melos.yaml` at repo root**

```yaml
name: polly_dart_workspace

packages:
  - .
  - extensions/*

command:
  bootstrap:
    usePubspecOverrides: true

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

- [ ] **Step 3: Install melos and bootstrap the workspace**

```bash
cd /Users/anirudh/libraries/polly_dart && dart pub get && dart pub global activate melos
```

Expected: `melos` installed globally.

- [ ] **Step 4: Bootstrap (links local packages)**

```bash
cd /Users/anirudh/libraries/polly_dart && melos bootstrap
```

Expected: "Bootstrapping workspace..." and no errors. This creates `pubspec_overrides.yaml` files in extension packages (once they exist) so they resolve the local `polly_dart` rather than pub.dev.

- [ ] **Step 5: Commit**

```bash
git add melos.yaml pubspec.yaml pubspec.lock
git commit -m "chore: add melos monorepo config"
```

---

## Task 4: Create `polly_dart_http` extension package scaffold

**Files:**
- Create: `extensions/polly_dart_http/pubspec.yaml`
- Create: `extensions/polly_dart_http/analysis_options.yaml`
- Create: `extensions/polly_dart_http/lib/polly_dart_http.dart`
- Create: `extensions/polly_dart_http/test/cancellable_http_client_test.dart`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p /Users/anirudh/libraries/polly_dart/extensions/polly_dart_http/lib
mkdir -p /Users/anirudh/libraries/polly_dart/extensions/polly_dart_http/test
```

- [ ] **Step 2: Create `extensions/polly_dart_http/pubspec.yaml`**

```yaml
name: polly_dart_http
description: package:http adapter for polly_dart — CancellableHttpClient with automatic cancellation support.
version: 0.0.1
homepage: https://polly.anirudhsingh.in/
repository: https://github.com/flutterninja9/polly_dart

environment:
  sdk: ^3.5.0

dependencies:
  http: ^1.2.0
  polly_dart: ^0.0.8

dev_dependencies:
  lints: ^4.0.0
  test: ^1.24.0
```

- [ ] **Step 3: Create `extensions/polly_dart_http/analysis_options.yaml`**

```yaml
include: package:lints/recommended.yaml
```

- [ ] **Step 4: Create the stub library file**

```dart
// extensions/polly_dart_http/lib/polly_dart_http.dart
library polly_dart_http;

export 'src/cancellable_http_client.dart';
```

- [ ] **Step 5: Create `extensions/polly_dart_http/lib/src/cancellable_http_client.dart` as a stub**

```dart
// extensions/polly_dart_http/lib/src/cancellable_http_client.dart
```

(Empty for now — filled in Task 5.)

- [ ] **Step 6: Create the failing test file**

```dart
// extensions/polly_dart_http/test/cancellable_http_client_test.dart
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:polly_dart/polly_dart.dart';
import 'package:polly_dart_http/polly_dart_http.dart';
import 'package:test/test.dart';

// A fake http.Client that delays its response by [delay], then returns a 200.
class _DelayingClient extends http.BaseClient {
  final Duration delay;
  bool sendCalled = false;

  _DelayingClient(this.delay);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sendCalled = true;
    await Future.delayed(delay);
    return http.StreamedResponse(
      Stream.value(List.empty()),
      200,
      request: request,
    );
  }
}

void main() {
  group('CancellableHttpClient', () {
    test('completes normally when token is not cancelled', () async {
      final token = CancellationToken();
      final inner = _DelayingClient(Duration(milliseconds: 10));
      final client = CancellableHttpClient(inner: inner, token: token);

      final request = http.Request('GET', Uri.parse('https://example.com'));
      final response = await client.send(request);

      expect(response.statusCode, equals(200));
      client.close();
    });

    test('throws OperationCancelledException when token is pre-cancelled', () async {
      final token = CancellationToken();
      token.cancel();
      final inner = _DelayingClient(Duration(milliseconds: 100));
      final client = CancellableHttpClient(inner: inner, token: token);

      final request = http.Request('GET', Uri.parse('https://example.com'));
      expect(
        () => client.send(request),
        throwsA(isA<OperationCancelledException>()),
      );
      client.close();
    });

    test('throws OperationCancelledException when token is cancelled mid-request', () async {
      final token = CancellationToken();
      final inner = _DelayingClient(Duration(milliseconds: 200));
      final client = CancellableHttpClient(inner: inner, token: token);

      final request = http.Request('GET', Uri.parse('https://example.com'));
      final sendFuture = client.send(request);

      // Cancel 50ms into the 200ms request
      await Future.delayed(Duration(milliseconds: 50));
      token.cancel();

      expect(
        () => sendFuture,
        throwsA(isA<OperationCancelledException>()),
      );
      client.close();
    });

    test('works with TimeoutStrategy: token is cancelled on timeout', () async {
      final pipeline = ResiliencePipelineBuilder()
          .addTimeout(Duration(milliseconds: 50))
          .build();

      CancellationToken? capturedToken;

      await expectLater(
        pipeline.execute((context) async {
          capturedToken = context.cancellationToken;
          final inner = _DelayingClient(Duration(milliseconds: 500));
          final client = CancellableHttpClient(inner: inner, token: context.cancellationToken);
          try {
            final request = http.Request('GET', Uri.parse('https://example.com'));
            return await client.send(request);
          } finally {
            client.close();
          }
        }),
        throwsA(isA<TimeoutRejectedException>()),
      );

      // Token should have been cancelled by TimeoutStrategy
      expect(capturedToken?.isCancelled, isTrue);
    });

    test('sendAbortable uses AbortableRequest with correct trigger', () async {
      final token = CancellationToken();
      final inner = _DelayingClient(Duration(milliseconds: 10));
      final client = CancellableHttpClient(inner: inner, token: token);

      final response = await client.sendAbortable('GET', Uri.parse('https://example.com'));
      expect(response.statusCode, equals(200));
      client.close();
    });

    test('sendAbortable throws when token is pre-cancelled', () async {
      final token = CancellationToken();
      token.cancel();
      final inner = _DelayingClient(Duration(milliseconds: 100));
      final client = CancellableHttpClient(inner: inner, token: token);

      expect(
        () => client.sendAbortable('GET', Uri.parse('https://example.com')),
        throwsA(isA<OperationCancelledException>()),
      );
      client.close();
    });
  });
}
```

- [ ] **Step 7: Bootstrap with melos so polly_dart resolves locally**

```bash
cd /Users/anirudh/libraries/polly_dart && melos bootstrap
```

Expected: `pubspec_overrides.yaml` created in `extensions/polly_dart_http/` pointing `polly_dart` to local path.

- [ ] **Step 8: Run the test to see it fail**

```bash
cd /Users/anirudh/libraries/polly_dart/extensions/polly_dart_http && dart test
```

Expected: error — `CancellableHttpClient` not found (empty stub file).

- [ ] **Step 9: Commit the scaffold**

```bash
git add extensions/polly_dart_http/
git commit -m "chore: scaffold polly_dart_http extension package"
```

---

## Task 5: Implement `CancellableHttpClient`

**Files:**
- Modify: `extensions/polly_dart_http/lib/src/cancellable_http_client.dart`

- [ ] **Step 1: Implement `CancellableHttpClient`**

Write the full implementation into `extensions/polly_dart_http/lib/src/cancellable_http_client.dart`:

```dart
import 'package:http/http.dart' as http;
import 'package:polly_dart/polly_dart.dart';

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

    return Future.any([
      _inner.send(request),
      _token.whenCancelled.then<http.StreamedResponse>(
        (_) => throw const OperationCancelledException('HTTP request was cancelled'),
      ),
    ]);
  }

  /// Sends a cancellable request using [http.AbortableRequest] for socket-level abort.
  ///
  /// Prefer this over [send] for new code where you control request construction.
  /// The socket connection will be closed as soon as the [CancellationToken] is cancelled.
  Future<http.StreamedResponse> sendAbortable(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    _token.throwIfCancelled();

    final request = http.AbortableRequest(
      method,
      url,
      abortTrigger: _token.whenCancelled,
    );
    if (headers != null) request.headers.addAll(headers);
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is List<int>) {
        request.bodyBytes = body;
      } else if (body is Map<String, String>) {
        request.bodyFields = body;
      }
    }
    if (encoding != null) request.encoding = encoding;

    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
```

Note: `Encoding` is from `dart:convert`. Add the import at the top of the file:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:polly_dart/polly_dart.dart';
```

- [ ] **Step 2: Run the tests**

```bash
cd /Users/anirudh/libraries/polly_dart/extensions/polly_dart_http && dart test
```

Expected: all 6 tests pass. If the `sendAbortable` test for mid-request cancellation has timing flakiness, increase the delay ratios.

- [ ] **Step 3: Run the analyzer on the extension**

```bash
cd /Users/anirudh/libraries/polly_dart/extensions/polly_dart_http && dart analyze
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add extensions/polly_dart_http/lib/src/cancellable_http_client.dart
git commit -m "feat(polly_dart_http): implement CancellableHttpClient with socket-level abort support"
```

---

## Task 6: Create `polly_dart_dio` extension package

**Files:**
- Create: `extensions/polly_dart_dio/pubspec.yaml`
- Create: `extensions/polly_dart_dio/analysis_options.yaml`
- Create: `extensions/polly_dart_dio/lib/polly_dart_dio.dart`
- Create: `extensions/polly_dart_dio/lib/src/cancellation_token_dio_extension.dart`
- Create: `extensions/polly_dart_dio/test/cancellation_token_dio_test.dart`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p /Users/anirudh/libraries/polly_dart/extensions/polly_dart_dio/lib/src
mkdir -p /Users/anirudh/libraries/polly_dart/extensions/polly_dart_dio/test
```

- [ ] **Step 2: Create `extensions/polly_dart_dio/pubspec.yaml`**

```yaml
name: polly_dart_dio
description: Dio adapter for polly_dart — bridges CancellationToken to Dio's CancelToken.
version: 0.0.1
homepage: https://polly.anirudhsingh.in/
repository: https://github.com/flutterninja9/polly_dart

environment:
  sdk: ^3.5.0

dependencies:
  dio: ^5.0.0
  polly_dart: ^0.0.8

dev_dependencies:
  lints: ^4.0.0
  test: ^1.24.0
```

- [ ] **Step 3: Create `extensions/polly_dart_dio/analysis_options.yaml`**

```yaml
include: package:lints/recommended.yaml
```

- [ ] **Step 4: Write the failing test**

```dart
// extensions/polly_dart_dio/test/cancellation_token_dio_test.dart
import 'package:dio/dio.dart' as dio;
import 'package:polly_dart/polly_dart.dart';
import 'package:polly_dart_dio/polly_dart_dio.dart';
import 'package:test/test.dart';

void main() {
  group('CancellationToken Dio extension', () {
    test('toDioCancelToken() returns a non-cancelled DioToken initially', () {
      final token = CancellationToken();
      final dioToken = token.toDioCancelToken();
      expect(dioToken.isCancelled, isFalse);
    });

    test('Dio token is cancelled when polly token is cancelled', () async {
      final token = CancellationToken();
      final dioToken = token.toDioCancelToken();

      token.cancel();
      await Future.microtask(() {});

      expect(dioToken.isCancelled, isTrue);
    });

    test('Dio token is cancelled immediately if polly token was already cancelled', () async {
      final token = CancellationToken();
      token.cancel();

      final dioToken = token.toDioCancelToken();
      await Future.microtask(() {});

      expect(dioToken.isCancelled, isTrue);
    });

    test('cancelling Dio token directly does not affect the polly token', () async {
      final token = CancellationToken();
      final dioToken = token.toDioCancelToken();

      dioToken.cancel('manual cancel');

      expect(token.isCancelled, isFalse);
    });

    test('each call to toDioCancelToken() returns a distinct Dio token', () {
      final token = CancellationToken();
      final a = token.toDioCancelToken();
      final b = token.toDioCancelToken();
      expect(identical(a, b), isFalse);
    });

    test('cancelling polly token propagates to all Dio tokens created from it', () async {
      final token = CancellationToken();
      final dioToken1 = token.toDioCancelToken();
      final dioToken2 = token.toDioCancelToken();

      token.cancel();
      await Future.microtask(() {});

      expect(dioToken1.isCancelled, isTrue);
      expect(dioToken2.isCancelled, isTrue);
    });
  });
}
```

- [ ] **Step 5: Run to confirm it fails**

First bootstrap melos again now that the new package exists:

```bash
cd /Users/anirudh/libraries/polly_dart && melos bootstrap
```

Then run the test:

```bash
cd /Users/anirudh/libraries/polly_dart/extensions/polly_dart_dio && dart test
```

Expected: compile error — `polly_dart_dio` library not found.

- [ ] **Step 6: Create the library entry point**

```dart
// extensions/polly_dart_dio/lib/polly_dart_dio.dart
library polly_dart_dio;

export 'src/cancellation_token_dio_extension.dart';
```

- [ ] **Step 7: Implement the extension**

```dart
// extensions/polly_dart_dio/lib/src/cancellation_token_dio_extension.dart
import 'package:dio/dio.dart' as dio;
import 'package:polly_dart/polly_dart.dart';

extension CancellationTokenDioExtension on CancellationToken {
  /// Returns a Dio [CancelToken] that is cancelled when this token is cancelled.
  ///
  /// Each call returns a distinct [CancelToken]. If this token is already
  /// cancelled, the returned token will be cancelled after the next microtask.
  ///
  /// ```dart
  /// pipeline.execute((context) async {
  ///   final response = await dio.get(
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

- [ ] **Step 8: Run the tests**

```bash
cd /Users/anirudh/libraries/polly_dart/extensions/polly_dart_dio && dart test
```

Expected: all 6 tests pass.

- [ ] **Step 9: Run the analyzer**

```bash
cd /Users/anirudh/libraries/polly_dart/extensions/polly_dart_dio && dart analyze
```

Expected: no issues.

- [ ] **Step 10: Commit**

```bash
git add extensions/polly_dart_dio/
git commit -m "feat(polly_dart_dio): add toDioCancelToken() extension bridging CancellationToken to Dio"
```

---

## Task 7: Run full workspace test suite and verify

- [ ] **Step 1: Run all tests via melos**

```bash
cd /Users/anirudh/libraries/polly_dart && melos run test
```

Expected: all tests in all packages pass. Count will be: core tests (existing + new) + 6 polly_dart_http tests + 6 polly_dart_dio tests.

- [ ] **Step 2: Run analysis across all packages**

```bash
cd /Users/anirudh/libraries/polly_dart && melos run analyze
```

Expected: no issues in any package.

- [ ] **Step 3: Dry-run publish check on all packages**

```bash
cd /Users/anirudh/libraries/polly_dart && melos run publish:check
```

Expected: no errors. Warnings about `polly_dart_http` and `polly_dart_dio` not having a `repository` link resolved (they already have it in pubspec.yaml). If you see "description is too long/short" — adjust the description.

- [ ] **Step 4: Final commit on the feature branch**

```bash
git add .
git status  # verify only intentional files
git commit -m "chore: run melos bootstrap artifacts"
```

---

## Self-Review Checklist

After completing all tasks, verify these against the spec:

- [ ] `CancellationToken` is a public exported class ✅ (Task 1)
- [ ] `CancellationToken.whenCancelled` is a `Future<void>` ✅ (Task 1)
- [ ] `ResilienceContext.cancellationToken` getter exists ✅ (Task 2)
- [ ] `copy()` propagates parent cancellation to child ✅ (Task 2)
- [ ] All existing `ResilienceContext` API is preserved, no breaking changes ✅ (Task 2)
- [ ] `melos.yaml` created and workspace bootstrapped ✅ (Task 3)
- [ ] `polly_dart_http` package with `CancellableHttpClient` ✅ (Tasks 4-5)
- [ ] `CancellableHttpClient.sendAbortable()` using `AbortableRequest` ✅ (Task 5)
- [ ] `polly_dart_dio` package with `toDioCancelToken()` extension ✅ (Task 6)
- [ ] All packages analyze and test clean ✅ (Task 7)
- [ ] Version bump to 0.0.8 in core pubspec.yaml — **not yet done, do this before publishing**
