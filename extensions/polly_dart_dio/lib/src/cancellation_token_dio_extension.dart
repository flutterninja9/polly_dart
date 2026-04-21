import 'package:dio/dio.dart' as dio;
import 'package:polly_dart/polly_dart.dart';

extension CancellationTokenDioExtension on CancellationToken {
  /// Returns a Dio [CancelToken] that is cancelled when this token is cancelled.
  ///
  /// Each call returns a distinct [CancelToken]. If this token is already
  /// cancelled, the returned token will be cancelled after the next microtask.
  ///
  /// ```dart
  /// pipeline.execute((context) async {
  ///   final response = await dioClient.get(
  ///     '/data',
  ///     cancelToken: context.cancellationToken.toDioCancelToken(),
  ///   );
  ///   return response.data;
  /// });
  /// ```
  dio.CancelToken toDioCancelToken() {
    final dioToken = dio.CancelToken();
    whenCancelled.then((_) {
      if (!dioToken.isCancelled) {
        dioToken.cancel('Cancelled by polly_dart pipeline');
      }
    });
    return dioToken;
  }
}
