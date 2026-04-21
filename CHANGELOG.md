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