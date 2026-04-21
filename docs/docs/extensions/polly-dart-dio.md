---
sidebar_position: 3
---

# polly_dart_dio

`polly_dart_dio` bridges polly_dart's `CancellationToken` to Dio's native `CancelToken`. When the pipeline cancels (timeout, hedging winner found, manual cancel), Dio receives the signal and closes the socket through its own HTTP adapter — giving you true socket-level abort with zero boilerplate.

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

One call — `context.cancellationToken.toDioCancelToken()` — and Dio handles the rest.

## API

### `toDioCancelToken()`

An extension method on `CancellationToken`:

```dart
extension CancellationTokenDioExtension on CancellationToken {
  CancelToken toDioCancelToken();
}
```

Returns a new `dio.CancelToken` that is cancelled when the polly token is cancelled. Each call returns a **distinct** token, so you can safely call it multiple times within one pipeline execution (e.g., for separate Dio requests).

```dart
final dioToken = context.cancellationToken.toDioCancelToken();
```

Cancellation propagates via `CancellationToken.whenCancelled` (a `Future<void>`). The polly token's state does not change when the Dio token is cancelled directly.

## Cancellation behaviour

| Scenario | Result |
|---|---|
| Token not cancelled | Dio request completes normally |
| Token cancelled before request starts | Dio token is already cancelled; Dio throws `DioException` with type `cancel` |
| Token cancelled mid-request | Dio token is cancelled; socket closed by Dio's adapter |
| Dio token cancelled independently | Polly token is **unaffected** |

### Handling `DioException`

When Dio cancels a request it throws a `DioException` with `type == DioExceptionType.cancel`. If your pipeline handles all exceptions by default (retry, fallback, circuit breaker), you may want to exclude cancellations:

```dart
final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      shouldHandle: PredicateBuilder()
          .handle<DioException>()  // only handle DioException...
          .handleOutcome((outcome) {
            // ...but not cancellations
            if (outcome.hasException &&
                outcome.exception is DioException &&
                (outcome.exception as DioException).type == DioExceptionType.cancel) {
              return false;
            }
            return true;
          })
          .build(),
    ))
    .build();
```

Or more simply — check `OperationCancelledException` if you wrap Dio in a helper that converts cancellations:

```dart
// Helper that converts DioException(cancel) → OperationCancelledException
Future<Response<T>> cancellableGet<T>(
  Dio dio,
  String url,
  CancellationToken token,
) async {
  try {
    return await dio.get<T>(url, cancelToken: token.toDioCancelToken());
  } on DioException catch (e) {
    if (e.type == DioExceptionType.cancel) {
      throw OperationCancelledException('Dio request cancelled by polly_dart pipeline');
    }
    rethrow;
  }
}
```

## Real-world example

```dart
import 'package:dio/dio.dart';
import 'package:polly_dart/polly_dart.dart';
import 'package:polly_dart_dio/polly_dart_dio.dart';

class UserService {
  final Dio _dio;
  final ResiliencePipeline _pipeline;

  UserService()
      : _dio = Dio(BaseOptions(baseUrl: 'https://api.example.com')),
        _pipeline = ResiliencePipelineBuilder()
            .addTimeout(Duration(seconds: 8))
            .addRetry(RetryStrategyOptions(
              maxRetryAttempts: 3,
              delay: Duration(milliseconds: 500),
              backoffType: DelayBackoffType.exponential,
              shouldHandle: PredicateBuilder()
                  .handle<DioException>()
                  .handleOutcome((o) =>
                      o.hasException &&
                      o.exception is DioException &&
                      (o.exception as DioException).type != DioExceptionType.cancel)
                  .build(),
            ))
            .addCircuitBreaker()
            .build();

  Future<List<User>> getUsers() {
    return _pipeline.execute((context) async {
      final response = await _dio.get<List<dynamic>>(
        '/users',
        cancelToken: context.cancellationToken.toDioCancelToken(),
      );
      return response.data!.map((j) => User.fromJson(j)).toList();
    });
  }

  Future<User> createUser(String name, String email) {
    return _pipeline.execute((context) async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/users',
        data: {'name': name, 'email': email},
        cancelToken: context.cancellationToken.toDioCancelToken(),
      );
      return User.fromJson(response.data!);
    });
  }
}

class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        name: json['name'],
        email: json['email'],
      );
}
```

## Using with Dio interceptors

`toDioCancelToken()` works seamlessly alongside Dio interceptors — just pass it in the request options as normal:

```dart
_dio.interceptors.add(LogInterceptor(responseBody: true));

final response = await _dio.get(
  '/data',
  cancelToken: context.cancellationToken.toDioCancelToken(),
  options: Options(headers: {'Authorization': 'Bearer $token'}),
);
```

## Multiple requests in one execution

Each call to `toDioCancelToken()` returns a distinct `CancelToken`, all linked to the same polly token. This lets you make parallel Dio requests that all cancel together:

