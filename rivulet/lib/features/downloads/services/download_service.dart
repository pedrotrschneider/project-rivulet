import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rivulet/features/downloads/services/file_system_service.dart';

part 'download_service.g.dart';

@Riverpod(keepAlive: true)
DownloadService downloadService(Ref ref) {
  return DownloadService(ref.read(fileSystemServiceProvider), ref);
}

class DownloadService {
  final FileSystemService _fs;
  final Ref _ref;

  DownloadService(this._fs, this._ref) {
    _init();
  }

  Future<void> _init() async {
    await FileDownloader().configure(
      globalConfig: [(Config.requestTimeout, const Duration(seconds: 100))],
      androidConfig: [(Config.useCacheDir, Config.never)],
    );
    // Enable database tracking to populate allRecords
    await FileDownloader().trackTasks();
  }

  Future<void> startMovieDownload({
    required String mediaUuid,
    required String url,
    required String title,
    required String? logoPath,
    required String? posterPath,
    required String? backdropPath,
    required String? overview,
    required String? imdbId,
    required double? voteAverage,
    required String? profileId,
  }) async {
    await _startDownload(
      mediaUuid: mediaUuid,
      url: url,
      title: title,
      type: 'movie',
      logoPath: logoPath,
      posterPath: posterPath,
      backdropPath: backdropPath,
      overview: overview,
      imdbId: imdbId,
      voteAverage: voteAverage,
      profileId: profileId,
    );
  }

  Future<void> startEpisodeDownload({
    required String mediaUuid,
    required String url,
    required String title,
    required String? logoPath,
    required String? seasonPosterPath,
    required String? posterPath,
    required String? backdropPath,
    required String? overview,
    required String? imdbId,
    required double? voteAverage,
    required String? showTitle,
    required int? seasonNumber,
    required String? seasonOverview,
    required String? seasonName,
    required int? episodeNumber,
    required String? episodeOverview,
    required String? episodeStillPath,
    required String? episodeTitle,
    required List<Map<String, dynamic>>? seasons, // Accept raw JSON or model
    required String? profileId,
  }) async {
    await _startDownload(
      mediaUuid: mediaUuid,
      url: url,
      title: title,
      type: 'episode',
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      logoPath: logoPath,
      seasonPosterPath: seasonPosterPath,
      posterPath: posterPath,
      backdropPath: backdropPath,
      overview: overview,
      imdbId: imdbId,
      voteAverage: voteAverage,
      showTitle: showTitle,
      seasonOverview: seasonOverview,
      seasonName: seasonName,
      episodeOverview: episodeOverview,
      episodeStillPath: episodeStillPath,
      episodeTitle: episodeTitle,
      seasons: seasons,
      profileId: profileId,
    );
  }

