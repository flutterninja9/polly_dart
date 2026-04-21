import 'package:http/http.dart' as http;
import 'package:polly_dart/polly_dart.dart';
import 'package:polly_dart_http/polly_dart_http.dart';
import 'package:test/test.dart';

class _DelayingClient extends http.BaseClient {
  final Duration delay;

  _DelayingClient(this.delay);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future.delayed(delay);
    return http.StreamedResponse(
      Stream.value(<int>[]),
      200,
      request: request,
    );
  }
}

void main() {
  group('CancellableHttpClient', () {
    test('completes normally when token is not cancelled', () async {
      final token = CancellationToken();
      final client = CancellableHttpClient(
          inner: _DelayingClient(Duration(milliseconds: 10)), token: token);

      final response =
          await client.send(http.Request('GET', Uri.parse('https://example.com')));

      expect(response.statusCode, equals(200));
      client.close();
    });

    test('throws OperationCancelledException when token is pre-cancelled',
        () async {
      final token = CancellationToken();
      token.cancel();
      final client = CancellableHttpClient(
          inner: _DelayingClient(Duration(milliseconds: 100)), token: token);

      expect(
        () => client.send(http.Request('GET', Uri.parse('https://example.com'))),
        throwsA(isA<OperationCancelledException>()),
      );
      client.close();
    });

    test('throws OperationCancelledException when token is cancelled mid-request',
        () async {
      final token = CancellationToken();
      final client = CancellableHttpClient(
          inner: _DelayingClient(Duration(milliseconds: 300)), token: token);

      final sendFuture =
          client.send(http.Request('GET', Uri.parse('https://example.com')));

      await Future.delayed(Duration(milliseconds: 50));
      token.cancel();

      await expectLater(sendFuture, throwsA(isA<OperationCancelledException>()));
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
          final client = CancellableHttpClient(
              inner: _DelayingClient(Duration(milliseconds: 500)),
              token: context.cancellationToken);
          try {
            return await client
                .send(http.Request('GET', Uri.parse('https://example.com')));
          } finally {
            client.close();
          }
        }),
        throwsA(isA<TimeoutRejectedException>()),
      );

      expect(capturedToken?.isCancelled, isTrue);
    });

    test('sendAbortable completes normally when token is not cancelled',
        () async {
      final token = CancellationToken();
      final client = CancellableHttpClient(
          inner: _DelayingClient(Duration(milliseconds: 10)), token: token);

      final response =
          await client.sendAbortable('GET', Uri.parse('https://example.com'));
      expect(response.statusCode, equals(200));
      client.close();
    });

    test('sendAbortable throws when token is pre-cancelled', () async {
      final token = CancellationToken();
      token.cancel();
      final client = CancellableHttpClient(
          inner: _DelayingClient(Duration(milliseconds: 100)), token: token);

      expect(
        () => client.sendAbortable('GET', Uri.parse('https://example.com')),
        throwsA(isA<OperationCancelledException>()),
      );
      client.close();
    });
  });
}
