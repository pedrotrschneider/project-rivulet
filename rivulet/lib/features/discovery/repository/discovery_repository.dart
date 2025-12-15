import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../api/rivulet_api.dart';
import '../domain/discovery_models.dart';

part 'discovery_repository.g.dart';

class DiscoveryRepository {
  final Dio _dio;

  DiscoveryRepository(this._dio);

  Future<List<DiscoveryItem>> search(String query) async {
    final response = await _dio.get(
      '/discover/search',
      queryParameters: {'q': query},
    );

    // API returns a list of items directly or wrapped in data?
    // Assuming List based on typical behavior, but robust check is good.
    final List data = response.data is List
        ? response.data
        : response.data['data'] ?? [];

    return data.map((json) => DiscoveryItem.fromJson(json)).toList();
  }

  Future<MediaDetail> getDetails(String id, {String? type}) async {
    final response = await _dio.get(
      '/discover/details/$id',
      queryParameters: type != null ? {'type': type} : null,
    );
    return MediaDetail.fromJson(response.data);
  }

  Future<List<DiscoverySeason>> getShowSeasons(String id) async {
    final response = await _dio.get('/discover/tv/$id/seasons');
    return (response.data as List)
        .map((json) => DiscoverySeason.fromJson(json))
        .toList();
  }

  Future<SeasonDetail> getSeasonDetails(String id, int seasonNum) async {
    final response = await _dio.get('/discover/tv/$id/season/$seasonNum');
    return SeasonDetail.fromJson(response.data);
  }

  Future<void> addToLibrary(String id, String type) async {
    await _dio.post('/library', data: {'external_id': id, 'media_type': type});
  }

  Future<bool> checkLibraryStatus(String id) async {
    try {
      final response = await _dio.get('/library/check/$id');
      return response.data['in_library'] as bool;
    } catch (_) {
      return false;
    }
  }

  Future<void> removeFromLibrary(String id) async {
    await _dio.delete('/library/$id');
  }

  Future<List<StreamResult>> scrapeStreams({
    required String externalId,
    required String type,
    int? season,
    int? episode,
  }) async {
    final response = await _dio.get(
      '/stream/scrape',
      queryParameters: {
        'external_id': externalId,
        'type': type,
        if (season != null) 'season': season,
        if (episode != null) 'episode': episode,
      },
    );
    return (response.data as List)
        .map((json) => StreamResult.fromJson(json))
        .toList();
  }

  Future<Map<String, dynamic>> resolveStream({
    required String magnet,
    int? season,
    int? episode,
    int? fileIndex,
  }) async {
    // Backend expects POST JSON
    final response = await _dio.post(
      '/stream/resolve',
      data: {
        'magnet': magnet,
        if (season != null) 'season': season,
        if (episode != null) 'episode': episode,
        if (fileIndex != null) 'file_index': fileIndex,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}

@riverpod
DiscoveryRepository discoveryRepository(Ref ref) {
  final dio = ref.watch(dioProvider);
  return DiscoveryRepository(dio);
}
