import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'domain/discovery_models.dart';
import 'repository/discovery_repository.dart';

part 'discovery_provider.g.dart';

@riverpod
class DiscoverySearch extends _$DiscoverySearch {
  @override
  FutureOr<List<DiscoveryItem>> build() {
    return [];
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