  /// Starts a download.
  Future<void> _startDownload({
    required String mediaUuid,
    required String url,
    required String title,
    required String type, // 'movie' or 'episode'
    String? logoPath,
    String? seasonPosterPath,
    String? posterPath,
    String? backdropPath,
    String? overview,
    String? imdbId,
    double? voteAverage,
    String? showTitle,
    int? seasonNumber,
    String? seasonOverview,
    String? seasonName,
    int? episodeNumber,
    String? episodeOverview,
    String? episodeStillPath,
    String? episodeTitle,
    List<Map<String, dynamic>>? seasons, // Accept raw JSON or model
    String? profileId,
  }) async {
    // 1. Determine Identity and Directory
    // User requested "tt***" folder if possible.
    final folderId = imdbId ?? mediaUuid;

    // 2. Persist Metadata & Images (Filesystem Source of Truth)
    await _persistMetadata(
      folderId: folderId,
      mediaUuid: mediaUuid,
      title: title,
      type: type,
      posterPath: posterPath,
      backdropPath: backdropPath,
      logoPath: logoPath,
      seasonPosterPath: seasonPosterPath,
      overview: overview,
      imdbId: imdbId,
      voteAverage: voteAverage,
      showTitle: showTitle,
      seasonNumber: seasonNumber,
      seasonOverview: seasonOverview,
      seasonName: seasonName,
      episodeNumber: episodeNumber,
      episodeOverview: episodeOverview,
      episodeStillPath: episodeStillPath,
      episodeTitle: episodeTitle,
      seasons: seasons,
      profileId: profileId,
    );

    // 3. Determine Video File Path
    String saveDir;
    String filename;

    if (type == 'movie') {
      final movieDir = await _fs.getMediaDirectory(
        folderId,
        profileId: profileId,
      );
      saveDir = movieDir.path;
      filename = 'video.mp4';
    } else {
      // Episode
      final episodeDir = await _fs.getEpisodeDirectory(
        folderId,
        seasonNumber ?? 0,
        episodeNumber ?? 0,
        profileId: profileId,
      );
      saveDir = episodeDir.path;
      filename = 'video.mp4';
    }

    // 4. Create Task with Metadata for Active Downloads UI
    final metaData = jsonEncode({
      'type': type,
      'title': title,
      'posterPath': posterPath,
      'showTitle': showTitle,
      'season': seasonNumber,
      'episode': episodeNumber,
      'mediaId': folderId, // Used for navigation/grouping
    });

    final task = DownloadTask(
      url: url,
      filename: filename,
      baseDirectory: BaseDirectory.root,
      directory: saveDir,
      updates: Updates.statusAndProgress,
      allowPause: true,
      taskId:
          '${folderId}_${type}_${seasonNumber ?? 0}_${episodeNumber ?? 0}_${DateTime.now().millisecondsSinceEpoch}',
      metaData: metaData,
    );

    // 5. Enqueue
    await FileDownloader().enqueue(task);
  }

  Future<void> _persistMetadata({
    required String folderId,
    required String mediaUuid,
    required String title,
    required String type,
    String? logoPath,
    String? seasonPosterPath,
    String? posterPath,
    String? backdropPath,
    String? overview,
    String? imdbId,
    double? voteAverage,
    String? showTitle,
    int? seasonNumber,
    String? seasonOverview,
    String? seasonName,
    int? episodeNumber,
    String? episodeOverview,
    String? episodeStillPath,
    String? episodeTitle,
    List<Map<String, dynamic>>? seasons,
    String? profileId,
  }) async {
    // A. Media Level (Movie or Show)
    // Always write show/movie details to the root media folder
    final mediaDir = await _fs.getMediaDirectory(
      folderId,
      profileId: profileId,
    );

    // Write media.json
    // Use Show Title if it's an episode, else Title
    final mainTitle = type == 'movie' ? title : (showTitle ?? title);

    await _fs.writeJson(mediaDir, 'details.json', {
      'id': mediaUuid, // Internal ID
      'folderId': folderId,
      'title': mainTitle,
      'posterUrl':
          posterPath, // We might replace this with local path if we download it?
      'backdropUrl': backdropPath,
      'logo': logoPath, // Save logo path
      'overview': overview,
      'type': type == 'movie'
          ? 'movie'
          : 'show', // if fetching show, type is show. if fetching ep?
      // When downloading an episode, we are technically downloading a 'show' component.
      // But the 'type' param passed to startDownload depends on caller.
      // Usually caller passes 'episode' for episodes.
      // But for Library grouping we want 'show'.
      'imdbId': imdbId,
      'voteAverage': voteAverage,
    });

    // Write seasons.json if provided
    if (seasons != null) {
      await _fs.writeJson(mediaDir, 'seasons.json', seasons);
    }

    // Download Media Images
    if (posterPath != null) {
      await _fs.downloadImage(posterPath, mediaDir, 'poster.jpg');
    }
    if (backdropPath != null) {
      await _fs.downloadImage(backdropPath, mediaDir, 'backdrop.jpg');
    }
    if (logoPath != null) {
      await _fs.downloadImage(logoPath, mediaDir, 'logo.png');
    }

    // B. Season/Episode Level (if Show)
    if (type == 'episode' || type == 'show') {
      if (seasonNumber != null && episodeNumber != null) {
        final seasonDir = await _fs.getSeasonDirectory(
          folderId,
          seasonNumber,
          profileId: profileId,
        );
        await _fs.writeJson(seasonDir, 'season_details.json', {
          'seasonNumber': seasonNumber,
          'posterPath': seasonPosterPath, // Save season poster path
          'overview': seasonOverview,
          'name': seasonName,
        });

        if (seasonPosterPath != null) {
          await _fs.downloadImage(seasonPosterPath, seasonDir, 'poster.jpg');
        }

        final episodeDir = await _fs.getEpisodeDirectory(
          folderId,
          seasonNumber,
          episodeNumber,
          profileId: profileId,
        );

        await _fs.writeJson(episodeDir, 'details.json', {
          'title': episodeTitle ?? 'Episode $episodeNumber',
          'overview': episodeOverview,
          'voteAverage': voteAverage,
        });

        await _fs.downloadImage(
          episodeStillPath ?? '',
          episodeDir,
          'still.jpg',
        );
      }
    }
  }

