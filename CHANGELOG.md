## 0.0.9

**No breaking changes.** All existing APIs are preserved.

### Circuit Breaker

- `OnCircuitOpenedArguments` gains two optional fields: `Outcome<T>? outcome` (the failing outcome that triggered the open) and `bool isManual` (whether the circuit was opened via `CircuitBreakerManualControl.isolateAsync`). Both default to their zero values so existing callbacks continue to compile unchanged.
- `OnCircuitClosedArguments` gains `bool isManual` (whether the circuit was closed via `CircuitBreakerManualControl.closeAsync`), defaulting to `false`.
- `BreakDurationGeneratorArguments` gains `Outcome<T>? outcome` so custom break-duration logic can inspect the specific error that caused the circuit to open (e.g. apply a longer break for a 503 than a 500).

### Rate Limiter

- `RateLimiterRejectedException` gains `Duration? retryAfter` — the suggested wait time before retrying. Populated for token-bucket, fixed-window, and sliding-window limiters; `null` for concurrency limiters where the release time is unknown.
- `OnRateLimiterRejectedArguments` gains the same `Duration? retryAfter` field so rejection callbacks receive the hint without catching the exception.

### Hedging

- `OnHedgingArguments` gains `Outcome<T>? outcome` — the primary outcome if the primary attempt already completed with a handled result before the hedge was triggered; `null` when the hedge fires speculatively while the primary is still in-flight.
- `HedgingDelayGeneratorArguments` gains `Outcome<T>? primaryOutcome` with the same semantics.

### Outcome

- `tryGetResult()` — returns the result if successful, or `null` if the outcome represents an exception. Avoids a try/catch when you just want an optional value.
- `tryGetException()` — returns the exception if present, or `null` if the outcome represents a successful result.
- `when<R>({required onResult, required onException})` — exhaustive match helper that calls the appropriate handler and returns its value, eliminating repeated `hasResult` checks.

### PredicateBuilder

- `handleWhen<TException>(bool Function(TException) predicate)` — adds a predicate that handles exceptions of a specific type only when an additional condition on the exception instance is true (e.g. `handleWhen<HttpException>((e) => e.statusCode >= 500)`).

### ResiliencePipeline

- `ResiliencePipeline.empty` — a pre-built, reusable no-op pipeline that executes callbacks directly without any resilience wrapping. Useful as a default value in optional-pipeline patterns and dependency injection scenarios.

### Retry

- Fixed jitter implementation to match .NET Polly's decorrelated-jitter formula: `delay × (1 + random ∈ [−0.5, 0.5))`, giving a final delay in the range **[50 %, 150 %]** of the calculated base. Previously the jitter replaced the entire delay with a random value in `[0, base)`, which could collapse the delay to near-zero.

## 0.0.8

**No breaking changes.** All existing APIs are preserved.

### New

- `CancellationToken` — new public class that bridges the pipeline's cancellation signal
  to external resources (HTTP clients, etc.). Exposes `isCancelled`, `whenCancelled`
  (`Future<void>`), `cancel()`, and `throwIfCancelled()`.
- `ResilienceContext.cancellationToken` — getter that returns the context's
  `CancellationToken`, ready to pass into HTTP client adapters.
- `ResilienceContext.copy()` now propagates parent cancellation to child contexts
  automatically (previously child contexts were independent after copying).

### Internal

- `OperationCancelledException` moved from `resilience_context.dart` to the new
  `cancellation_token.dart`. It is still re-exported by both files, so any existing
  `import 'package:polly_dart/polly_dart.dart'` continues to resolve it unchanged.
- Repo converted to a melos monorepo. Extension packages (`polly_dart_http`,
  `polly_dart_dio`) live in `extensions/` and are published as separate packages.

## 0.0.7

- Update README with examples of cache strategy usage

## 0.0.6

- Add cache strategy support
- Fix version in the readme installation example

## 0.0.5

- ReFormat the changelog for consistency

## 0.0.4

- Reorganize the changelog

## 0.0.3

- Update pub homepage link to point to the correct documentation website

## 0.0.2

- Add docs

## 0.0.1

- Initial version.