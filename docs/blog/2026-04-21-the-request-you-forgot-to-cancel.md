---
slug: the-request-you-forgot-to-cancel
title: The Request You Forgot to Cancel
authors: [anirudh_singh]
tags: [dart, flutter, http, cancellation, dio, best-practices]
---

You open an app. You tap on a product. The detail screen starts loading. You change your mind and go back. Half a second later, the app fetches the full product data anyway, parses it, and tries to update a screen that no longer exists.

Nobody notices. The user didn't notice. You probably didn't notice. But something real happened: a network socket stayed open a little longer than it needed to, a server processed a request nobody was waiting for, and a widget tried to call `setState` after it was disposed — which, if you're lucky, Dart caught and printed a warning about.

This is the in-flight request problem. It's quiet, it's common, and most apps ship with it every single day.

<!--truncate-->

## Why it actually matters

The obvious case is wasted bandwidth. If a user navigates away mid-download, you're transferring data that will immediately be thrown away. On a mobile connection, that's real cost — both in data and in battery.

But the subtler issue is state. Async callbacks don't know that the world has moved on. If your response handler runs after the screen that triggered it has been disposed, you get the classic Flutter warning:

```
setState() called after dispose()
```

Or worse — no warning at all. The data lands in your bloc/cubit/provider, triggers a rebuild, and shows stale information for a split second before the current screen overwrites it. Users rarely notice. Crash reporters never catch it. It just quietly degrades the experience.

And then there's the resource side. Every open socket is a file descriptor. Every pending response holds memory. On a low-end device with a slow connection, a user who taps around rapidly can stack up several in-flight requests, all racing to update UI that's already moved on.

The fix isn't complicated. The hard part is remembering that the problem exists.

## Rolling your own cancellation

The first instinct is to track it yourself. Keep a flag. Check the flag before doing anything in the callback.

```dart
class UserScreen extends StatefulWidget { ... }

class _UserScreenState extends State<UserScreen> {
  bool _mounted = true;
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await api.getUser(widget.id); // still running after pop
    if (!_mounted) return;                      // check before setState
    setState(() => _user = user);
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }
}
```

This stops the `setState` crash. It doesn't stop the request. The network call runs to completion — you just ignore the result. That's better than crashing, but it's not cancellation.

The real problem shows up when you need to actually abort the work: stop the download, release the connection, free the memory. A boolean flag can't do that.

You need something that reaches into the HTTP layer.

## Cancellation at the HTTP layer

If you're using Dio, this is already built in. Dio has a `CancelToken` class — you pass one when making a request, and if you cancel it later, Dio closes the socket.

```dart
class UserCubit extends Cubit<UserState> {
  CancelToken? _cancelToken;

  Future<void> loadUser(int id) async {
    _cancelToken?.cancel('New request started');
    _cancelToken = CancelToken();

    emit(UserLoading());
    try {
      final response = await dio.get(
        '/users/$id',
        cancelToken: _cancelToken,
      );
      emit(UserLoaded(User.fromJson(response.data)));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return; // expected, ignore
      emit(UserError(e.message ?? 'Failed'));
    }
  }

  @override
  Future<void> close() {
    _cancelToken?.cancel('Screen disposed');
    return super.close();
  }
}
```

This is the right shape. When the cubit closes — which Flutter does automatically when the screen is popped — the token fires, Dio shuts down the connection, and nothing tries to update dead state.

For a single cubit making a single request, this works well. But real apps aren't single cubits making single requests.

## Where it starts to get messy

Say your screen makes three requests in parallel — user profile, recent activity, and notification count. Now you need three tokens:

```dart
CancelToken? _profileToken;
CancelToken? _activityToken;
CancelToken? _notificationToken;
```

And in `close()`:

```dart
@override
Future<void> close() {
  _profileToken?.cancel();
  _activityToken?.cancel();
  _notificationToken?.cancel();
  return super.close();
}
```

