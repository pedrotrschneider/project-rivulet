import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:rivulet/api/real_debrid_client.dart';

void main() {
  group('RealDebridClient Error Handling', () {
    late RealDebridClient client;
    late Dio dio;
    late DioAdapter dioAdapter;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.real-debrid.com/rest/1.0'));
      dioAdapter = DioAdapter(dio: dio);
      client = RealDebridClient(dio: dio);
      client.setToken('test_token');
    });

    test('addMagnet throws friendly exception on 403', () async {
      const magnet = 'magnet:?xt=urn:btih:test_hash';

      dioAdapter.onPost(
        '/torrents/addMagnet',
        (server) => server.reply(403, {'error': 'access_denied'}),
        data: {'magnet': magnet},
      );

      expect(
        () => client.addMagnet(magnet),
        throwsA(
          predicate(
            (e) =>
                e is Exception && e.toString().contains('Access Denied (403)'),
          ),
        ),
      );
    });
  });
}
