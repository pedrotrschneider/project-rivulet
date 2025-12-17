import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../services/download_service.dart';

final allDownloadsProvider = StreamProvider<List<TaskRecord>>((ref) async* {
  // Ensure DownloadService is initialized (and tracks tasks)
  ref.watch(downloadServiceProvider);
  // Re-run when trigger changes
  ref.watch(downloadRefreshTriggerProvider);

  // Helper to filter valid records
  Future<List<TaskRecord>> getValidRecords() async {
    final all = await FileDownloader().database.allRecords();
    final valid = <TaskRecord>[];

    for (final r in all) {
      if (r.status == TaskStatus.complete) {
        final task = r.task as DownloadTask;
        String fullPath;
        // Match user's fix: assume directory is absolute-ish but might need leading slash anchor
        // or just rely on it being the full path.
        fullPath = p.join('/', task.directory, task.filename);

        if (File(fullPath).existsSync()) {
          valid.add(r);
        }
      } else {
        // Keeps non-completed tasks (running, failed, paused etc)
        valid.add(r);
      }
    }
    return valid;
  }

  // Yield initial state
  yield await getValidRecords();

  // Listen to updates and refresh list
  await for (final _ in FileDownloader().updates) {
    yield await getValidRecords();
  }
});

// Helper to check if a specific media (Movie or Episode) is currently downloading
// mediaId is strictly the ID (e.g. uuid).
// But for Episodes, we might want to check specific Ep.
// For now, this mimics old behavior: returns a task if ANY task matches mediaId?
// Old behavior: `where((tbl) => tbl.mediaUuid.equals(mediaUuid))`.
// If multiple episodes downloading? It returned SINGLEOrNull.
// New behavior: Return list? Or just first matching?
final activeDownloadByMediaIdProvider =
    FutureProvider.family<TaskRecord?, String>((ref, mediaId) async {
      final records = await FileDownloader().database.allRecords();
      try {
        return records
            .where((r) => r.task.metaData.contains('"mediaId":"$mediaId"'))
            .firstOrNull;
      } catch (e) {
        return null;
      }
    });
