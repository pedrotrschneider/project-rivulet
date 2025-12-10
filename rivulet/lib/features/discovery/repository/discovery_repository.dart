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

  Future<void> addToLibrary(String id) async {
    await _dio.post('/library', data: {'external_id': id});
  }
}

@riverpod
DiscoveryRepository discoveryRepository(Ref ref) {
  final dio = ref.watch(dioProvider);
  return DiscoveryRepository(dio);
}
