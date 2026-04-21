## 0.0.1

- Initial release.
- `toDioCancelToken()` extension on `CancellationToken` — converts a polly_dart cancellation signal to a Dio `CancelToken`.
- Cancellation propagates via `CancellationToken.whenCancelled`; Dio closes the socket through its `HttpClientAdapter`.
- Each call returns a distinct `CancelToken`, so multiple parallel Dio requests can all be cancelled by a single polly token.
- Compatible with all polly_dart strategies that signal cancellation (Timeout, Hedging).