  Future<void> pause(String taskId) async {
    final task = await _getTaskById(taskId);
    if (task != null) await FileDownloader().pause(task);
  }

  Future<void> resume(String taskId) async {
    final task = await _getTaskById(taskId);
    if (task != null) await FileDownloader().resume(task);
  }

  Future<void> cancel(String taskId) async {
    await FileDownloader().cancelTaskWithId(taskId);
    // We don't delete files on cancel automatically in new arch?
    // Or we should clean up partials? BackgroundDownloader handles temp files.
    // If we wrote metadata, do we delete it?
    // Maybe not.
  }

  Future<void> delete(String taskId, {String? profileId}) async {
    final task = await _getTaskById(taskId);
    if (task != null) {
      // 1. Cancel the task mechanism (stops download, removes from queue)
      await FileDownloader().cancelTaskWithId(taskId);

      // 2. Delete the directory associated with this task
      // We assume one task = one folder (Movie folder or Episode folder)
      // This removes video, details.json, images, etc.
      final dir = Directory(task.directory);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }

      // 3. Cleanup parents (Season / Show) if empty
      // Only for episodes (check structure)
      // Structure: Show/Season/Episode
      // Parent of Episode is Season. Parent of Season is Show.
      // Parent of Movie is .rivulet_data. We don't delete that.

      final parent = dir.parent; // Season or .rivulet_data (for movies)
      // We can check if parent name starts with 'S' to guess if it's a season?
      // Or just try deleteIfEmpty.

      // Safest way:
      // check if parent is inside .rivulet_data (to avoid deleting root)
      // but simple check:
      if (p.basename(parent.path).startsWith('S')) {
        // It's likely a season folder
        await _fs.deleteIfEmpty(parent);

        // If season deleted, check Show folder
        // Show folder contains details.json and images, so it won't be empty
        // unless we explicitely check for "only metadata left".
        // For now, leaving Show folder is safer/acceptable.
        // User can delete from library if they want to remove the show shell.
      }
    }
  }

  // Helper for Library delete
  Future<void> deleteMedia(String folderId, {String? profileId}) async {
    // 1. Delete from Filesystem
    await _fs.deleteMedia(folderId, profileId: profileId);

    // 2. We can't easily delete records from DB as method is missing.
    // We rely on file existence check in UI to ignore ghost records.
    // Trigger refresh so providers re-check file existence.
    _ref.read(downloadRefreshTriggerProvider.notifier).trigger();
  }

  Future<DownloadTask?> _getTaskById(String taskId) async {
    final task = await FileDownloader().taskForId(taskId);
    return task as DownloadTask?;
  }

  Future<void> openDownloadsFolder({String? profileId}) async {
    await _fs.openDownloadsFolder(profileId: profileId);
  }
}

@riverpod
class DownloadRefreshTrigger extends _$DownloadRefreshTrigger {
  @override
  int build() => 0;

  void trigger() => state++;
}