And if you add retry logic — which you probably should, for transient failures — you need to make sure you're not retrying a request that was *intentionally* cancelled. Retrying a cancellation defeats the entire point:

```dart
RetryStrategyOptions(
  shouldHandle: PredicateBuilder()
      .handleOutcome((outcome) {
        if (outcome.exception is DioException &&
            (outcome.exception as DioException).type == DioExceptionType.cancel) {
          return false; // don't retry cancellations
        }
        return outcome.hasException;
      })
      .build(),
)
```

And if you add a timeout on top of retry, you need to make sure the timeout fires the same cancellation path, not a different one. Now your cancellation logic is spread across token declarations, `close()`, retry predicates, and timeout handlers. It still works — but it's a lot of plumbing to get right and easy to miss in code review.

## The part where I mention my library

So I built an extension to handle this. It's called `polly_dart_dio`.

The idea is simple: `polly_dart` already has a `CancellationToken` that the whole resilience pipeline (timeout, retry, hedging) operates on. When anything in the pipeline decides the operation should be cancelled — timeout fires, hedging finds a winner, you call `cancel()` manually — that one token knows about it. The extension just connects that token to Dio's `CancelToken` with a single method call:

```dart
cancelToken: context.cancellationToken.toDioCancelToken()
```

That's it. From there, the pipeline's cancellation signal reaches Dio's socket layer automatically.

The cubit pattern from before becomes:

```dart
class UserCubit extends Cubit<UserState> {
  final ResiliencePipeline _pipeline;
  ResilienceContext? _activeContext;

  UserCubit(this._pipeline) : super(UserInitial());

  Future<void> loadUser(int id) async {
    _activeContext?.cancel();
    final context = ResilienceContext();
    _activeContext = context;

    emit(UserLoading());
    try {
      final user = await _pipeline.execute(
        (ctx) async {
          final response = await dio.get(
            '/users/$id',
            cancelToken: ctx.cancellationToken.toDioCancelToken(),
          );
          return User.fromJson(response.data);
        },
        context: context,
      );
      emit(UserLoaded(user));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      emit(UserError(e.message ?? 'Failed'));
    } on TimeoutRejectedException {
      emit(UserError('Request timed out'));
    }
  }

  @override
  Future<void> close() {
    _activeContext?.cancel();
    return super.close();
  }
}
```

The difference here is that one context covers everything the pipeline does. If you have retry, timeout, and circuit breaker stacked together, they all share the same cancellation signal. Parallel requests just each get their own `toDioCancelToken()` call — they're all linked to the same token, so one `cancel()` takes down all of them:

```dart
final results = await Future.wait([
  dio.get('/users',    cancelToken: token.toDioCancelToken()),
  dio.get('/posts',    cancelToken: token.toDioCancelToken()),
  dio.get('/comments', cancelToken: token.toDioCancelToken()),
]);
```

And if you're using Retrofit (which wraps Dio), add `@CancelRequest() CancelToken? cancelToken` to your endpoint method and pass `ctx.cancellationToken.toDioCancelToken()` — the generated client handles the rest.

## The point

In-flight request cancellation is the kind of thing that feels optional until it isn't. It doesn't cause crashes in most cases. It doesn't show up in your error tracker. It just quietly wastes resources and occasionally produces a weird flicker in your UI that nobody can reproduce consistently.

The good news is that Dio already has everything you need at the HTTP level. The wiring is the tedious part. Whether you do it manually with `CancelToken` directly, or use an abstraction that connects your pipeline's lifecycle to the socket, the important thing is doing it at all.

Because somewhere in your app right now, there's a request running for a screen the user already left. It's going to finish. It's going to try to do something with the result. And nobody is going to notice.

Until they do.

---

`polly_dart_dio` is available on pub.dev. If you're using `package:http` rather than Dio, there's `polly_dart_http` which covers the same ground for that client. Both are extensions to [polly_dart](https://pub.dev/packages/polly_dart) — a resilience pipeline library for Dart and Flutter.
