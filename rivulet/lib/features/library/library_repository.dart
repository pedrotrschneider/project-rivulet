import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../discovery/domain/discovery_models.dart';
import '../../api/rivulet_api.dart';

part 'library_repository.g.dart';

class LibraryResponse {
  final List<DiscoveryItem> results;
  final int page;

  LibraryResponse({required this.results, required this.page});

  factory LibraryResponse.fromJson(Map<String, dynamic> json) {
    final results = json['results'] as List<dynamic>? ?? [];
    return LibraryResponse(
      results: results
          .map((item) => DiscoveryItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 1,
    );
  }
}

class LibraryRepository {
  final Dio _dio;

  LibraryRepository(this._dio);

  /// Fetches the library with optional filters.
  Future<LibraryResponse> fetchLibrary({
    int page = 1,
    String? type, // 'movie' or 'show'
  }) async {
    final queryParams = <String, dynamic>{'page': page};
    if (type != null && type.isNotEmpty) {
      queryParams['type'] = type;
    }

    // Backend now mirrors TMDB structure: { "results": [...], "page": 1 }
    final response = await _dio.get('/library', queryParameters: queryParams);
    return LibraryResponse.fromJson(response.data as Map<String, dynamic>);
  }
}

@riverpod
LibraryRepository libraryRepository(Ref ref) {
  final dio = ref.watch(dioProvider);
  return LibraryRepository(dio);
}
