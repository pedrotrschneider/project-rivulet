import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rivulet/features/discovery/domain/discovery_models.dart';
import 'package:rivulet/features/widgets/action_scale.dart';

class ContinueWatchingCard extends StatefulWidget {
  final MediaDetail detail;
  final AsyncValue<List<HistoryItem>> historyAsync;
  final Future<void> Function(
    int? startPos,
    String mediaId,
    int seasonNumber,
    int episodeNumber,
  )
  onResume;

  const ContinueWatchingCard({
    super.key,
    required this.detail,
    required this.historyAsync,
    required this.onResume,
  });

  @override
  State<ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<ContinueWatchingCard> {
  late FocusNode _playButtonNode;

  @override
  void initState() {
    super.initState();
    _playButtonNode = FocusNode();
    _playButtonNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _playButtonNode.removeListener(_onFocusChange);
    // _playButtonNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_playButtonNode.hasFocus && mounted) {
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.historyAsync.hasValue || widget.historyAsync.value!.isEmpty) {
      return const SizedBox.shrink();
    }

    final showHistory = widget.historyAsync.value!.where((h) {
      return (h.type == 'show' || h.type == 'tv') &&
          (h.mediaId == widget.detail.id ||
              h.mediaId == widget.detail.imdbId ||
              h.seriesName == widget.detail.title);
    }).toList();

    if (showHistory.isEmpty) return const SizedBox.shrink();

    showHistory.sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
    final latest = showHistory.first;

    String episodeTitle = latest.title;
    int seasonNumber = latest.seasonNumber!;
    int episodeNumber = latest.episodeNumber!;
    int startTicks = latest.positionTicks;

    if (latest.isWatched) {
      episodeTitle = latest.nextEpisodeTitle ?? 'Next Episode';
      seasonNumber = latest.nextSeason ?? seasonNumber;
      episodeNumber = latest.nextEpisode ?? (episodeNumber + 1);
      startTicks = 0;
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
            borderRadius: BorderRadius.circular(12),
            child: latest.backdropPath.isNotEmpty
                ? Image.network(
                    'https://image.tmdb.org/t/p/w300${latest.backdropPath}', // Fixed to use episode image if avail
                    height: 152,
                    width: 268,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.network(
                      'https://image.tmdb.org/t/p/w300${widget.detail.backdropUrl}',
                      height: 152,
                      width: 268,
                      fit: BoxFit.cover,
                    ),
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
                    if (latest.durationTicks > 0 && !latest.isWatched)
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

              ActionScale(
                focusNode: _playButtonNode,
                scale: 1.1,
                breathingIntensity: 0.2,
                builder: (context, node) => IconButton.filled(
                  focusNode: node,
                  onPressed: () async => await widget.onResume(
                    startTicks, // Corrected variable
                    widget.detail.id,
                    seasonNumber,
                    episodeNumber,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
