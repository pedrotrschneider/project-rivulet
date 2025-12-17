import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rivulet/features/downloads/providers/downloads_provider.dart';
import 'package:rivulet/features/downloads/services/download_service.dart';
import 'package:rivulet/features/downloads/services/file_system_service.dart';

part 'download_status_provider.g.dart';

@riverpod
Future<bool> isDownloaded(
  Ref ref, {
  required String mediaId,
  int? season,
  int? episode,
}) async {
  // Watch trigger for updates on delete
  ref.watch(downloadRefreshTriggerProvider);

  final fs = ref.read(fileSystemServiceProvider);

  Directory dir;
  if (season != null && episode != null) {
    dir = await fs.getEpisodeDirectory(mediaId, season, episode);
  } else {
    dir = await fs.getMediaDirectory(mediaId);
  }

  // Assuming standard filename used in DownloadService
  final videoFile = File(p.join(dir.path, 'video.mp4'));
  return videoFile.exists();
}

@riverpod
Future<TaskRecord?> activeDownload(
  Ref ref, {
  required String mediaId,
  int? season,
  int? episode,
}) async {
  // Stream all downloads
  final allDownloads = await ref.watch(allDownloadsProvider.future);

  // Find matching active task
  try {
    return allDownloads.firstWhere((record) {
      if (record.status == TaskStatus.complete) {
        return false; // Ignore completed
      }

      final metaString = record.task.metaData;
      if (!metaString.contains('"mediaId":"$mediaId"')) return false;

      if (season != null && episode != null) {
        if (!metaString.contains('"season":$season')) return false;
        if (!metaString.contains('"episode":$episode')) return false;
      } else {
        if (metaString.contains('"type":"movie"')) return true;
      }
      return true;
    });
  } catch (e) {
    return null;
  }
}
