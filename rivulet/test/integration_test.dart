import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:rivulet/api/real_debrid_client.dart';
import 'package:rivulet/api/torrentio_client.dart';
import 'package:rivulet/features/search/search_screen.dart';

// Generate mocks
@GenerateMocks([TorrentioClient, RealDebridClient])
import 'integration_test.mocks.dart';

void main() {
  // Mock media_kit native calls if possible, or just ignore them since we are in a test environment.
  // However, PlayerScreen uses Player() which calls native code.
  // We might need to mock Player or avoid rendering PlayerScreen fully.
  // For this test, we can verify navigation happened.

  // Ensure binding initialized
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock MediaKit.ensureInitialized to avoid native errors in test environment if possible
  // Actually, media_kit might throw if native libs are missing.
  // We can try to run it. If it fails, we might need to mock the Player class or use a fake.

  group('Integration Test', () {
    late MockTorrentioClient mockTorrentioClient;
    late MockRealDebridClient mockRealDebridClient;

    setUp(() {
      mockTorrentioClient = MockTorrentioClient();
      mockRealDebridClient = MockRealDebridClient();
    });

    testWidgets('Smoke test', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Smoke'))),
      );
      expect(find.text('Smoke'), findsOneWidget);
    });

    testWidgets('Simple smoke test with imports', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Smoke'))),
      );
      expect(find.text('Smoke'), findsOneWidget);
    });

    testWidgets('Full flow: Search -> Select -> Play', (tester) async {
      // Setup Mocks
      when(mockTorrentioClient.getStreams(any)).thenAnswer(
        (_) async => [
          TorrentioStream(
            title: 'Inception 1080p',
            infoHash: 'test_hash',
            name: 'Torrentio',
          ),
        ],
      );

      when(
        mockRealDebridClient.addMagnet(any),
      ).thenAnswer((_) async => 'torrent_id');

      when(mockRealDebridClient.getTorrentInfo(any)).thenAnswer(
        (_) async => {
          'id': 'torrent_id',
          'status': 'downloaded',
          'links': ['https://real-debrid.com/d/LINK'],
        },
      );

      when(
        mockRealDebridClient.unrestrictLink(any),
      ).thenAnswer((_) async => 'https://stream.url/video.mp4');

      // Pump Widget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            torrentioClientProvider.overrideWithValue(mockTorrentioClient),
            realDebridClientProvider.overrideWithValue(mockRealDebridClient),
          ],
          child: MaterialApp(
            home: const SearchScreen(),
            onGenerateRoute: (settings) {
              if (settings.name == '/player') {
                return MaterialPageRoute(
                  builder: (context) =>
                      const Scaffold(body: Text('Mock Player Screen')),
                );
              }
              return null;
            },
          ),
        ),
      );

      expect(find.byType(SearchScreen), findsOneWidget);

      // 1. Enter Token
      await tester.enterText(find.byType(TextField).at(0), 'fake_token');
      await tester.pump();

      // 2. Enter IMDB ID
      await tester.enterText(find.byType(TextField).at(1), 'tt1375666');
      await tester.pump();

      // 3. Click Search
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump(); // Start search
      await tester.pump(); // Finish search (async)

      // Verify results
      expect(find.text('Inception 1080p'), findsOneWidget);

      // 4. Click Stream
      await tester.tap(find.text('Inception 1080p'));
      await tester.pump(); // Start async calls

      // We need to pump for async operations (addMagnet, getInfo, unrestrictLink)
      await tester.pump(const Duration(milliseconds: 100)); // addMagnet
      await tester.pump(const Duration(milliseconds: 100)); // getTorrentInfo
      await tester.pump(const Duration(milliseconds: 100)); // unrestrictLink
      await tester.pumpAndSettle(); // Navigation

      // Verify calls
      verify(mockTorrentioClient.getStreams('tt1375666')).called(1);
      verify(
        mockRealDebridClient.addMagnet('magnet:?xt=urn:btih:test_hash'),
      ).called(1);
      verify(mockRealDebridClient.getTorrentInfo('torrent_id')).called(1);
      verify(
        mockRealDebridClient.unrestrictLink('https://real-debrid.com/d/LINK'),
      ).called(1);

      // Verify Navigation to Mock Player Screen
      expect(find.text('Mock Player Screen'), findsOneWidget);
    });
  });
}
