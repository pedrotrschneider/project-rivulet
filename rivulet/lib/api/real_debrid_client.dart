import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// We will need a way to set the token. For now, we can use a StateProvider or similar.
// But for the client itself, let's pass the token or a token provider.
// For simplicity in this phase, I'll assume the token is passed to methods or set on the client.

final realDebridClientProvider = Provider((ref) => RealDebridClient());

class RealDebridClient {
  final Dio _dio;

  RealDebridClient({Dio? dio})
    : _dio =
          dio ??
          Dio(BaseOptions(baseUrl: 'https://api.real-debrid.com/rest/1.0')) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['User-Agent'] = 'Rivulet/1.0';
          if (_apiToken != null) {
            options.headers['Authorization'] = 'Bearer $_apiToken';
          }
          print('Request: ${options.method} ${options.uri}');
          print('Headers: ${options.headers}');
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          print('DioError: ${e.message}');
          if (e.response != null) {
            print('Response: ${e.response?.statusCode} ${e.response?.data}');
          }
          return handler.next(e);
        },
      ),
    );
  }

  // In a real app, this would come from secure storage
  String? _apiToken;

  void setToken(String token) {
    _apiToken = token.trim();
  }

  Future<String> addMagnet(String magnet) async {
    try {
      final response = await _dio.post(
        '/torrents/addMagnet',
        data: {'magnet': magnet},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return response.data['id'];
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception(
          'Access Denied (403). Token: ${_apiToken?.substring(0, 5)}... Response: ${e.response?.data}',
        );
      }
      print('Error adding magnet: $e');
      rethrow;
    } catch (e) {
      print('Error adding magnet: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTorrentInfo(String id) async {
    try {
      final response = await _dio.get('/torrents/info/$id');
      return response.data;
    } catch (e) {
      print('Error getting torrent info: $e');
      rethrow;
    }
  }

  Future<void> selectFiles(String id, String files) async {
    try {
      await _dio.post(
        '/torrents/selectFiles/$id',
        data: {'files': files},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } catch (e) {
      print('Error selecting files: $e');
      rethrow;
    }
  }

  Future<String?> unrestrictLink(String link) async {
    if (_apiToken == null) throw Exception('API Token not set');

    try {
      final response = await _dio.post(
        '/unrestrict/link',
        data: {'link': link},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return response.data['download'];
    } catch (e) {
      print('Error unrestricting link: $e');
      rethrow;
    }
  }
}
