import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_downloader/background_downloader.dart';

import '../../../downloads/providers/downloads_provider.dart';

class DownloadButton extends ConsumerWidget {
  final String mediaId; // UUID
  final String? imdbId;
  final int? season;
  final int? episode;
  final VoidCallback onDownload;
  final String? tooltip;
  final bool compact; // For smaller cards if needed

  const DownloadButton({
    super.key,
    required this.mediaId,
    this.imdbId,
    this.season,
    this.episode,
    required this.onDownload,
    this.tooltip,
    this.compact = false,
  });

  // Helper to safely parse metadata
  Map<String, dynamic> _getTaskMetadata(TaskRecord record) {
    try {
      return jsonDecode(record.task.metaData);
    } catch (_) {
      return {};
    }
  }

  Widget _buildIconButton(BuildContext context, List<TaskRecord> tasks) {
    if (tasks.isEmpty) {
      // Idle State
      return IconButton(
        icon: const Icon(Icons.download_rounded),
        tooltip: tooltip ?? 'Download',
        onPressed: onDownload,
      );
    }

    // Sort by priority: Active > Paused > Complete > Error
    // 1. Active: running, enqueued, waitingToRetry
    // 2. Paused: paused
    // 3. Complete: complete
    // 4. Error: failed, canceled, notFound
    tasks.sort((a, b) {
      int getPriority(TaskStatus status) {
        switch (status) {
          case TaskStatus.running:
          case TaskStatus.enqueued:
          case TaskStatus.waitingToRetry:
            return 0; // Highest
          case TaskStatus.paused:
            return 1;
          case TaskStatus.complete:
            return 2;
          case TaskStatus.failed:
          case TaskStatus.canceled:
          case TaskStatus.notFound:
            return 3; // Lowest
        }
      }

      return getPriority(a.status).compareTo(getPriority(b.status));
    });

    final task = tasks.first;

    switch (task.status) {
      case TaskStatus.complete:
        return IconButton(
          icon: const Icon(Icons.check_circle, color: Colors.green),
          tooltip: 'Downloaded',
          onPressed: null, // Disabled
        );
      case TaskStatus.running:
      case TaskStatus.enqueued:
      case TaskStatus.waitingToRetry:
        return Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(8),
          child: CircularProgressIndicator(
            value: task.progress > 0 && task.progress < 1
                ? task.progress
                : null,
            strokeWidth: 3,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          ),
        );
      case TaskStatus.paused:
        return IconButton(
          icon: const Icon(Icons.pause_circle_filled),
          tooltip: 'Paused',
          onPressed: () {
            // Could verify pause/resume implementation
            // For now just show state
          },
        );
      case TaskStatus.failed:
      case TaskStatus.canceled:
      case TaskStatus.notFound:
        // Retryable
        return IconButton(
          icon: const Icon(Icons.download_rounded, color: Colors.red),
          tooltip: 'Retry Download',
          onPressed: onDownload,
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch all downloads
    final downloadsAsync = ref.watch(allDownloadsProvider);

    return downloadsAsync.when(
      data: (downloads) {
        // Find all matching tasks
        final matchingTasks = downloads.where((record) {
          final meta = _getTaskMetadata(record);
          final idMatch =
              (meta['mediaId'] == mediaId || meta['mediaId'] == imdbId);

          if (!idMatch) return false;

          // Check Season/Episode
          if (season != null && episode != null) {
            return meta['season'] == season && meta['episode'] == episode;
          } else {
            // Movie check (ensure no season/ep in meta)
            return meta['season'] == null && meta['episode'] == null;
          }
        }).toList();

        return Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _buildIconButton(context, matchingTasks),
        );
      },
      loading: () => const SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => IconButton(
        icon: const Icon(Icons.error_outline),
        tooltip: 'Error loading status',
        onPressed: null,
      ),
    );
  }
}
