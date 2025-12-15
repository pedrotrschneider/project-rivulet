import 'dart:async';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/auth/auth_provider.dart';

part 'rivulet_api.g.dart';

final unauthorizedEvent = StreamController<void>.broadcast();

@riverpod
Dio dio(Ref ref) {
  final serverUrl = ref.watch(serverUrlProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: (serverUrl != null && serverUrl.isNotEmpty)
          ? '${serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl}/api/v1'
          : '',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  dio.interceptors.add(LoggerInterceptor());
  dio.interceptors.add(AuthInterceptor(const FlutterSecureStorage()));
  dio.interceptors.add(ErrorInterceptor());

  return dio;
}

class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  static const _profileKey = 'selected_profile_id';

  AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Add auth token
    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Add profile ID from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final profileId = prefs.getString(_profileKey);
    if (profileId != null) {
      options.headers['X-Profile-ID'] = profileId;
    }

    handler.next(options);
  }

  // TODO: Handle 401 Refresh Logic here later
}

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      unauthorizedEvent.add(null);
    }
    super.onError(err, handler);
  }
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
