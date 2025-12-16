import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rivulet/features/discovery/discovery_provider.dart';

import '../library_status_provider.dart';
import '../widgets/stream_selection_sheet.dart';
import '../domain/discovery_models.dart';

class MediaDetailScreen extends ConsumerStatefulWidget {
  final String itemId;
  final String type;

  const MediaDetailScreen({
    super.key,
    required this.itemId,
    required this.type,
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
    final detailAsync = ref.watch(
      mediaDetailProvider(id: widget.itemId, type: widget.type),
    );

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

    final historyAsync = effectiveHistoryId != null
        ? ref.watch(
            mediaHistoryProvider(
              externalId: effectiveHistoryId,
              type: widget.type,
            ),
          )
        : const AsyncValue<List<HistoryItem>>.data([]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
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
                                type: widget.type,
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
                            .read(libraryStatusProvider(widget.itemId).notifier)
                            .toggle(typeToAdd, idOverride: idToAdd);

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
          if (backdropUrl != null && backdropUrl.startsWith('/')) {
            backdropUrl = 'https://image.tmdb.org/t/p/w1280$backdropUrl';
          }

          final isShow = detail.type == 'tv' || detail.type == 'show';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (backdropUrl != null)
                  Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
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
                          child: Image.network(
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
                                          onTap: () {
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
                              final seasonsAsync = ref.watch(
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
                                      if (posterUrl != null &&
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
                                                      ? Image.network(
                                                          posterUrl,
                                                          fit: BoxFit.cover,
                                                          width:
                                                              double.infinity,
                                                        )
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
                        Text(
                          'Episodes - Season $_selectedSeason',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Consumer(
                          builder: (context, ref, child) {
                            final episodesAsync = ref.watch(
                              seasonEpisodesProvider(
                                id: widget.itemId,
                                seasonNum: _selectedSeason!,
                              ),
                            );
                            return episodesAsync.when(
                              data: (seasonDetail) {
                                final episodes = seasonDetail.episodes;
                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: episodes.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(),
                                  itemBuilder: (context, index) {
                                    final episode = episodes[index];
                                    String? stillUrl = episode.stillPath;
                                    if (stillUrl != null &&
                                        stillUrl.startsWith('/')) {
                                      stillUrl =
                                          'https://image.tmdb.org/t/p/w500$stillUrl';
                                    }
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: Container(
                                              width: 100,
                                              height: 56,
                                              color: Colors.grey[800],
                                              child: stillUrl != null
                                                  ? Image.network(
                                                      stillUrl,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : const Icon(Icons.image),
                                            ),
                                          ),
                                          // Checkmark overlay
                                          if (historyAsync.hasValue) ...[
                                            Builder(
                                              builder: (context) {
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
                                                if (h.mediaId.isNotEmpty &&
                                                    h.isWatched) {
                                                  return Positioned.fill(
                                                    child: Container(
                                                      color: Colors.black54,
                                                      child: const Center(
                                                        child: Icon(
                                                          Icons.check,
                                                          color: Colors.green,
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
                                          if (historyAsync.hasValue)
                                            Builder(
                                              builder: (context) {
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
                                                if (h.mediaId.isNotEmpty &&
                                                    !h.isWatched &&
                                                    h.positionTicks > 0) {
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4.0,
                                                        ),
                                                    child: LinearProgressIndicator(
                                                      value: h.durationTicks > 0
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
                                      onTap: () {
                                        // Calculate start position from history
                                        int startPos = 0;
                                        if (historyAsync.hasValue) {
                                          final h = historyAsync.value!
                                              .firstWhere(
                                                (h) =>
                                                    h.seasonNumber ==
                                                        _selectedSeason &&
                                                    h.episodeNumber ==
                                                        episode.episodeNumber,
                                                orElse: () =>
                                                    HistoryItem.empty(),
                                              );
                                          startPos = h.positionTicks;
                                        }

                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (context) =>
                                              StreamSelectionSheet(
                                                externalId:
                                                    detail.imdbId ??
                                                    widget.itemId,
                                                title:
                                                    'S${_selectedSeason}E${episode.episodeNumber} - ${episode.name}',
                                                type: 'show',
                                                season: _selectedSeason,
                                                episode: episode.episodeNumber,
                                                startPosition: startPos,
                                                imdbId: detail.imdbId,
                                              ),
                                        );
                                      },
                                    );
                                  },
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
      floatingActionButton: detailAsync.asData?.value.type == 'movie'
          ? FloatingActionButton.extended(
              onPressed: () {
                final detail = detailAsync.asData!.value;

                int? startPos;

                // String? resMagnet;
                // int? resFileIdx;

                if (historyAsync.hasValue && historyAsync.value!.isNotEmpty) {
                  final h = historyAsync.value!.first;
                  if (!h.isWatched && h.positionTicks > 0) {
                    startPos = h.positionTicks;
                    // resMagnet = h.lastMagnet;
                    // resFileIdx = h.lastFileIndex;
                  }
                }

                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => StreamSelectionSheet(
                    externalId:
                        detail.imdbId ??
                        detail.id, // Prefer IMDB ID if available
                    title: detail.title,
                    type: 'movie',
                    startPosition: startPos,
                    imdbId: detail.imdbId,
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(
                (historyAsync.hasValue &&
                        historyAsync.value!.isNotEmpty &&
                        !historyAsync.value!.first.isWatched &&
                        historyAsync.value!.first.positionTicks > 0)
                    ? 'Continue from ${_formatDuration(historyAsync.value!.first.positionTicks)}'
                    : 'Play',
              ),
            )
          : null,
    );
  }
}
