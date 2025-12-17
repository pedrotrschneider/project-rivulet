import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rivulet/features/discovery/domain/discovery_models.dart';
import 'package:rivulet/features/downloads/services/file_system_service.dart';
import 'package:path/path.dart' as p;

part 'offline_providers.g.dart';

/// Returns a list of unique media available on the filesystem.
/// Used for the "Library" view in Downloads screen.
@riverpod
Future<List<MediaDetail>> downloadedContent(Ref ref) async {
  final fs = ref.read(fileSystemServiceProvider);
  final mediaDirs = await fs.listMedia();
  final List<MediaDetail> list = [];

  for (final dir in mediaDirs) {
    try {
      final json = await fs.readJson(dir, 'details.json');
      if (json != null) {
        // Construct paths for local images
        // We stored 'poster.jpg' and 'backdrop.jpg' in the directory
        final posterPath = p.join(dir.path, 'poster.jpg');
        final backdropPath = p.join(dir.path, 'backdrop.jpg');
        final logoPath = p.join(dir.path, 'logo.png');

        list.add(
          MediaDetail(
            id: json['id'] ?? json['folderId'] ?? '', // TMDB ID or UUID
            title: json['title'] ?? 'Unknown',
            posterUrl: posterPath, // Use local path convention
            backdropUrl: backdropPath,
            logo: logoPath,
            overview: json['overview'] ?? '',
            type: json['type'] ?? 'movie',
            imdbId: json['imdbId'],
            rating: (json['voteAverage'] as num?)?.toDouble() ?? 0.0,
            releaseDate: null,
            // Store original poster url if needed? json['posterUrl']
          ),
        );
      }
    } catch (e) {
      print('Error parsing media at ${dir.path}: $e');
    }
  }
  return list;
}

/// Helper to get media detail from filesystem for offline mode
@riverpod
Future<MediaDetail> offlineMediaDetail(Ref ref, {required String id}) async {
  final fs = ref.read(fileSystemServiceProvider);
  // Id passed here might be MediaUuid or FolderId (ImdbId).
  // We need to find the directory.
  // Assumption: The ID passed is the folder name OR we have to search.
  // The 'Library' list returns items with `id` = `json['id']`.
  // If `json['id']` != folderName, we have a mismatch.
  // In `DownloadService`, we used `folderId = imdbId ?? mediaUuid`.
  // And we wrote `id: mediaUuid` in json.
  // So `downloadedContent` returns `MediaDetail` with `id: mediaUuid`.
  // `MediaDetailScreen` calls this provider with `widget.itemId` (mediaUuid).

  // Searching logic:
  // 1. Check if directory exists with this ID directly (e.g. if it was IMDB ID).
  // 2. Scan all directories and check `details.json` for matching `id`.

  final mediaDirs = await fs.listMedia();
  for (final dir in mediaDirs) {
    if (p.basename(dir.path) == id) {
      // Direct match (unlikely if id is UUID and folder is IMDB)
      final json = await fs.readJson(dir, 'details.json');
      if (json != null) {
        return _mapJsonToDetail(json, dir.path);
      }
    }
  }

  // Scan
  for (final dir in mediaDirs) {
    final json = await fs.readJson(dir, 'details.json');
    if (json != null && (json['id'] == id || json['folderId'] == id)) {
      return _mapJsonToDetail(json, dir.path);
    }
  }

  throw Exception('Media not found offline');
}

MediaDetail _mapJsonToDetail(Map<String, dynamic> json, String dirPath) {
  return MediaDetail(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    posterUrl: p.join(dirPath, 'poster.jpg'),
    backdropUrl: p.join(dirPath, 'backdrop.jpg'),
    logo: p.join(dirPath, 'logo.png'),
    overview: json['overview'] ?? '',
    type: json['type'] ?? 'movie',
    imdbId: json['imdbId'],
    rating: (json['voteAverage'] as num?)?.toDouble() ?? 0.0,
  );
}

