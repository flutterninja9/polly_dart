## 0.0.2

- Add example.

## 0.0.1

- Initial release.
- `CancellableHttpClient` — a `package:http` `BaseClient` wrapper that aborts requests when a `CancellationToken` is cancelled.
- `send()` provides application-level cancellation via `Future.any`.
- `sendAbortable()` provides socket-level cancellation via `http.AbortableRequest`.
- Compatible with all polly_dart strategies that signal cancellation (Timeout, Hedging).
