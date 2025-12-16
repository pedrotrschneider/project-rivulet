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
    final historyAsync = ref.watch(
      mediaHistoryProvider(externalId: widget.itemId, type: widget.type),
    );

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
                        // Use widget.itemId for consistency with provider family,
                        // unless we want to be very specific about adding with IMDb.
                        // But check uses widget.itemId.
                        // If we add with IMDb ID, Check with TMDB ID works (as validated).
                        // So using widget.itemId for toggle is simplest and consistent.
                        // But wait, if I add with TMDB ID, AddToLibrary service might re-fetch details if it doesn't see "tt".
                        // AddToLibrary handles "tmdb:123" or just "123".
                        // If I pass "123" (TMDB ID), CheckLibrary("123") works.
                        // So let's stick to widget.itemId for everything to avoid confusion,
                        // UNLESS user specifically requested IMDb ID preference for ADDING.
                        // User said: "try to ise IMDB ids whenever possible".
                        // So if I add, I should use IMDb ID.
                        // But CheckLibrary needs to know if THAT item is in library.
                        // If I check(TMDB_ID) -> returns true/false.
                        // If false -> I call toggle.
                        // toggle -> calls provider.toggle.
                        // provider.toggle calls repo.addToLibrary(id).
                        // I need to pass the PREFERRED ID to provider.toggle?
                        // Provider build(id) uses one ID.
                        // If I construct provider with TMDB ID, toggle uses TMDB ID.
                        // Maybe I should pass preferred ID to toggle?

                        // Let's modify provider.toggle to accept id/type override?
                        // Or just update MediaDetailScreen to handle logic manually instead of provider.toggle?
                        // Provider toggle is cleaner.
                        // Let's pass (id, type) to toggle.

                        final idToAdd =
                            detail?.imdbId ??
                            (detail?.id.isNotEmpty == true
                                ? detail!.id
                                : widget.itemId);
                        final typeToAdd = detail?.type ?? widget.type;

                        // If inLibrary, remove (using widget.itemId or checking ID? Remove uses externalID lookup).
                        // RemoveFromLibrary(id) checks external_ids.
                        // So removing by TMDB ID works even if added by IMDb ID.

                        // Adding: If I add by TMDB ID, it works.
                        // User prefers IMDb.
                        // So if NOT in library, I want to add using `idToAdd` (IMDb).
                        // But provider holds `id` (TMDB).

                        // I will update provider to allow passing add arguments.
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
                                  bool isResuming =
                                      !latest.isWatched &&
                                      latest.positionTicks > 0;
                                  String label = "Continue Watching";
                                  bool shouldShow = true;

                                  if (latest.isWatched) {
                                    // Logic to find Next Up
                                    label = "Next Up";

                                    // STRICT: Only use stored next episode
                                    if (latest.nextSeason != null &&
                                        latest.nextEpisode != null) {
                                      targetS = latest.nextSeason!;
                                      targetE = latest.nextEpisode!;
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
                                          title: Text('S$targetS E$targetE'),
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
                                              builder: (context) => StreamSelectionSheet(
                                                externalId:
                                                    detail.imdbId ??
                                                    widget.itemId,
                                                title: 'S${targetS}E${targetE}',
                                                type: 'show',
                                                season: targetS,
                                                episode: targetE,
                                                // Only pass resume params if resuming EXACT episode
                                                startPosition: isResuming
                                                    ? latest.positionTicks
                                                    : null,
                                                resumeMagnet: isResuming
                                                    ? latest.lastMagnet
                                                    : null,
                                                resumeFileIndex: isResuming
                                                    ? latest.lastFileIndex
                                                    : null,
                                                // STRICT: Use stored values or null if not available for resume
                                                nextSeason: latest.nextSeason,
                                                nextEpisode: latest.nextEpisode,
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
                                        // Open Stream Selection for Episode
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (context) => StreamSelectionSheet(
                                            externalId:
                                                detail.imdbId ??
                                                widget
                                                    .itemId, // Use IMDB ID if available
                                            title:
                                                'S${_selectedSeason}E${episode.episodeNumber} - ${episode.name}',
                                            type: 'show',
                                            season: _selectedSeason,
                                            episode: episode.episodeNumber,
                                            nextSeason: (() {
                                              if (index + 1 < episodes.length)
                                                return _selectedSeason;
                                              // Check for next season
                                              final seasons = ref
                                                  .read(
                                                    showSeasonsProvider(
                                                      widget.itemId,
                                                    ),
                                                  )
                                                  .asData
                                                  ?.value;
                                              if (seasons != null) {
                                                final currentIdx = seasons
                                                    .indexWhere(
                                                      (s) =>
                                                          s.seasonNumber ==
                                                          _selectedSeason,
                                                    );
                                                if (currentIdx != -1 &&
                                                    currentIdx + 1 <
                                                        seasons.length) {
                                                  return seasons[currentIdx + 1]
                                                      .seasonNumber;
                                                }
                                              }
                                              return null;
                                            })(),
                                            nextEpisode: (() {
                                              if (index + 1 < episodes.length)
                                                return episodes[index + 1]
                                                    .episodeNumber;
                                              // Check for next season
                                              final seasons = ref
                                                  .read(
                                                    showSeasonsProvider(
                                                      widget.itemId,
                                                    ),
                                                  )
                                                  .asData
                                                  ?.value;
                                              if (seasons != null) {
                                                final currentIdx = seasons
                                                    .indexWhere(
                                                      (s) =>
                                                          s.seasonNumber ==
                                                          _selectedSeason,
                                                    );
                                                if (currentIdx != -1 &&
                                                    currentIdx + 1 <
                                                        seasons.length) {
                                                  return 1;
                                                }
                                              }
                                              return null;
                                            })(),
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
                String? resMagnet;
                int? resFileIdx;

                if (historyAsync.hasValue && historyAsync.value!.isNotEmpty) {
                  final h = historyAsync.value!.first;
                  if (!h.isWatched && h.positionTicks > 0) {
                    startPos = h.positionTicks;
                    resMagnet = h.lastMagnet;
                    resFileIdx = h.lastFileIndex;
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
                    resumeMagnet: resMagnet,
                    resumeFileIndex: resFileIdx,
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
