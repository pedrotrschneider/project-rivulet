import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rivulet/features/auth/profiles_provider.dart';
import 'package:rivulet/features/discovery/domain/discovery_models.dart';
import 'package:rivulet/features/downloads/services/file_system_service.dart';
import 'package:path/path.dart' as p;

part 'offline_providers.g.dart';

/// Returns a list of unique media available on the filesystem.
/// Used for the "Library" view in Downloads screen.
@riverpod
Future<List<MediaDetail>> downloadedContent(Ref ref) async {
  final fs = ref.read(fileSystemServiceProvider);
  final profileId = ref.watch(selectedProfileProvider);
  final mediaDirs = await fs.listMedia(profileId: profileId);
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
  final profileId = ref.watch(selectedProfileProvider);
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

  final mediaDirs = await fs.listMedia(profileId: profileId);
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
  final profileId = ref.watch(selectedProfileProvider);

  // Find correct directory first (same logic as above)
  String? folderId;
  final mediaDirs = await fs.listMedia(profileId: profileId);
  for (final dir in mediaDirs) {
    final json = await fs.readJson(dir, 'details.json');
    if (json != null && (json['id'] == id || p.basename(dir.path) == id)) {
      folderId = p.basename(dir.path);
      break;
    }
  }

  if (folderId == null) throw Exception('Media not found');

  final epDirs = await fs.listEpisodes(
    folderId,
    seasonNum,
    profileId: profileId,
  );
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
  final profileId = ref.watch(selectedProfileProvider);

  // Find correct directory first
  String? folderId;
  final mediaDirs = await fs.listMedia(profileId: profileId);
  for (final dir in mediaDirs) {
    final json = await fs.readJson(dir, 'details.json');
    if (json != null && (json['id'] == id || p.basename(dir.path) == id)) {
      folderId = p.basename(dir.path);
      break;
    }
  }

  if (folderId == null) return [];

  final seasonDirs = await fs.listSeasons(folderId, profileId: profileId);
  final seasonDirMap = {
    for (var d in seasonDirs)
      int.tryParse(p.basename(d.path).substring(1)) ?? -1: d,
  };

  final List<DiscoverySeason> seasons = [];
  final mediaDir = await fs.getMediaDirectory(folderId, profileId: profileId);
  final seasonsJson = await fs.readJsonList(mediaDir, 'seasons.json');

  if (seasonsJson != null) {
    // metadata + check existence
    for (final json in seasonsJson) {
      if (json is Map<String, dynamic>) {
        final s = DiscoverySeason.fromJson(json);
        if (seasonDirMap.containsKey(s.seasonNumber)) {
          final sDir = seasonDirMap[s.seasonNumber]!;
          final epDirs = await fs.listEpisodes(
            folderId,
            s.seasonNumber,
            profileId: profileId,
          );

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
      final epDirs = await fs.listEpisodes(
        folderId,
        sNum,
        profileId: profileId,
      );

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

@riverpod
Future<List<HistoryItem>> offlineMediaHistory(
  Ref ref, {
  required String id,
}) async {
  final fs = ref.read(fileSystemServiceProvider);
  final profileId = ref.watch(selectedProfileProvider);
  final dir = await fs.getMediaDirectory(id, profileId: profileId);

  // 1. Read cached API history
  final cachedData = await fs.readJsonList(dir, 'history.json');
  final List<HistoryItem> cachedHistory = cachedData != null
      ? cachedData.map((json) => HistoryItem.fromJson(json)).toList()
      : [];

  // 2. Read pending offline history
  final offlineData = await fs.readJsonList(dir, 'offline_history.json');
  final List<HistoryItem> pendingHistory = [];

  if (offlineData != null) {
    for (final json in offlineData) {
      // Convert progress map to HistoryItem structure
      // Progress keys: external_id, imdb_id, type, season, episode, position_ticks, duration_ticks, is_watched, timestamp
      pendingHistory.add(
        HistoryItem(
          mediaId: json['external_id'] ?? '',
          episodeId: json['episode_id']?.toString(), // Potentially available
          type: json['type'] ?? 'movie',
          title: '', // Not stored in progress map
          posterPath: '',
          backdropPath: '',
          seasonNumber: json['season'],
          episodeNumber: json['episode'],
          positionTicks: json['position_ticks'] ?? 0,
          durationTicks: json['duration_ticks'] ?? 0,
          isWatched: json['is_watched'] ?? false,
          lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(
            (json['timestamp'] ?? 0) * 1000,
          ).toIso8601String(),
        ),
      );
    }
  }

  // 3. Merge Strategies
  // Map by "season-episode" or "movie-id" key
  final Map<String, HistoryItem> merged = {};

  // Add cached first
  for (final item in cachedHistory) {
    if (item.type == 'movie') {
      merged['movie'] = item;
    } else {
      merged['${item.seasonNumber}-${item.episodeNumber}'] = item;
    }
  }

  // Overlay pending (they are newer by definition if they exist)
  for (final item in pendingHistory) {
    if (item.type == 'movie') {
      // Preserve static metadata from cached if available
      if (merged.containsKey('movie')) {
        final old = merged['movie']!;
        merged['movie'] = item.copyWith(
          title: old.title,
          posterPath: old.posterPath,
          backdropPath: old.backdropPath,
        );
      } else {
        merged['movie'] = item;
      }
    } else {
      final key = '${item.seasonNumber}-${item.episodeNumber}';
      if (merged.containsKey(key)) {
        final old = merged[key]!;
        merged[key] = item.copyWith(
          title: old.title,
          posterPath: old.posterPath,
          backdropPath: old.backdropPath,
          nextEpisodeTitle: old.nextEpisodeTitle, // Keep these if possible
        );
      } else {
        merged[key] = item;
      }
    }
  }

  return merged.values.toList();
}
