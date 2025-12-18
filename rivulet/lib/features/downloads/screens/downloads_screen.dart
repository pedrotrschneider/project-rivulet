import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rivulet/features/auth/auth_provider.dart';
import 'package:rivulet/features/discovery/domain/discovery_models.dart';
import 'package:rivulet/features/discovery/screens/media_detail_screen.dart';
import 'package:rivulet/features/downloads/providers/downloads_provider.dart';
import 'package:rivulet/features/downloads/providers/offline_providers.dart';
import 'package:rivulet/features/downloads/services/download_service.dart';
import 'package:rivulet/features/downloads/services/offline_history_service.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Active Downloads from FileDownloader
    final allDownloadsAsync = ref.watch(allDownloadsProvider);
    // 2. Library Content from Filesystem
    final libraryContentAsync = ref.watch(downloadedContentProvider);
    final serverUrl = ref.watch(serverUrlProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Offline History',
            onPressed: () async {
              final scaffold = ScaffoldMessenger.of(context);
              scaffold.showSnackBar(
                const SnackBar(
                  content: Text('Syncing history...'),
                  duration: Duration(seconds: 1),
                ),
              );
              try {
                final count = await ref
                    .read(offlineHistoryServiceProvider)
                    .syncOfflineHistory();
                scaffold.hideCurrentSnackBar();
                scaffold.showSnackBar(
                  SnackBar(content: Text('Synced $count items')),
                );
              } catch (e) {
                scaffold.hideCurrentSnackBar();
                scaffold.showSnackBar(
                  SnackBar(content: Text('Sync failed: $e')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open Downloads Folder',
            onPressed: () {
              ref.read(downloadServiceProvider).openDownloadsFolder();
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Active Downloads Section
          allDownloadsAsync.when(
            data: (records) {
              // Filter tasks that are NOT finished?
              // FileDownloader().allTasks() returns tasks in DB.
              // Depending on config, completed tasks might stay.
              // User said: "when the download ends it shoudl be removed from that list".
              // StartDownload sets updates to StatusAndProgress.
              // We should filter active.
              final active = records
                  .where(
                    (r) =>
                        r.status == TaskStatus.running ||
                        r.status == TaskStatus.enqueued ||
                        r.status == TaskStatus.paused ||
                        r.status == TaskStatus.failed,
                  )
                  .toList();

              if (active.isEmpty)
                return const SliverToBoxAdapter(child: SizedBox.shrink());

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index == 0) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Active Downloads',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return _DownloadTaskTile(record: active[index - 1]);
                }, childCount: active.length + 1),
              );
            },
            error: (_, __) =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
            loading: () =>
                const SliverToBoxAdapter(child: LinearProgressIndicator()),
          ),

          // 2. Library Section header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Library',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // 3. Library Grid
          libraryContentAsync.when(
            data: (content) {
              if (content.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No downloaded content'),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    childAspectRatio: 2 / 3, // Matches LibraryScreen
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = content[index];
                    return _LibraryItemCard(item: item, serverUrl: serverUrl);
                  }, childCount: content.length),
                ),
              );
            },
            error: (err, _) =>
                SliverToBoxAdapter(child: Center(child: Text('Error: $err'))),
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadTaskTile extends ConsumerWidget {
  final TaskRecord record;

  const _DownloadTaskTile({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Parse metadata
    Map<String, dynamic> meta = {};
    try {
      meta = jsonDecode(record.task.metaData);
    } catch (_) {}

    final title = meta['title'] as String? ?? 'Unknown';
    final posterPath = meta['posterPath'] as String?;
    final showTitle = meta['showTitle'] as String?;
    final seasonNum = meta['season'] as int?;
    final episodeNum = meta['episode'] as int?;

    return ListTile(
      leading: posterPath != null
          ? AspectRatio(
              aspectRatio: 2 / 3,
              child: Image.network(
                posterPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.movie),
              ),
            )
          : const Icon(Icons.movie),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle != null)
            Text(
              '$showTitle - S${seasonNum}E$episodeNum',
              style: const TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: record.progress),
          const SizedBox(height: 4),
          Text(
            '${record.status.name} • ${(record.progress * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (record.status == TaskStatus.running ||
              record.status == TaskStatus.enqueued)
            IconButton(
              icon: const Icon(Icons.pause),
              onPressed: () {
                ref.read(downloadServiceProvider).pause(record.taskId);
              },
            ),
          if (record.status == TaskStatus.paused ||
              record.status == TaskStatus.failed)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () {
                ref.read(downloadServiceProvider).resume(record.taskId);
              },
            ),
          IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: () {
              ref.read(downloadServiceProvider).cancel(record.taskId);
            },
          ),
        ],
      ),
    );
  }
}

class _LibraryItemCard extends ConsumerWidget {
  final MediaDetail item;
  final String? serverUrl;

  const _LibraryItemCard({required this.item, this.serverUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl =
        item.posterUrl; // Should be local path from provider or URL

    // Check if imageUrl is a local file path
    final isLocal = imageUrl != null && !imageUrl.startsWith('http');

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MediaDetailScreen(
              itemId: item.id,
              type: item.type,
              offlineMode: true,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? (isLocal
                        ? Image.file(
                            File(imageUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          ))
                  : _placeholder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Row(
            children: [
              Icon(
                item.type == 'movie' ? Icons.movie : Icons.tv,
                size: 14,
                color: Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                item.type == 'movie' ? 'Movie' : 'Series',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              // Delete button for Library Item
              IconButton(
                icon: const Icon(Icons.delete, size: 16),
                onPressed: () {
                  // Delete generic media
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete'),
                      content: Text('Delete ${item.title}?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(downloadServiceProvider)
                                .deleteMedia(item.imdbId ?? item.id);
                            // Refresh provider
                            ref.invalidate(downloadedContentProvider);
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(Icons.movie, size: 48),
    );
  }
}
