import 'package:flutter_test/flutter_test.dart';
import 'package:rivulet/api/torrentio_client.dart';

void main() {
  group('TorrentioClient', () {
    late TorrentioClient client;

    setUp(() {
      client = TorrentioClient();
    });

    test('getStreams returns streams for Inception (tt1375666)', () async {
      final streams = await client.getStreams('tt1375666');
      
      expect(streams, isNotEmpty);
      expect(streams.first.infoHash, isNotNull);
      expect(streams.first.title, isNotNull);
      
      // Print first stream for manual verification
      print('First stream title: ${streams.first.title}');
      print('First stream infoHash: ${streams.first.infoHash}');
    });
  });
}
