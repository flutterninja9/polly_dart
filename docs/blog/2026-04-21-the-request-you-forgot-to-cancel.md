---
slug: the-request-you-forgot-to-cancel
title: The Request You Forgot to Cancel
authors: [anirudh_singh]
tags: [dart, flutter, http, cancellation, dio, best-practices]
---

You open a product detail screen. The app fires a request to load the data. You change your mind and swipe back. Flutter pops the route, disposes the widget, closes the cubit. Everything on the Flutter side cleaned up correctly.

But out on the internet, a request is still running.

The server received it. It's querying the database, serializing JSON, preparing a response. Nobody is waiting for that response anymore — the screen is gone, the cubit is gone, the state is gone. But the server doesn't know that. So it finishes the work anyway, sends the bytes back, and your app quietly receives them, parses them, and throws them away.

This is the part that always gets missed.

<!--truncate-->

## The cleanup that didn't happen

Most Flutter developers have dealt with the `setState() called after dispose()` warning at some point. It's annoying, but the fix is well understood — and if you're using a state management library like `flutter_bloc`, it's largely handled for you. When the screen is popped, `BlocProvider` calls `cubit.close()`, the stream closes, and any subsequent emits are silently dropped. The widget side is clean.

What's not handled is the network layer. `cubit.close()` doesn't reach down into the HTTP client and say "stop, we don't need this anymore." The request that was in-flight keeps going, completely unaware that its requester has moved on.

This is worth sitting with for a moment: your app correctly managed all of its local state. Nothing crashed. No stale data appeared on screen. From Flutter's perspective, everything worked. But a real network connection was kept open, a real server spent real CPU cycles on work that produced nothing useful, and real bytes traveled across the network that were immediately discarded.

At the scale of a single user tapping around your app, this is a minor inefficiency. At the scale of thousands of users, it starts to matter.

## The scenario that makes it visible

Imagine a search screen. Every time the user types a character, you fire a request. The user types "flutter" — that's seven keystrokes, seven requests. They type at a reasonable pace, maybe 150ms between characters, but your API takes 300ms to respond. By the time the final request for "flutter" comes back, the requests for "f", "fl", "flu", "flut", "flutt", and "flutte" are all still in flight. Six requests nobody cares about anymore. Six server roundtrips happening in parallel for no reason.

Or a feed screen. The user pulls to refresh, then immediately switches to another tab. The refresh request runs to completion, fetches a full page of data, and delivers it to a cubit that no longer exists.

The Flutter side handled both of these correctly. The waste happened at the network level.

## The fix is in the HTTP layer

The solution is actual request cancellation — telling the HTTP client to abort the connection, not just ignoring the response when it arrives.

Dio has this built in. You create a `CancelToken`, pass it with the request, and call `cancel()` on it when you no longer need the result. Dio closes the socket.

```dart
class FeedCubit extends Cubit<FeedState> {
  CancelToken? _cancelToken;

  Future<void> refresh() async {
    // Cancel whatever was already running
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    emit(FeedLoading());
    try {
      final response = await dio.get(
        '/feed',
        cancelToken: _cancelToken,
      );
      emit(FeedLoaded(response.data));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      emit(FeedError(e.message ?? 'Failed'));
    }
  }

  @override
  Future<void> close() {
    _cancelToken?.cancel(); // abort when screen is disposed
    return super.close();
  }
}
```

Now when `BlocProvider` closes the cubit, the token fires, and Dio actually closes the connection. The server stops receiving the request mid-stream (or if it already sent the response, the TCP connection is dropped before your app reads it). Either way, you've stopped pretending the work was needed.

## Where the manual approach gets noisy

For a cubit making a single request, one `CancelToken` field is manageable. But add a few more requests and the bookkeeping grows:

```dart
CancelToken? _feedToken;
CancelToken? _userToken;
CancelToken? _notificationsToken;

@override
Future<void> close() {
  _feedToken?.cancel();
  _userToken?.cancel();
  _notificationsToken?.cancel();
  return super.close();
}
```

Then add retry logic — and you need to make sure you're not retrying a request that was *intentionally* cancelled, because that would immediately undo the cancellation:

```dart
shouldHandle: (outcome) {
  if (outcome.exception is DioException &&
      (outcome.exception as DioException).type == DioExceptionType.cancel) {
    return false; // don't retry a cancellation
  }
  return outcome.hasException;
}
```

And if you stack a timeout on top of retry, you need that same check in the timeout path too, and now the cancellation logic is scattered across token declarations, `close()` overrides, retry predicates, and timeout handlers.

It still works. It's just a lot of plumbing to carry around.

## The shameless part

`polly_dart_dio` is an extension I built that connects Dio's `CancelToken` to `polly_dart`'s resilience pipeline. The pipeline already has a `CancellationToken` that all strategies (timeout, retry, hedging) share. One method call bridges it to Dio:

```dart
cancelToken: context.cancellationToken.toDioCancelToken()
```

The cubit pattern becomes:

```dart
class FeedCubit extends Cubit<FeedState> {
  final ResiliencePipeline _pipeline;
  ResilienceContext? _activeContext;

  FeedCubit(this._pipeline) : super(FeedInitial());

  Future<void> refresh() async {
    _activeContext?.cancel();
    final context = ResilienceContext();
    _activeContext = context;

    emit(FeedLoading());
    try {
      final data = await _pipeline.execute(
        (ctx) async {
          final response = await dio.get(
            '/feed',
            cancelToken: ctx.cancellationToken.toDioCancelToken(),
          );
          return response.data;
        },
        context: context,
      );
      emit(FeedLoaded(data));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      emit(FeedError(e.message ?? 'Failed'));
    } on TimeoutRejectedException {
      emit(FeedError('Request timed out'));
    }
  }

  @override
  Future<void> close() {
    _activeContext?.cancel();
    return super.close();
  }
}
```

One context. One `cancel()` call in `close()`. All parallel requests just get their own `toDioCancelToken()` call — they're all linked to the same token, so one `cancel()` takes down every open connection:

```dart
await Future.wait([
  dio.get('/feed',          cancelToken: token.toDioCancelToken()),
  dio.get('/notifications', cancelToken: token.toDioCancelToken()),
]);
```

If you use Retrofit, add `@CancelRequest() CancelToken? cancelToken` to the endpoint and pass `ctx.cancellationToken.toDioCancelToken()`. That's the full integration.

## The thing worth remembering

Flutter handles the UI lifecycle really well. Cubits, providers, and `dispose()` take care of local state so cleanly that it's easy to feel like the cleanup is done when it isn't. The network layer is one step further out, and nothing in the framework reaches that far automatically.

The request you fired before the user swiped back is still out there. The server is finishing the work. The bytes are coming back. Your app is going to receive them.

The only question is whether you planned for that.

---

`polly_dart_dio` is available on [pub.dev](https://pub.dev/packages/polly_dart_dio). If you're using `package:http` rather than Dio, [`polly_dart_http`](https://pub.dev/packages/polly_dart_http) covers the same ground for that client. Both are extensions to [polly_dart](https://pub.dev/packages/polly_dart) — a resilience pipeline library for Dart and Flutter.
