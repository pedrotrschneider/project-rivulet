import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rivulet/features/auth/profiles_provider.dart';
import '../services/download_service.dart';

final allDownloadsProvider = StreamProvider<List<TaskRecord>>((ref) async* {
  // Ensure DownloadService is initialized (and tracks tasks)
  ref.watch(downloadServiceProvider);
  // Re-run when trigger changes
  ref.watch(downloadRefreshTriggerProvider);
  // Re-run when profile changes
  final profileId = ref.watch(selectedProfileProvider);

  // Helper to filter valid records
  Future<List<TaskRecord>> getValidRecords() async {
    final all = await FileDownloader().database.allRecords();
    final valid = <TaskRecord>[];

    for (final r in all) {
      final task = r.task as DownloadTask;

      if (profileId != null && !task.directory.contains('/$profileId/')) {
        continue;
      }

      if (r.status == TaskStatus.complete) {
        // Match user's fix: assume directory is absolute
        // Trust the DB record for UI state.
        // File existence check can be flaky if path normalization differs
        // or during finalization.
        valid.add(r);
      } else {
        // Keeps non-completed tasks (running, failed, paused etc)
        // We should also filter these by profile.
        // For active downloads, we might not have a full path yet?
        // Yes we do, task.directory is set at creation.
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
      final profileId = ref.watch(selectedProfileProvider);
      final records = await FileDownloader().database.allRecords();
      try {
        return records.where((r) {
          final task = r.task as DownloadTask;
          // Filter by profile
          if (profileId != null && !task.directory.contains('/$profileId/')) {
            return false;
          }
          return task.metaData.contains('"mediaId":"$mediaId"');
        }).firstOrNull;
      } catch (e) {
        return null;
      }
    });
