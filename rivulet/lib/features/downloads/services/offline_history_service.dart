import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rivulet/features/auth/profiles_provider.dart';
import 'package:rivulet/features/discovery/repository/discovery_repository.dart';
import 'package:rivulet/features/downloads/services/file_system_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'offline_history_service.g.dart';

@Riverpod(keepAlive: true)
OfflineHistoryService offlineHistoryService(Ref ref) {
  return OfflineHistoryService(ref);
}

class OfflineHistoryService {
  final Ref _ref;

  OfflineHistoryService(this._ref);

  Future<void> saveOfflineProgress(
    String mediaId,
    Map<String, dynamic> progress,
  ) async {
    final fs = _ref.read(fileSystemServiceProvider);
    final profileId = _ref.read(selectedProfileProvider);

    // Get media directory
    final dir = await fs.getMediaDirectory(mediaId, profileId: profileId);

    // Read existing
    List<Map<String, dynamic>> history = [];
    final existing = await fs.readJsonList(dir, 'offline_history.json');
    if (existing != null) {
      history = List<Map<String, dynamic>>.from(existing);
    }

    // Deduplicate: Remove entries for same episode/movie
    // Progress map keys: season, episode, type
    final type = progress['type'];
    final season = progress['season'];
    final episode = progress['episode'];

    history.removeWhere((item) {
      if (item['type'] != type) return false;
      if (type == 'movie') return true; // Only one entry per movie
      return item['season'] == season && item['episode'] == episode;
    });

    // Add new (latest)
    history.add(progress);

    // Write back
    await fs.writeJson(dir, 'offline_history.json', history);
  }

  Future<int> syncOfflineHistory() async {
    final fs = _ref.read(fileSystemServiceProvider);
    final repo = _ref.read(discoveryRepositoryProvider);
    final profileId = _ref.read(selectedProfileProvider);
    int syncedCount = 0;

    final mediaDirs = await fs.listMedia(profileId: profileId);

    for (final dir in mediaDirs) {
      final history = await fs.readJsonList(dir, 'offline_history.json');
      if (history != null && history.isNotEmpty) {
        try {
          // Cast strictly
          final progressList = List<Map<String, dynamic>>.from(history);

          if (progressList.isNotEmpty) {
            await repo.updateProgress(progressList);
            syncedCount += progressList.length;

            // Delete offline file after successful sync
            final file = fs.getFile(dir, 'offline_history.json');
            if (file.existsSync()) {
              await file.delete();
            }

            // Refresh central history cache for this media
            // We need externalId/type. Grab from first item.
            final first = progressList.first;
            final externalId = first['external_id'] as String?;
            final type = first['type'] as String?;

            if (externalId != null && type != null) {
              // Re-fetch history to update 'history.json'
              final results = await repo.getMediaHistory(externalId, type);
              if (results.isNotEmpty) {
                await fs.writeJson(
                  dir,
                  'history.json',
                  results.map((e) => e.toJson()).toList(),
                );
              }
            }
          }
        } catch (e) {
          print('Failed to sync ${dir.path}: $e');
        }
      }
    }
    return syncedCount;
  }
}
