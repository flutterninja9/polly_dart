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

    test('Dio token is cancelled immediately if polly token was already cancelled',
        () async {
      final token = CancellationToken();
      token.cancel();

      final dioToken = token.toDioCancelToken();
      await Future.microtask(() {});

      expect(dioToken.isCancelled, isTrue);
    });

    test('cancelling Dio token directly does not affect the polly token',
        () async {
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

    test('cancelling polly token propagates to all Dio tokens created from it',
        () async {
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
