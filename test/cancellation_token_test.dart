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

    test('throwIfCancelled() throws OperationCancelledException when cancelled',
        () {
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
