import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Shared Dio client with retry logic and timeouts for all API services.
Dio createApiClient() {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  dio.interceptors.add(_RetryInterceptor(dio));
  return dio;
}

class _RetryInterceptor extends Interceptor {
  final Dio _dio;
  static const _maxRetries = 2;
  static const _retryableTypes = {
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
  };

  _RetryInterceptor(this._dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;

    if (retryCount < _maxRetries && _retryableTypes.contains(err.type)) {
      debugPrint('Retrying request (${retryCount + 1}/$_maxRetries): ${err.requestOptions.uri}');

      err.requestOptions.extra['retryCount'] = retryCount + 1;

      // Exponential backoff: 500ms, 1000ms
      await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));

      try {
        final response = await _dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (e) {
        // Fall through to handler.next below
      }
    }

    handler.next(err);
  }
}
