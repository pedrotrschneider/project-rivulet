import 'dart:io';
import 'package:flutter/material.dart';

import 'package:rivulet/features/discovery/domain/discovery_models.dart';
import 'download_button.dart';

class EpisodeCard extends StatefulWidget {
  final DiscoveryEpisode episode;
  final HistoryItem? history;
  final String mediaId;
  final String? imdbId;
  final int season;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final bool offlineMode;

  const EpisodeCard({
    super.key,
    required this.episode,
    this.history,
    required this.mediaId,
    this.imdbId,
    required this.season,
    required this.onTap,
    required this.onDownload,
    this.offlineMode = false,
  });

  @override
  State<EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<EpisodeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final progress = widget.history != null && widget.history!.durationTicks > 0
        ? widget.history!.positionTicks / widget.history!.durationTicks
        : 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isHovered
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Image
              SizedBox(
                width: 220,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      alignment: Alignment.bottomLeft,
                      children: [
                        widget.episode.stillPath != null
                            ? (widget.offlineMode
                                  ? Image.file(
                                      File(widget.episode.stillPath!),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.black,
                                        child: const Center(
                                          child: Icon(Icons.tv),
                                        ),
                                      ),
                                    )
                                  : Image.network(
                                      'https://image.tmdb.org/t/p/w300${widget.episode.stillPath}',
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ))
                            : Container(
                                color: Colors.black,
                                child: const Center(child: Icon(Icons.tv)),
                              ),

                        // Progress Bar
                        if (progress > 0)
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),

                        // Watched Indicator
                        if (widget.history?.isWatched ?? false)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.remove_red_eye_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.episode.episodeNumber}. ${widget.episode.name}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (widget.episode.airDate != null)
                      Text(
                        widget.episode.airDate!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      widget.episode.overview ?? 'No description available.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Actions
              if (!widget.offlineMode)
                DownloadButton(
                  mediaId: widget.mediaId,
                  imdbId: widget.imdbId,
                  season: widget.season,
                  episode: widget.episode.episodeNumber,
                  tooltip: 'Download',
                  onDownload: widget.onDownload,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
