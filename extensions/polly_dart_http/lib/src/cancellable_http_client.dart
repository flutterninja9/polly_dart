import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:polly_dart/polly_dart.dart';

class CancellableHttpClient extends http.BaseClient {
  final http.Client _inner;
  final CancellationToken _token;

  CancellableHttpClient({
    http.Client? inner,
    required CancellationToken token,
  })  : _inner = inner ?? http.Client(),
        _token = token;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    _token.throwIfCancelled();

    return Future.any([
      _inner.send(request),
      _token.whenCancelled.then<http.StreamedResponse>(
        (_) =>
            throw const OperationCancelledException('HTTP request was cancelled'),
      ),
    ]);
  }

  /// Sends a cancellable request using [http.AbortableRequest] for socket-level abort.
  ///
  /// Prefer this over [send] for new code where you control request construction.
  /// The socket connection is closed as soon as the [CancellationToken] is cancelled.
  Future<http.StreamedResponse> sendAbortable(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    _token.throwIfCancelled();

    final request = http.AbortableRequest(
      method,
      url,
      abortTrigger: _token.whenCancelled,
    );
    if (headers != null) request.headers.addAll(headers);
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is List<int>) {
        request.bodyBytes = body;
      } else if (body is Map<String, String>) {
        request.bodyFields = body;
      }
    }
    if (encoding != null) request.encoding = encoding;

    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