/// Helper to get seasons/episodes from filesystem
@riverpod
Future<SeasonDetail> offlineSeasonEpisodes(
  Ref ref, {
  required String id,
  required int seasonNum,
}) async {
  final fs = ref.read(fileSystemServiceProvider);

  // Find correct directory first (same logic as above)
  String? folderId;
  final mediaDirs = await fs.listMedia();
  for (final dir in mediaDirs) {
    final json = await fs.readJson(dir, 'details.json');
    if (json != null && (json['id'] == id || p.basename(dir.path) == id)) {
      folderId = p.basename(dir.path);
      break;
    }
  }

  if (folderId == null) throw Exception('Media not found');

  final epDirs = await fs.listEpisodes(folderId, seasonNum);
  final List<DiscoveryEpisode> episodes = [];

  for (final epDir in epDirs) {
    final json = await fs.readJson(epDir, 'details.json');
    if (json != null) {
      final name = p.basename(epDir.path); // E01
      final epNum = int.tryParse(name.substring(1)) ?? 0;

      episodes.add(
        DiscoveryEpisode(
          id: 0, // dummy
          name: json['title'] ?? 'Episode $epNum',
          overview: json['overview'] ?? '',
          stillPath: p.join(epDir.path, 'still.jpg'),
          episodeNumber: epNum,
          voteAverage: (json['voteAverage'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }
  }

  // Sort
  episodes.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

  return SeasonDetail(
    id: 0,
    name: 'Season $seasonNum',
    seasonNumber: seasonNum,
    episodes: episodes,
  );
}

// Available seasons
@riverpod
Future<List<DiscoverySeason>> offlineAvailableSeasons(
  Ref ref, {
  required String id,
}) async {
  final fs = ref.read(fileSystemServiceProvider);

  // Find correct directory first
  String? folderId;
  final mediaDirs = await fs.listMedia();
  for (final dir in mediaDirs) {
    final json = await fs.readJson(dir, 'details.json');
    if (json != null && (json['id'] == id || p.basename(dir.path) == id)) {
      folderId = p.basename(dir.path);
      break;
    }
  }

  if (folderId == null) return [];

  final seasonDirs = await fs.listSeasons(folderId);
  final seasonDirMap = {
    for (var d in seasonDirs)
      int.tryParse(p.basename(d.path).substring(1)) ?? -1: d,
  };

  final List<DiscoverySeason> seasons = [];
  final mediaDir = await fs.getMediaDirectory(folderId);
  final seasonsJson = await fs.readJsonList(mediaDir, 'seasons.json');

  if (seasonsJson != null) {
    // metadata + check existence
    for (final json in seasonsJson) {
      if (json is Map<String, dynamic>) {
        final s = DiscoverySeason.fromJson(json);
        if (seasonDirMap.containsKey(s.seasonNumber)) {
          final sDir = seasonDirMap[s.seasonNumber]!;
          final epDirs = await fs.listEpisodes(folderId, s.seasonNumber);

          seasons.add(
            DiscoverySeason(
              id: s.id,
              name: s.name,
              seasonNumber: s.seasonNumber,
              airDate: s.airDate,
              episodeCount: epDirs.length, // Use actual local count
              posterPath: p.join(sDir.path, 'poster.jpg'), // Use local poster
            ),
          );
        }
      }
    }
  } else {
    // Fallback: Scan directories
    for (final sDir in seasonDirs) {
      final name = p.basename(sDir.path); // S01
      final sNum = int.tryParse(name.substring(1)) ?? 0;

      // We could count episodes inside
      final epDirs = await fs.listEpisodes(folderId, sNum);

      seasons.add(
        DiscoverySeason(
          id: 0,
          name: 'Season $sNum',
          seasonNumber: sNum,
          episodeCount: epDirs.length,
          posterPath: p.join(sDir.path, 'poster.jpg'),
        ),
      );
    }
  }

  seasons.sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
  return seasons;
}
