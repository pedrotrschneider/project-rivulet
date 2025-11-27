import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rivulet/api/torrentio_client.dart';

// 1. Use AsyncNotifierProvider instead of StateNotifierProvider
final searchResultsProvider = AsyncNotifierProvider<SearchNotifier, List<TorrentioStream>>(SearchNotifier.new);

// 2. Extend AsyncNotifier instead of StateNotifier
class SearchNotifier extends AsyncNotifier<List<TorrentioStream>> {
  
  @override
  FutureOr<List<TorrentioStream>> build() {
    // 3. Define the initial state here.
    // We return an empty list initially.
    return [];
  }

  Future<void> search(String imdbId) async {
    // 4. Set state to loading
    state = const AsyncValue.loading();
    
    // 5. Use AsyncValue.guard to automatically handle try/catch/error states
    state = await AsyncValue.guard(() async {
      // Access other providers using 'ref' (built-in property)
      final client = ref.read(torrentioClientProvider);
      return client.getStreams(imdbId);
    });
  }
}