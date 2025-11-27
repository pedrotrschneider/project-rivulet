import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:rivulet/api/real_debrid_client.dart';

void main() {
  group('RealDebridClient', () {
    late RealDebridClient client;
    late Dio dio;
    late DioAdapter dioAdapter;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.real-debrid.com/rest/1.0'));
      dioAdapter = DioAdapter(dio: dio);
      client = RealDebridClient(dio: dio);
      client.setToken('test_token');
    });

    test('addMagnet returns torrent id', () async {
      const magnet = 'magnet:?xt=urn:btih:test_hash';
      const responsePayload = {'id': 'torrent_id'};

      dioAdapter.onPost(
        '/torrents/addMagnet',
        (server) => server.reply(201, responsePayload),
        data: {'magnet': magnet},
      );

      final result = await client.addMagnet(magnet);
      expect(result, 'torrent_id');
    });

    test('getTorrentInfo returns info', () async {
      const id = 'torrent_id';
      const responsePayload = {'id': 'torrent_id', 'status': 'downloaded'};

      dioAdapter.onGet(
        '/torrents/info/$id',
        (server) => server.reply(200, responsePayload),
      );

      final result = await client.getTorrentInfo(id);
      expect(result['status'], 'downloaded');
    });

    test('selectFiles posts correctly', () async {
      const id = 'torrent_id';
      const files = 'all';

      dioAdapter.onPost(
        '/torrents/selectFiles/$id',
        (server) => server.reply(204, null),
        data: {'files': files},
      );

      await client.selectFiles(id, files);
    });

    test('unrestrictLink returns download link', () async {
      const link = 'test_link';
      const responsePayload = {'download': 'https://download.link'};

      dioAdapter.onPost(
        '/unrestrict/link',
        (server) => server.reply(200, responsePayload),
        data: {'link': link},
        headers: {'Authorization': 'Bearer test_token'},
      );

      final result = await client.unrestrictLink(link);
      expect(result, 'https://download.link');
    });
  });
}
