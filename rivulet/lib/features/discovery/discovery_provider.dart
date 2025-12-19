import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rivulet/features/auth/profiles_provider.dart';
import 'package:rivulet/features/downloads/services/file_system_service.dart';
import 'domain/discovery_models.dart';
import 'repository/discovery_repository.dart';

part 'discovery_provider.g.dart';

@riverpod
class DiscoverySearch extends _$DiscoverySearch {
  @override
  FutureOr<List<DiscoveryItem>> build() async {
    final repository = ref.read(discoveryRepositoryProvider);
    return await repository.search('');
  }

  Future<void> search(String query) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(discoveryRepositoryProvider);
      final results = await repository.search(query);
      state = AsyncValue.data(results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

@riverpod
Future<MediaDetail> mediaDetail(
  Ref ref, {
  required String id,
  required String type,
}) {
  return ref.read(discoveryRepositoryProvider).getDetails(id, type: type);
}

@riverpod
Future<List<DiscoverySeason>> showSeasons(Ref ref, String id) {
  return ref.read(discoveryRepositoryProvider).getShowSeasons(id);
}

@riverpod
Future<SeasonDetail> seasonEpisodes(
  Ref ref, {
  required String id,
  required int seasonNum,
}) {
  return ref.read(discoveryRepositoryProvider).getSeasonDetails(id, seasonNum);
}

@riverpod
Future<List<StreamResult>> streamScraper(
  Ref ref, {
  required String externalId,
  required String type,
  int? season,
  int? episode,
}) {
  return ref
      .read(discoveryRepositoryProvider)
      .scrapeStreams(
        externalId: externalId,
        type: type,
        season: season,
        episode: episode,
      );
}

@riverpod
Future<List<HistoryItem>> mediaHistory(
  Ref ref, {
  required String externalId,
}) async {
  final results = await ref
      .read(discoveryRepositoryProvider)
      .getMediaHistory(externalId);

  if (results.isNotEmpty) {
    // Cache to local file system for offline use
    // Fire and forget to not block UI
    Future(() async {
      try {
        final profileId = ref.read(selectedProfileProvider);
        final fs = ref.read(fileSystemServiceProvider);
        final dir = await fs.getMediaDirectory(
          externalId,
          profileId: profileId,
        );
        await fs.writeJson(
          dir,
          'history.json',
          results.map((e) => e.toJson()).toList(),
        );
      } catch (e) {
        print('Error caching history: $e');
      }
    });
  }

  return results;
}