```dart
await pipeline.execute((context) async {
  final token = context.cancellationToken;

  // Both are cancelled the moment the pipeline cancels
  final results = await Future.wait([
    dio.get('/users', cancelToken: token.toDioCancelToken()),
    dio.get('/posts', cancelToken: token.toDioCancelToken()),
  ]);

  return results;
});
```

## Using with Retrofit

[Retrofit for Dart](https://pub.dev/packages/retrofit) generates type-safe API clients on top of Dio. Because `toDioCancelToken()` returns a plain Dio `CancelToken`, Retrofit understands it natively — no adapter or wrapper needed.

Add a `@CancelRequest()` parameter to any endpoint you want to be cancellable:

```dart
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'api_service.g.dart';

@RestApi(baseUrl: 'https://api.example.com')
abstract class ApiService {
  factory ApiService(Dio dio, {String baseUrl}) = _ApiService;

  @GET('/users')
  Future<List<User>> getUsers({@CancelRequest() CancelToken? cancelToken});

  @POST('/users')
  Future<User> createUser(
    @Body() Map<String, dynamic> body, {
    @CancelRequest() CancelToken? cancelToken,
  });
}
```

Then inside a pipeline execution:

```dart
final users = await pipeline.execute((context) async {
  return apiService.getUsers(
    cancelToken: context.cancellationToken.toDioCancelToken(),
  );
});
```

That's the entire integration. The only one-time cost is adding `@CancelRequest() CancelToken? cancelToken` to each endpoint and re-running `build_runner`.

## Flutter: cancelling on screen navigation (Cubit)

A common Flutter pattern — user navigates away mid-request and the in-flight call should be aborted. The natural hook is `Cubit.close()`, which Flutter calls automatically when the `BlocProvider` disposes.

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:polly_dart/polly_dart.dart';
import 'package:polly_dart_dio/polly_dart_dio.dart';

class UserCubit extends Cubit<UserState> {
  final ApiService _apiService;
  final ResiliencePipeline _pipeline;
  ResilienceContext? _activeContext;

  UserCubit(this._apiService, this._pipeline) : super(UserInitial());

  Future<void> loadUsers() async {
    // Cancel any previous in-flight call before starting a new one.
    // Safe to call even if the previous request already finished.
    _activeContext?.cancel();
    final context = ResilienceContext();
    _activeContext = context;

    emit(UserLoading());
    try {
      final users = await _pipeline.execute(
        (ctx) => _apiService.getUsers(
          cancelToken: ctx.cancellationToken.toDioCancelToken(),
        ),
        context: context,
      );
      emit(UserLoaded(users));
    } on DioException catch (e) {
      // Screen is gone — swallow the signal, no stale state emitted.
      if (e.type == DioExceptionType.cancel) return;
      emit(UserError(e.message ?? 'Request failed'));
    } on TimeoutRejectedException {
      emit(UserError('Request timed out'));
    }
  }

  @override
  Future<void> close() {
    _activeContext?.cancel(); // abort any in-flight request
    return super.close();
  }
}
```

### What happens when the user navigates away

```
User swaps Screen A → Screen B
  └── Flutter disposes Screen A's widget tree
        └── BlocProvider calls cubit.close()
              └── _activeContext.cancel()
                    └── CancellationToken.whenCancelled completes
                          └── toDioCancelToken() listener fires
                                └── Dio closes the socket
                                      └── DioException.cancel thrown
                                            └── caught silently — no stale emit
```

### Why `_activeContext` is per-request, not per-cubit

Holding a single context at the cubit level would permanently cancel it after the first navigation. A per-request context means:

- **Rapid taps** — previous call cancelled, new one starts cleanly
- **Navigation away** — current call cancelled, no stale `UserLoaded` emitted after dispose
- **Navigation back** — `BlocProvider` creates a fresh cubit with a fresh context, no leftover state

## Testing

```dart
test('Dio token is cancelled when polly pipeline times out', () async {
  final pipeline = ResiliencePipelineBuilder()
      .addTimeout(Duration(milliseconds: 50))
      .build();

  CancellationToken? captured;

  await expectLater(
    pipeline.execute((context) async {
      captured = context.cancellationToken;
      // Simulate a slow request
      await Future.delayed(Duration(milliseconds: 500));
      return 'never';
    }),
    throwsA(isA<TimeoutRejectedException>()),
  );

  expect(captured?.isCancelled, isTrue);

  final dioToken = captured!.toDioCancelToken();
  await Future.microtask(() {});
  expect(dioToken.isCancelled, isTrue);
});
```

## Next steps

- [polly_dart_http](./polly-dart-http) — if you use `package:http` instead of Dio
- [Timeout Strategy](../strategies/timeout) — configure when cancellation fires
- [Hedging Strategy](../strategies/hedging) — cancel losing parallel attempts automatically
