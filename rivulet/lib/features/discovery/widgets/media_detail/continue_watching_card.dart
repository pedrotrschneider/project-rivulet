import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rivulet/features/discovery/domain/discovery_models.dart';

class ContinueWatchingCard extends StatelessWidget {
  final MediaDetail detail;
  final AsyncValue<List<HistoryItem>> historyAsync;
  final Future<void> Function(int? startPos, String mediaId, int seasonNumber, int episodeNumber) onResume;

  const ContinueWatchingCard({
    super.key,
    required this.detail,
    required this.historyAsync,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    if (!historyAsync.hasValue || historyAsync.value!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Find latest history item for this show
    final showHistory = historyAsync.value!.where((h) {
      return (h.type == 'show' || h.type == 'tv') &&
          (h.mediaId == detail.id ||
              h.mediaId == detail.imdbId ||
              h.seriesName == detail.title);
    }).toList();

    if (showHistory.isEmpty) return const SizedBox.shrink();

    // Sort by lastPlayedAt descending
    showHistory.sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
    final latest = showHistory.first;

    String episodeTitle = latest.title;
    int seasonNumber = latest.seasonNumber!;
    int episodeNumber = latest.episodeNumber!;
    if (latest.isWatched) {
      episodeTitle = latest.nextEpisodeTitle!;
      seasonNumber = latest.nextSeason!;
      episodeNumber = latest.nextEpisode!;
    }

    return Container(
      width: 340,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // Episode Still
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: latest.backdropPath.isNotEmpty
                ? Image.network(
                    'https://image.tmdb.org/t/p/w300${detail.backdropUrl}',
                    height: 152,
                    width: 268,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 152,
                    width: 268,
                    color: Colors.black,
                    child: const Center(child: Icon(Icons.play_arrow)),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue Watching S${seasonNumber}E$episodeNumber',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      episodeTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (latest.durationTicks > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: LinearProgressIndicator(
                          value: latest.positionTicks / latest.durationTicks,
                          backgroundColor: Colors.white10,
                          borderRadius: BorderRadius.circular(2),
                          minHeight: 4,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              IconButton.filled(
                onPressed: () async => await onResume(latest.positionTicks, detail.id, seasonNumber, episodeNumber),
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
