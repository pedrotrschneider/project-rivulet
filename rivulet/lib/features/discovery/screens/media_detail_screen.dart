import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rivulet/features/discovery/discovery_provider.dart';
import 'dart:convert';
import 'package:background_downloader/background_downloader.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import '../library_status_provider.dart';
import '../widgets/stream_selection_sheet.dart';
import '../domain/discovery_models.dart';
import '../../downloads/services/download_service.dart';
import '../../downloads/providers/downloads_provider.dart';
import '../../downloads/providers/download_status_provider.dart';

import '../../downloads/providers/offline_providers.dart';
import '../../player/player_screen.dart';

class MediaDetailScreen extends ConsumerStatefulWidget {
  final String itemId;
  final String? type; // 'movie' or 'show' (optional if we resolve it later)
  final bool offlineMode;

  const MediaDetailScreen({
    super.key,
    required this.itemId,
    this.type = 'movie', // Default, but API usually resolves it
    this.offlineMode = false,
  });

  @override
  ConsumerState<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends ConsumerState<MediaDetailScreen> {
  int? _selectedSeason;

  String _formatDuration(int ticks) {
    if (ticks <= 0) return '';
    final duration = Duration(microseconds: ticks ~/ 10);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Use IMDB ID for history lookup if available from details, otherwise start with widget ID
    // Verify strict requirements: Frontend must switch to IMDB ID.
    final detailAsync = widget.offlineMode
        ? ref.watch(offlineMediaDetailProvider(id: widget.itemId))
        : ref.watch(
            mediaDetailProvider(
              id: widget.itemId,
              type: widget.type ?? 'movie', // Fix nullability
            ),
          );

    final downloadsAsync = ref.watch(allDownloadsProvider);

    // Use IMDB ID for history lookup if available from details, otherwise start with widget ID
    // Verify strict requirements: Frontend must switch to IMDB ID.
    // Logic: If widget.itemId is IMDB, use it.
    // If widget.itemId is NOT IMDB, wait for detailAsync to provide IMDB ID.
    String? effectiveHistoryId;
    if (widget.itemId.startsWith('tt')) {
      effectiveHistoryId = widget.itemId;
    } else if (detailAsync.asData?.value.imdbId != null) {
      effectiveHistoryId = detailAsync.asData!.value.imdbId;
    }

    final historyAsync = (effectiveHistoryId != null && !widget.offlineMode)
        ? ref.watch(
            mediaHistoryProvider(
              externalId: effectiveHistoryId,
              type: widget.type ?? 'movie',
            ),
          )
        : const AsyncValue<List<HistoryItem>>.data([]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          if (!widget.offlineMode)
            Consumer(
              builder: (context, ref, child) {
                // We use widget.itemId (TMDB ID usually) which works for checking
                // because backend stores both IDs.
                final statusAsync = ref.watch(
                  libraryStatusProvider(widget.itemId),
                );

                return statusAsync.when(
                  data: (inLibrary) {
                    return IconButton(
                      icon: Icon(inLibrary ? Icons.check : Icons.add),
                      tooltip: inLibrary
                          ? 'Remove from Library'
                          : 'Add to Library',
                      onPressed: () async {
                        // Logic to add/remove
                        try {
                          // Resolve type and preferred ID
                          final detail = ref
                              .read(
                                mediaDetailProvider(
                                  id: widget.itemId,
                                  type: widget.type!,
                                ),
                              )
                              .value;

                          final idToAdd =
                              detail?.imdbId ??
                              (detail?.id.isNotEmpty == true
                                  ? detail!.id
                                  : widget.itemId);
                          final typeToAdd = detail?.type ?? widget.type;

                          await ref
                              .read(
                                libraryStatusProvider(widget.itemId).notifier,
                              )
                              .toggle(typeToAdd!, idOverride: idToAdd);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  inLibrary
                                      ? 'Removed from Library'
                                      : 'Added to Library',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Action failed: $e')),
                            );
                          }
                        }
                      },
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (_, __) => const Icon(Icons.error),
                );
              },
            ),
        ],
      ),
      body: detailAsync.when(
        data: (detail) {
          String? backdropUrl = detail.backdropUrl;
          if (!widget.offlineMode &&
              backdropUrl != null &&
              backdropUrl.startsWith('/')) {
            backdropUrl = 'https://image.tmdb.org/t/p/w1280$backdropUrl';
          }

          final isShow = detail.type == 'tv' || detail.type == 'show';

          // If it is a movie, use the new Desktop/TV style layout
          if (!isShow) {
            return _buildMovieLayout(
              context,
              detail,
              downloadsAsync,
              historyAsync,
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (backdropUrl != null)
                  Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      if (widget.offlineMode)
                        Image.file(
                          File(backdropUrl),
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 250,
                                color: Colors.grey[900],
                                child: const Center(
                                  child: Icon(Icons.movie, size: 50),
                                ),
                              ),
                        )
                      else
                        Image.network(
                          backdropUrl,
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      if (detail.logo != null)
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          width: 200,
                          child: widget.offlineMode
                              ? Image.file(
                                  File(detail.logo!),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                )
                              : Image.network(
                                  detail.logo!,
                                  fit: BoxFit.contain,
                                ),
                        ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (detail.releaseDate != null)
                            Chip(
                              label: Text(detail.releaseDate!.split('-').first),
                              visualDensity: VisualDensity.compact,
                            ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(detail.type.toUpperCase()),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (detail.rating != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.star, size: 16, color: Colors.amber),
                            Text(' ${detail.rating!.toStringAsFixed(1)}'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (detail.overview != null)
                        Text(
                          detail.overview!,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),

                      // Seasons Section
                      if (isShow) ...[
                        const SizedBox(height: 24),
                        const SizedBox(height: 24),
                        // Continue Watching Section (Series)
                        if (historyAsync.hasValue &&
                            historyAsync.value!.isNotEmpty) ...[
                          Consumer(
                            builder: (context, ref, child) {
                              final seasonsAsync = ref.watch(
                                showSeasonsProvider(widget.itemId),
                              );
                              final history = historyAsync.value!;
                              final latest = history.first;

                              return seasonsAsync.when(
                                data: (seasons) {
                                  int targetS = latest.seasonNumber ?? 1;
                                  int targetE = latest.episodeNumber ?? 1;
                                  String targetTitle = latest.title;
                                  bool isResuming =
                                      !latest.isWatched &&
                                      latest.positionTicks > 0;
                                  String label = "Continue Watching";
                                  bool shouldShow = true;

                                  if (latest.isWatched) {
                                    // Logic to find Next Up
                                    label = "Next Up";

                                    if (latest.nextSeason != null &&
                                        latest.nextEpisode != null) {
                                      targetS = latest.nextSeason!;
                                      targetE = latest.nextEpisode!;
                                      targetTitle =
                                          latest.nextEpisodeTitle ?? '';
                                    } else {
                                      // If no stored next episode, hide the card.
                                      // This avoids "S2 E null" or incorrect guesses.
                                      shouldShow = false;
                                    }
                                  }

                                  if (!shouldShow)
                                    return const SizedBox.shrink();

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 8),
                                      Card(
                                        clipBehavior: Clip.antiAlias,
                                        child: ListTile(
                                          leading: const Icon(
                                            Icons.play_circle_outline,
                                            size: 40,
                                          ),
                                          title: Text(
                                            'S$targetS E$targetE${targetTitle.isNotEmpty ? ' - $targetTitle' : ''}',
                                          ),
                                          subtitle: isResuming
                                              ? LinearProgressIndicator(
                                                  value:
                                                      latest.durationTicks > 0
                                                      ? latest.positionTicks /
                                                            latest.durationTicks
                                                      : 0,
                                                  backgroundColor:
                                                      Colors.grey[800],
                                                )
                                              : const Text("Tap to play"),
                                          onTap: () async {
                                            final downloadedPath =
                                                await _resolveDownloadPath(
                                                  ref,
                                                  downloadsAsync
                                                          .asData
                                                          ?.value ??
                                                      [],
                                                  detail.imdbId ?? detail.id,
                                                  season: targetS,
                                                  episode: targetE,
                                                );

                                            if (!context.mounted) return;

                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              builder: (context) =>
                                                  StreamSelectionSheet(
                                                    externalId: detail.imdbId!,
                                                    title:
                                                        'S${targetS}E$targetE - ${detail.title}',
                                                    type: 'show',
                                                    season: targetS,
                                                    episode: targetE,
                                                    imdbId: detail.imdbId,
                                                    // Only pass resume params if resuming EXACT episode
                                                    startPosition: isResuming
                                                        ? latest.positionTicks
                                                        : null,
                                                    downloadedPath:
                                                        downloadedPath,
                                                  ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  );
                                },
                                error: (_, __) => const SizedBox.shrink(),
                                loading: () =>
                                    const SizedBox.shrink(), // Don't show card while loading seasons info
                              );
                            },
                          ),
                        ],
                        Text(
                          'Seasons',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 180,
                          child: Consumer(
                            builder: (context, ref, child) {
                              final seasonsAsync = widget.offlineMode
                                  ? ref.watch(
                                      offlineAvailableSeasonsProvider(
                                        id: widget.itemId,
                                      ),
                                    )
                                  : ref.watch(
                                      showSeasonsProvider(widget.itemId),
                                    );
                              return seasonsAsync.when(
                                data: (seasons) {
                                  return ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: seasons.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final season = seasons[index];
                                      final isSelected =
                                          _selectedSeason ==
                                          season.seasonNumber;

                                      String? posterUrl = season.posterPath;
                                      final isLocal =
                                          widget.offlineMode &&
                                          posterUrl != null &&
                                          !posterUrl.startsWith('http');

                                      if (!widget.offlineMode &&
                                          posterUrl != null &&
                                          posterUrl.startsWith('/')) {
                                        posterUrl =
                                            'https://image.tmdb.org/t/p/w500$posterUrl';
                                      }

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedSeason =
                                                season.seasonNumber;
                                          });
                                        },
                                        child: Container(
                                          width: 120,
                                          decoration: BoxDecoration(
                                            border: isSelected
                                                ? Border.all(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                    width: 2,
                                                  )
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  child: posterUrl != null
                                                      ? (isLocal
                                                            ? Image.file(
                                                                File(posterUrl),
                                                                fit: BoxFit
                                                                    .cover,
                                                                width: double
                                                                    .infinity,
                                                                errorBuilder:
                                                                    (
                                                                      _,
                                                                      __,
                                                                      ___,
                                                                    ) => Container(
                                                                      color: Colors
                                                                          .grey[800],
                                                                      child: const Center(
                                                                        child: Icon(
                                                                          Icons
                                                                              .tv,
                                                                        ),
                                                                      ),
                                                                    ),
                                                              )
                                                            : Image.network(
                                                                posterUrl,
                                                                fit: BoxFit
                                                                    .cover,
                                                                width: double
                                                                    .infinity,
                                                              ))
                                                      : Container(
                                                          color:
                                                              Colors.grey[800],
                                                          child: const Center(
                                                            child: Icon(
                                                              Icons.tv,
                                                            ),
                                                          ),
                                                        ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                season.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      fontWeight: isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: isSelected
                                                          ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                          : null,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                error: (err, stack) => Center(
                                  child: Text('Error loading seasons'),
                                ),
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Episodes Section (Visible only when a season is selected)
                      if (_selectedSeason != null) ...[
                        const SizedBox(height: 24),
                        // Title moved inside builder
                        // const SizedBox(height: 16),
                        Consumer(
                          builder: (context, ref, child) {
                            final episodesAsync = widget.offlineMode
                                ? ref.watch(
                                    offlineSeasonEpisodesProvider(
                                      id: widget.itemId,
                                      seasonNum: _selectedSeason!,
                                    ),
                                  )
                                : ref.watch(
                                    seasonEpisodesProvider(
                                      id: widget.itemId,
                                      seasonNum: _selectedSeason!,
                                    ),
                                  );

                            return episodesAsync.when(
                              data: (seasonDetail) {
                                final episodes = seasonDetail.episodes;
                                return Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Episodes - Season $_selectedSeason',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                        if (!widget.offlineMode)
                                          TextButton.icon(
                                            icon: const Icon(
                                              Icons.download_rounded,
                                            ),
                                            label: const Text(
                                              'Download Season',
                                            ),
                                            onPressed: () {
                                              if (detailAsync.hasValue) {
                                                final downloads =
                                                    downloadsAsync
                                                        .asData
                                                        ?.value ??
                                                    [];
                                                _startBulkDownload(
                                                  episodes,
                                                  detailAsync.value!,
                                                  _selectedSeason!,
                                                  downloads,
                                                );
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: episodes.length,
                                      separatorBuilder: (context, index) =>
                                          const Divider(),
                                      itemBuilder: (context, index) {
                                        final episode = episodes[index];
                                        String? stillUrl = episode.stillPath;
                                        final isLocal =
                                            widget.offlineMode &&
                                            stillUrl != null &&
                                            !stillUrl.startsWith('http');

                                        if (!widget.offlineMode &&
                                            stillUrl != null &&
                                            stillUrl.startsWith('/')) {
                                          stillUrl =
                                              'https://image.tmdb.org/t/p/w500$stillUrl';
                                        }
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: Container(
                                                  width: 100,
                                                  height: 56,
                                                  color: Colors.grey[800],
                                                  child: stillUrl != null
                                                      ? (isLocal
                                                            ? Image.file(
                                                                File(stillUrl),
                                                                fit: BoxFit
                                                                    .cover,
                                                                errorBuilder:
                                                                    (
                                                                      _,
                                                                      __,
                                                                      ___,
                                                                    ) => const Icon(
                                                                      Icons
                                                                          .image,
                                                                    ),
                                                              )
                                                            : Image.network(
                                                                stillUrl,
                                                                fit: BoxFit
                                                                    .cover,
                                                              ))
                                                      : const Icon(Icons.image),
                                                ),
                                              ),
                                              // Checkmark overlay
                                              if (historyAsync.hasValue) ...[
                                                Builder(
                                                  builder: (context) {
                                                    final h = historyAsync
                                                        .value!
                                                        .firstWhere(
                                                          (h) =>
                                                              h.seasonNumber ==
                                                                  _selectedSeason &&
                                                              h.episodeNumber ==
                                                                  episode
                                                                      .episodeNumber,
                                                          orElse: () =>
                                                              HistoryItem.empty(),
                                                        );
                                                    if (h.mediaId.isNotEmpty &&
                                                        h.isWatched) {
                                                      return Positioned.fill(
                                                        child: Container(
                                                          color: Colors.black54,
                                                          child: const Center(
                                                            child: Icon(
                                                              Icons.check,
                                                              color:
                                                                  Colors.green,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                    return const SizedBox.shrink();
                                                  },
                                                ),
                                              ],
                                            ],
                                          ),
                                          title: Text(
                                            '${episode.episodeNumber}. ${episode.name}',
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                episode.overview ?? '',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              // Linear progress bar if applicable
                                              if (historyAsync.hasValue)
                                                Builder(
                                                  builder: (context) {
                                                    final h = historyAsync
                                                        .value!
                                                        .firstWhere(
                                                          (h) =>
                                                              h.seasonNumber ==
                                                                  _selectedSeason &&
                                                              h.episodeNumber ==
                                                                  episode
                                                                      .episodeNumber,
                                                          orElse: () =>
                                                              HistoryItem.empty(),
                                                        );
                                                    if (h.mediaId.isNotEmpty &&
                                                        !h.isWatched &&
                                                        h.positionTicks > 0) {
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 4.0,
                                                            ),
                                                        child: LinearProgressIndicator(
                                                          value:
                                                              h.durationTicks >
                                                                  0
                                                              ? h.positionTicks /
                                                                    h.durationTicks
                                                              : 0,
                                                          backgroundColor:
                                                              Colors.grey[800],
                                                          minHeight: 2,
                                                        ),
                                                      );
                                                    }
                                                    return const SizedBox.shrink();
                                                  },
                                                ),
                                            ],
                                          ),
                                          trailing: Consumer(
                                            builder: (context, ref, child) {
                                              final isDownloadedAsync = ref
                                                  .watch(
                                                    isDownloadedProvider(
                                                      mediaId:
                                                          detail.imdbId ??
                                                          detail.id,
                                                      season: _selectedSeason,
                                                      episode:
                                                          episode.episodeNumber,
                                                    ),
                                                  );

                                              return isDownloadedAsync.when(
                                                data: (isDownloaded) {
                                                  if (isDownloaded) {
                                                    return IconButton(
                                                      icon: const Icon(
                                                        Icons.download_done,
                                                        color: Colors.green,
                                                      ),
                                                      onPressed: () {
                                                        // Prompt delete?
                                                      },
                                                    );
                                                  }

                                                  // Not downloaded? Check active tasks
                                                  final activeTaskAsync = ref
                                                      .watch(
                                                        activeDownloadProvider(
                                                          mediaId:
                                                              detail.imdbId ??
                                                              detail.id,
                                                          season:
                                                              _selectedSeason,
                                                          episode: episode
                                                              .episodeNumber,
                                                        ),
                                                      );

                                                  return activeTaskAsync.when(
                                                    data: (task) {
                                                      if (task == null) {
                                                        // Not downloading, not downloaded
                                                        if (widget.offlineMode)
                                                          return const SizedBox.shrink();

                                                        return IconButton(
                                                          icon: const Icon(
                                                            Icons
                                                                .download_outlined,
                                                          ),
                                                          onPressed: () =>
                                                              _showDownloadSheet(
                                                                context,
                                                                ref,
                                                                detailAsync
                                                                    .asData!
                                                                    .value,
                                                                episode,
                                                              ),
                                                        );
                                                      }

                                                      // Active Task Found
                                                      switch (task.status) {
                                                        case TaskStatus.running:
                                                        case TaskStatus
                                                            .enqueued:
                                                          return SizedBox(
                                                            width: 24,
                                                            height: 24,
                                                            child: CircularProgressIndicator(
                                                              value:
                                                                  task.progress >
                                                                      0
                                                                  ? task.progress
                                                                  : null,
                                                              strokeWidth: 2,
                                                            ),
                                                          );
                                                        case TaskStatus.failed:
                                                          return IconButton(
                                                            icon: const Icon(
                                                              Icons
                                                                  .error_outline,
                                                              color: Colors.red,
                                                            ),
                                                            onPressed: () {
                                                              if (!widget
                                                                  .offlineMode) {
                                                                _showDownloadSheet(
                                                                  context,
                                                                  ref,
                                                                  detailAsync
                                                                      .asData!
                                                                      .value,
                                                                  episode,
                                                                );
                                                              }
                                                            },
                                                          );
                                                        default:
                                                          // Not downloading, not downloaded
                                                          if (widget
                                                              .offlineMode)
                                                            return const SizedBox.shrink();

                                                          return IconButton(
                                                            icon: const Icon(
                                                              Icons
                                                                  .download_outlined,
                                                            ),
                                                            onPressed: () =>
                                                                _showDownloadSheet(
                                                                  context,
                                                                  ref,
                                                                  detailAsync
                                                                      .asData!
                                                                      .value,
                                                                  episode,
                                                                ),
                                                          );
                                                      }
                                                    },
                                                    error: (e, s) =>
                                                        const SizedBox.shrink(), // Silent error for active check
                                                    loading: () => const SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    ),
                                                    skipLoadingOnReload: true,
                                                  );
                                                },
                                                error: (e, s) => const Icon(
                                                  Icons.error,
                                                  color: Colors.orange,
                                                ),
                                                loading: () => const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                                skipLoadingOnReload: true,
                                              );
                                            },
                                          ),
                                          onTap: () async {
                                            // Calculate start position from history
                                            int startPos = 0;
                                            if (historyAsync.hasValue) {
                                              final h = historyAsync.value!
                                                  .firstWhere(
                                                    (h) =>
                                                        h.seasonNumber ==
                                                            _selectedSeason &&
                                                        h.episodeNumber ==
                                                            episode
                                                                .episodeNumber,
                                                    orElse: () =>
                                                        HistoryItem.empty(),
                                                  );
                                              startPos = h.positionTicks;
                                            }

                                            final downloadedPath =
                                                await _resolveDownloadPath(
                                                  ref,
                                                  downloadsAsync
                                                          .asData
                                                          ?.value ??
                                                      [],
                                                  detail.imdbId ?? detail.id,
                                                  season: _selectedSeason,
                                                  episode:
                                                      episode.episodeNumber,
                                                );

                                            if (!context.mounted) return;

                                            if (widget.offlineMode &&
                                                downloadedPath != null) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => PlayerScreen(
                                                    url:
                                                        'file://$downloadedPath',
                                                    externalId:
                                                        detailAsync
                                                            .value!
                                                            .imdbId ??
                                                        widget.itemId,
                                                    title:
                                                        'S${_selectedSeason}E${episode.episodeNumber} - ${episode.name}',
                                                    type: 'show',
                                                    season: _selectedSeason,
                                                    episode:
                                                        episode.episodeNumber,
                                                    startPosition: startPos,
                                                    imdbId: detailAsync
                                                        .value!
                                                        .imdbId,
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              builder: (context) =>
                                                  StreamSelectionSheet(
                                                    externalId:
                                                        detailAsync
                                                            .value!
                                                            .imdbId ??
                                                        widget.itemId,
                                                    title:
                                                        'S${_selectedSeason}E${episode.episodeNumber} - ${episode.name}',
                                                    type: 'show',
                                                    season: _selectedSeason,
                                                    episode:
                                                        episode.episodeNumber,
                                                    startPosition: startPos,
                                                    imdbId: detailAsync
                                                        .value!
                                                        .imdbId,
                                                    downloadedPath:
                                                        downloadedPath,
                                                  ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                              error: (err, stack) =>
                                  Text('Error loading episodes: $err'),
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        error: (err, stack) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: null,
    );
  }

  // Helper to safely parse metadata
  Map<String, dynamic> _getTaskMetadata(TaskRecord record) {
    try {
      return jsonDecode(record.task.metaData);
    } catch (_) {
      return {};
    }
  }

  Future<void> _startBulkDownload(
    List<DiscoveryEpisode> episodes,
    MediaDetail detail,
    int seasonNum,
    List<TaskRecord> existingDownloads,
  ) async {
    bool cancelRemaining = false;

    for (int i = 0; i < episodes.length; i++) {
      if (cancelRemaining) break;

      final episode = episodes[i];

      // Check if already downloaded
      final isDownloaded = existingDownloads.any((record) {
        final meta = _getTaskMetadata(record);
        final targetId = detail.imdbId ?? detail.id;

        return (meta['mediaId'] == targetId || meta['mediaId'] == detail.id) &&
            meta['season'] == seasonNum &&
            meta['episode'] == episode.episodeNumber &&
            (record.status == TaskStatus.complete ||
                record.status == TaskStatus.running ||
                record.status == TaskStatus.enqueued);
      });

      if (isDownloaded) continue;

      // Wait for user interaction
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => StreamSelectionSheet(
          externalId: detail.imdbId ?? detail.id,
          title: 'Downloading S${seasonNum}E${episode.episodeNumber}',
          type: 'show',
          season: seasonNum,
          episode: episode.episodeNumber,
          imdbId: detail.imdbId,
          onStreamSelected: (url, filename, quality) {
            ref
                .read(downloadServiceProvider)
                .startDownload(
                  mediaUuid: detail.id,
                  url: url,
                  title:
                      'S${seasonNum}E${episode.episodeNumber} - ${episode.name}',
                  type: 'episode',
                  posterPath: detail.posterUrl,
                  backdropPath: detail.backdropUrl,
                  logoPath: detail.logo,
                  overview: detail.overview,
                  imdbId: detail.imdbId,
                  voteAverage: detail.rating,
                  showTitle: detail.title,
                  seasonNumber: seasonNum,
                  episodeNumber: episode.episodeNumber,
                  episodeOverview: episode.overview,
                  episodeStillPath: episode.stillPath,
                  episodeTitle: episode.name, // Pass name as title
                  seasonPosterPath: _getSeasonPosterPath(seasonNum),
                  seasons: ref
                      .read(showSeasonsProvider(widget.itemId))
                      .value
                      ?.map((s) => s.toJson())
                      .toList(),
                );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Queued S${seasonNum}E${episode.episodeNumber}'),
              ),
            );
          },
          onSkip: () {
            // Just close, loop continues
          },
          onSkipRemaining: () {
            cancelRemaining = true;
          },
        ),
      );
    }
  }

  void _showDownloadSheet(
    BuildContext context,
    WidgetRef ref,
    MediaDetail detail,
    DiscoveryEpisode episode,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StreamSelectionSheet(
        externalId: detail.imdbId ?? widget.itemId,
        title: 'S${_selectedSeason}E${episode.episodeNumber} - ${episode.name}',
        type: 'show',
        season: _selectedSeason,
        episode: episode.episodeNumber,
        imdbId: detail.imdbId,
        onStreamSelected: (url, _, __) {
          ref
              .read(downloadServiceProvider)
              .startDownload(
                mediaUuid: detail.id,
                url: url,
                title:
                    '${detail.title} - S${_selectedSeason}E${episode.episodeNumber}',
                type: 'episode',
                posterPath: detail.posterUrl,
                backdropPath: detail.backdropUrl,
                logoPath: detail.logo,
                overview: detail.overview,
                imdbId: detail.imdbId,
                voteAverage: detail.rating,
                showTitle: detail.title,
                seasonNumber: _selectedSeason,
                episodeNumber: episode.episodeNumber,
                episodeOverview: episode.overview,
                episodeStillPath: episode.stillPath,
                episodeTitle: episode.name, // Pass name as title
                seasonPosterPath: _getSeasonPosterPath(_selectedSeason!),
                seasons: ref
                    .read(showSeasonsProvider(widget.itemId))
                    .value
                    ?.map((s) => s.toJson())
                    .toList(),
              );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloading ${episode.name}')),
          );
        },
      ),
    );
  }

  Future<String?> _resolveDownloadPath(
    WidgetRef ref,
    List<TaskRecord> downloads,
    String mediaId, {
    int? season,
    int? episode,
  }) async {
    for (final record in downloads) {
      if (record.status == TaskStatus.complete) {
        final meta = _getTaskMetadata(record);
        // Check both ID types (UUID or IMDB)
        if (meta['mediaId'] == mediaId ||
            meta['imdbId'] == mediaId ||
            mediaId == record.task.group) {
          // Basic ID match, now check Episode/Season
          bool match = false;
          if (season != null && episode != null) {
            // Episode match
            if (meta['season'] == season && meta['episode'] == episode) {
              match = true;
            }
          } else {
            // Movie match (no season/episode in meta)
            if (meta['season'] == null && meta['episode'] == null) {
              match = true;
            }
          }

          if (match) {
            final task = record.task as DownloadTask;
            // Resolve absolute path
            String fullPath = p.join("/", task.directory, task.filename);

            if (File(fullPath).existsSync()) {
              return fullPath;
            }
          }
        }
      }
    }
    return null;
  }

  String? _getSeasonPosterPath(int seasonNumber) {
    if (widget.offlineMode) {
      final seasonsAsync = ref.read(
        offlineAvailableSeasonsProvider(id: widget.itemId),
      );
      return seasonsAsync.value
          ?.where((s) => s.seasonNumber == seasonNumber)
          .firstOrNull
          ?.posterPath;
    } else {
      final seasonsAsync = ref.read(showSeasonsProvider(widget.itemId));
      return seasonsAsync.value
          ?.where((s) => s.seasonNumber == seasonNumber)
          .firstOrNull
          ?.posterPath;
    }
  }

  Widget _buildMovieLayout(
    BuildContext context,
    MediaDetail detail,
    AsyncValue<List<TaskRecord>> downloadsAsync,
    AsyncValue<List<HistoryItem>> historyAsync,
  ) {
    String? backdropUrl = detail.backdropUrl;
    if (!widget.offlineMode &&
        backdropUrl != null &&
        backdropUrl.startsWith('/')) {
      backdropUrl = 'https://image.tmdb.org/t/p/original$backdropUrl';
    }

    String? posterUrl = detail.posterUrl;
    if (!widget.offlineMode && posterUrl != null && posterUrl.startsWith('/')) {
      posterUrl = 'https://image.tmdb.org/t/p/w780$posterUrl';
    }

    final logoUrl = detail
        .logo; // Assuming fully qualified or handled by Image widget if typical

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Backdrop Image with Shader Mask
        if (backdropUrl != null)
          Positioned.fill(
            child: widget.offlineMode
                ? Image.file(
                    File(backdropUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  )
                : Image.network(
                    backdropUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  ),
          ),

        // 2. Gradient Overlay (Fade to background at bottom)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(0.1),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
        ),

        // 3. Content Columns
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48.0, 32.0, 48.0, 64.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Column 1: Poster (25%)
                Expanded(
                  flex: 3, // ~25% of 12
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: posterUrl != null
                            ? (widget.offlineMode
                                  ? Image.file(
                                      File(posterUrl),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey[900],
                                        child: const Icon(
                                          Icons.movie,
                                          size: 50,
                                        ),
                                      ),
                                    )
                                  : Image.network(posterUrl, fit: BoxFit.cover))
                            : Container(
                                color: Colors.grey[900],
                                child: const Icon(Icons.movie, size: 50),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 32),

                // Column 2: Logo + Buttons (33%)
                Expanded(
                  flex: 4, // ~33.3% of 12
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (logoUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 120),
                            child: widget.offlineMode
                                ? Image.file(File(logoUrl), fit: BoxFit.contain)
                                : Image.network(logoUrl, fit: BoxFit.contain),
                          ),
                        ),

                      const SizedBox(height: 16),
                      // Buttons Row
                      Row(
                        children: [
                          // Add to Library Button (Square)
                          if (!widget.offlineMode)
                            Consumer(
                              builder: (context, ref, child) {
                                final statusAsync = ref.watch(
                                  libraryStatusProvider(widget.itemId),
                                );
                                return statusAsync.when(
                                  data: (inLibrary) => Container(
                                    margin: const EdgeInsets.only(right: 16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        inLibrary ? Icons.check : Icons.add,
                                      ),
                                      tooltip: inLibrary
                                          ? 'Remove from Library'
                                          : 'Add to Library',
                                      onPressed: () async {
                                        try {
                                          // Resolve type and preferred ID
                                          final detail = ref
                                              .read(
                                                mediaDetailProvider(
                                                  id: widget.itemId,
                                                  type: widget.type!,
                                                ),
                                              )
                                              .value;

                                          final idToAdd =
                                              detail?.imdbId ??
                                              (detail?.id.isNotEmpty == true
                                                  ? detail!.id
                                                  : widget.itemId);
                                          final typeToAdd =
                                              detail?.type ?? widget.type;

                                          await ref
                                              .read(
                                                libraryStatusProvider(
                                                  widget.itemId,
                                                ).notifier,
                                              )
                                              .toggle(
                                                typeToAdd!,
                                                idOverride: idToAdd,
                                              );

                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  inLibrary
                                                      ? 'Removed from Library'
                                                      : 'Added to Library',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Action failed: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                  loading: () => Container(
                                    width: 48,
                                    height: 48,
                                    margin: const EdgeInsets.only(right: 16),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  error: (_, __) => const SizedBox.shrink(),
                                );
                              },
                            ),

                          // Download Button (Square)
                          if (!widget.offlineMode)
                            Container(
                              margin: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.download_rounded),
                                tooltip: 'Download Movie',
                                onPressed: () {
                                  // Trigger logic
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (context) => StreamSelectionSheet(
                                      externalId: detail.imdbId ?? detail.id,
                                      title: detail.title,
                                      type: 'movie',
                                      imdbId: detail.imdbId,
                                      onStreamSelected:
                                          (url, filename, quality) {
                                            ref
                                                .read(downloadServiceProvider)
                                                .startDownload(
                                                  mediaUuid: detail.id,
                                                  url: url,
                                                  title: detail.title,
                                                  type: 'movie',
                                                  posterPath: detail.posterUrl,
                                                  backdropPath:
                                                      detail.backdropUrl,
                                                  logoPath: detail.logo,
                                                  overview: detail.overview,
                                                  imdbId: detail.imdbId,
                                                  voteAverage: detail.rating,
                                                );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Download started',
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                                  );
                                },
                              ),
                            ),

                          // Play Button (Wide)
                          Expanded(
                            child: SizedBox(
                              height: 52, // Wide and tall
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 28,
                                ),
                                label: Consumer(
                                  builder: (context, ref, _) {
                                    // Resume logic
                                    String label = 'Play';
                                    if (historyAsync.hasValue &&
                                        historyAsync.value!.isNotEmpty) {
                                      final h = historyAsync.value!.first;
                                      if (!h.isWatched && h.positionTicks > 0) {
                                        label =
                                            'Resume ${_formatDuration(h.positionTicks)}';
                                      }
                                    }
                                    return Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                                ),
                                onPressed: () async {
                                  int? startPos;
                                  if (historyAsync.hasValue &&
                                      historyAsync.value!.isNotEmpty) {
                                    final h = historyAsync.value!.first;
                                    if (!h.isWatched && h.positionTicks > 0) {
                                      startPos = h.positionTicks;
                                    }
                                  }

                                  final downloadedPath =
                                      await _resolveDownloadPath(
                                        ref,
                                        downloadsAsync.asData?.value ?? [],
                                        detail.imdbId ?? detail.id,
                                      );

                                  if (!context.mounted) return;

                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (context) => StreamSelectionSheet(
                                      externalId: detail.imdbId ?? detail.id,
                                      title: detail.title,
                                      type: 'movie',
                                      startPosition: startPos,
                                      imdbId: detail.imdbId,
                                      downloadedPath: downloadedPath,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),

                // Column 3: Info (42%)
                Expanded(
                  flex: 5, // ~41.6% of 12
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.title,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              shadows: [
                                BoxShadow(
                                  color: Colors.black,
                                  blurRadius: 20,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (detail.rating != null) ...[
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${detail.rating!.toStringAsFixed(1)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (detail.releaseDate != null) ...[
                            Text(
                              detail.releaseDate!.split('-').first,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 16),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white70),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'MOVIE',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        detail.overview ?? '',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.4,
                          fontSize: 16,
                          shadows: [
                            BoxShadow(color: Colors.black, blurRadius: 10),
                          ],
                        ),
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Extra space at bottom
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
