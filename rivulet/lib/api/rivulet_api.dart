import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_provider.dart';

part 'rivulet_api.g.dart';

@riverpod
Dio dio(Ref ref) {
  final serverUrl = ref.watch(serverUrlProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: serverUrl ?? '',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  dio.interceptors.add(LoggerInterceptor());
  dio.interceptors.add(AuthInterceptor(const FlutterSecureStorage()));

  return dio;
}

class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;

  AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  // TODO: Handle 401 Refresh Logic here later
}

class LoggerInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('--- API Error ---');
    print('Request: ${err.requestOptions.method} ${err.requestOptions.path}');
    print('Headers: ${err.requestOptions.headers}');
    print('Query Query: ${err.requestOptions.queryParameters}');
    print('Request Data: ${err.requestOptions.data}');

    if (err.response != null) {
      print('Response Status: ${err.response?.statusCode}');
      print('Response Data: ${err.response?.data}');
    } else {
      print('Response: No response received');
      print('Message: ${err.message}');
    }
    print('-----------------');
    super.onError(err, handler);
  }
}
