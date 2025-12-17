import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
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
import '../../downloads/providers/offline_providers.dart';
import '../../player/player_screen.dart';

// Enum for Show View State
enum ShowViewMode { main, season, episode }

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
  // Show State
  ShowViewMode _viewMode = ShowViewMode.main;
  int? _selectedSeason; // Nullable to allow Deselect
  DiscoveryEpisode? _selectedEpisode; // For Screen 3

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

    return PopScope(
      canPop:
          _viewMode == ShowViewMode.main &&
          (widget.type == 'movie' || _viewMode == ShowViewMode.main),
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_viewMode == ShowViewMode.episode) {
          setState(() {
            _viewMode = ShowViewMode.season;
          });
        } else if (_viewMode == ShowViewMode.season) {
          setState(() {
            _viewMode = ShowViewMode.main;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_viewMode == ShowViewMode.episode) {
                setState(() {
                  _viewMode = ShowViewMode.season;
                });
              } else if (_viewMode == ShowViewMode.season) {
                setState(() {
                  _viewMode = ShowViewMode.main;
                });
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
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

            if (detail.type == 'movie') {
              return _buildMovieLayout(
                context,
                detail,
                downloadsAsync,
                historyAsync,
              );
            } else {
              // Show Layout
              return _buildShowLayout(
                context,
                detail,
                downloadsAsync,
                historyAsync,
              );
            }
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
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

  Widget _buildBackdrop(BuildContext context, String? backdropUrl) {
    if (!widget.offlineMode &&
        backdropUrl != null &&
        backdropUrl.startsWith('/')) {
      backdropUrl = 'https://image.tmdb.org/t/p/original$backdropUrl';
    }

    return Stack(
      fit: StackFit.expand,
      children: [
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
      ],
    );
  }

  Widget _buildMovieLayout(
    BuildContext context,
    MediaDetail detail,
    AsyncValue<List<TaskRecord>> downloadsAsync,
    AsyncValue<List<HistoryItem>> historyAsync,
  ) {
    String? posterUrl = detail.posterUrl;
    if (!widget.offlineMode && posterUrl != null && posterUrl.startsWith('/')) {
      posterUrl = 'https://image.tmdb.org/t/p/w780$posterUrl';
    }

    final logoUrl = detail
        .logo; // Assuming fully qualified or handled by Image widget if typical

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackdrop(context, detail.backdropUrl),

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

                // Column 2: Info (42%)
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
                const SizedBox(width: 48),

                // Column 3: Logo + Buttons (33%)
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

                          // Play Button with Progress Overlay
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                double progress = 0.0;
                                String label = 'Play';
                                int? startPos;

                                if (historyAsync.hasValue &&
                                    historyAsync.value!.isNotEmpty) {
                                  final h = historyAsync.value!.first;
                                  if (!h.isWatched && h.positionTicks > 0) {
                                    label =
                                        'Resume ${_formatDuration(h.positionTicks)}';
                                    startPos = h.positionTicks;
                                    if (h.durationTicks > 0) {
                                      progress =
                                          h.positionTicks / h.durationTicks;
                                      if (progress > 1.0) progress = 1.0;
                                    }
                                  }
                                }

                                return SizedBox(
                                  height: 52,
                                  child: Material(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () async {
                                        final downloadedPath =
                                            await _resolveDownloadPath(
                                              ref,
                                              downloadsAsync.asData?.value ??
                                                  [],
                                              detail.imdbId ?? detail.id,
                                            );

                                        if (!context.mounted) return;

                                        final url =
                                            await showModalBottomSheet<String>(
                                              context: context,
                                              isScrollControlled: true,
                                              builder: (context) =>
                                                  StreamSelectionSheet(
                                                    externalId:
                                                        detail.imdbId ??
                                                        detail.id,
                                                    title: detail.title,
                                                    type: 'movie',
                                                    startPosition: startPos,
                                                    imdbId: detail.imdbId,
                                                    downloadedPath:
                                                        downloadedPath,
                                                  ),
                                            );

                                        if (url != null && context.mounted) {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PlayerScreen(
                                                url: url,
                                                externalId:
                                                    detail.imdbId ?? detail.id,
                                                title: detail.title,
                                                type: 'movie',
                                                startPosition:
                                                    startPos ??
                                                    0, // calculated locally above
                                                imdbId: detail.imdbId,
                                              ),
                                            ),
                                          );

                                          if (mounted) {
                                            // Sync history and reload details on exit
                                            if (widget.offlineMode) {
                                              ref.invalidate(
                                                offlineMediaDetailProvider(
                                                  id: widget.itemId,
                                                ),
                                              );
                                            } else {
                                              ref.invalidate(
                                                mediaDetailProvider(
                                                  id: widget.itemId,
                                                  type: widget.type ?? 'movie',
                                                ),
                                              );
                                              ref.invalidate(
                                                mediaHistoryProvider(
                                                  externalId: widget.itemId,
                                                  type: 'movie',
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      },
                                      child: Stack(
                                        children: [
                                          // Progress Bar (Dark Overlay)
                                          if (progress > 0)
                                            Positioned.fill(
                                              child: LayoutBuilder(
                                                builder:
                                                    (context, constraints) {
                                                      return Align(
                                                        alignment: Alignment
                                                            .centerLeft,
                                                        child: Container(
                                                          width:
                                                              constraints
                                                                  .maxWidth *
                                                              progress,
                                                          color: Colors.black
                                                              .withOpacity(
                                                                0.25,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                              ),
                                            ),

                                          // Content
                                          Center(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.play_arrow_rounded,
                                                  size: 28,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  label,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildShowLayout(
    BuildContext context,
    MediaDetail detail,
    AsyncValue<List<TaskRecord>> downloadsAsync,
    AsyncValue<List<HistoryItem>> historyAsync,
  ) {
    switch (_viewMode) {
      case ShowViewMode.main:
        return _buildShowMainView(
          context,
          detail,
          downloadsAsync,
          historyAsync,
        );
      case ShowViewMode.season:
        return _buildSeasonLayout(
          context,
          detail,
          downloadsAsync,
          historyAsync,
        );
      case ShowViewMode.episode:
        return _buildEpisodeLayout(
          context,
          detail,
          downloadsAsync,
          historyAsync,
        );
    }
  }

  Widget _buildSeasonLayout(
    BuildContext context,
    MediaDetail detail,
    AsyncValue<List<TaskRecord>> downloadsAsync,
    AsyncValue<List<HistoryItem>> historyAsync,
  ) {
    // 1. Fetch Episodes
    final episodesAsync = ref.watch(
      seasonEpisodesProvider(id: widget.itemId, seasonNum: _selectedSeason!),
    );

    return episodesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (seasonDetail) {
        final episodes = seasonDetail.episodes;

        // Find Season Poster
        final seasonsAsync = ref.watch(showSeasonsProvider(widget.itemId));
        final seasonPoster = seasonsAsync.value
            ?.where((s) => s.seasonNumber == _selectedSeason)
            .firstOrNull
            ?.posterPath;

        final posterUrlToUse = seasonPoster != null
            ? 'https://image.tmdb.org/t/p/w780$seasonPoster'
            : (detail.posterUrl != null && detail.posterUrl!.startsWith('/')
                  ? 'https://image.tmdb.org/t/p/w780${detail.posterUrl}'
                  : detail.posterUrl);

        // Resolve Downloads
        final downloads = downloadsAsync.value ?? [];

        return Padding(
          padding: const EdgeInsets.all(32.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Poster (Flex 3)
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 2 / 3,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: posterUrlToUse != null
                              ? Image.network(posterUrlToUse, fit: BoxFit.cover)
                              : Container(
                                  color: Colors.grey[900],
                                  child: const Icon(Icons.tv, size: 50),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Back Button
                    // Back Button Removed as per request
                  ],
                ),
              ),

              const SizedBox(width: 32),

              // Right Column: Episodes (Flex 9)
              Expanded(
                flex: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        // Download Season Button
                        FilledButton.icon(
                          onPressed: () {
                            // Batch Download
                            _startBulkDownload(
                              episodes,
                              detail,
                              _selectedSeason!,
                              downloads,
                            );
                          },
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Download Season'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.tertiary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onTertiary,
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Title Group
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.title,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Season $_selectedSeason',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Divider(height: 32),

                    // Episode List
                    Expanded(
                      child: ListView.separated(
                        itemCount: episodes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final episode = episodes[index];

                          // Find Download Task
                          final task = downloads.firstWhereOrNull((r) {
                            final meta = _getTaskMetadata(r);
                            return (meta['mediaId'] == detail.id ||
                                    meta['mediaId'] == detail.imdbId) &&
                                meta['season'] == _selectedSeason &&
                                meta['episode'] == episode.episodeNumber;
                          });

                          // Find History
                          final historyItem = historyAsync.value
                              ?.firstWhereOrNull(
                                (h) =>
                                    (h.mediaId == detail.id ||
                                        h.mediaId == detail.imdbId) &&
                                    h.seasonNumber == _selectedSeason &&
                                    h.episodeNumber == episode.episodeNumber,
                              );

                          return _EpisodeCard(
                            episode: episode,
                            history: historyItem,
                            downloadTask: task,
                            onTap: () {
                              setState(() {
                                _selectedEpisode = episode;
                                _viewMode = ShowViewMode.episode;
                              });
                            },
                            onPlay: () {
                              // Play logic
                            },
                            onDownload: () {
                              ref
                                  .read(downloadServiceProvider)
                                  .startDownload(
                                    mediaUuid: detail.id,
                                    url: '',
                                    title:
                                        '${detail.title} - S${_selectedSeason}E${episode.episodeNumber}',
                                    type: 'show',
                                    posterPath: detail.posterUrl,
                                    backdropPath: detail.backdropUrl,
                                    logoPath: detail.logo,
                                    overview: episode.overview,
                                    imdbId: detail.imdbId,
                                    seasonNumber: _selectedSeason,
                                    episodeNumber: episode.episodeNumber,
                                  );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Download started'),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEpisodeLayout(
    BuildContext context,
    MediaDetail detail,
    AsyncValue<List<TaskRecord>> downloadsAsync,
    AsyncValue<List<HistoryItem>> historyAsync,
  ) {
    if (_selectedEpisode == null) {
      return const Center(child: Text("No Episode Selected"));
    }
    final episode = _selectedEpisode!;

    // Resolving Season Poster
    final seasonsAsync = ref.watch(showSeasonsProvider(widget.itemId));
    final seasonPoster = seasonsAsync.value
        ?.where((s) => s.seasonNumber == _selectedSeason)
        .firstOrNull
        ?.posterPath;

    final posterUrlToUse = seasonPoster != null
        ? 'https://image.tmdb.org/t/p/w780$seasonPoster'
        : (detail.posterUrl != null && detail.posterUrl!.startsWith('/')
              ? 'https://image.tmdb.org/t/p/w780${detail.posterUrl}'
              : detail.posterUrl);

    // Find Download Task
    final downloads = downloadsAsync.value ?? [];
    final task = downloads.firstWhereOrNull((r) {
      final meta = _getTaskMetadata(r);
      return (meta['mediaId'] == detail.id ||
              meta['mediaId'] == detail.imdbId) &&
          meta['season'] == _selectedSeason &&
          meta['episode'] == episode.episodeNumber;
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackdrop(context, detail.backdropUrl), // Use Show backdrop
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48.0, 32.0, 48.0, 64.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 1. Poster (Season)
                Expanded(
                  flex: 3,
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
                        child: posterUrlToUse != null
                            ? Image.network(posterUrlToUse, fit: BoxFit.cover)
                            : Container(
                                color: Colors.grey[900],
                                child: const Icon(Icons.tv, size: 50),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 32),

                // 2. Info (Middle)
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${detail.title} • S${_selectedSeason} E${episode.episodeNumber}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        episode.name,
                        style: Theme.of(context).textTheme.displaySmall
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      // Meta
                      Row(
                        children: [
                          if (episode.airDate != null)
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
                                episode.airDate!.split('-').first,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          const SizedBox(width: 16),
                          if (episode.voteAverage != null &&
                              episode.voteAverage! > 0)
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  episode.voteAverage!.toStringAsFixed(1),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        episode.overview ??
                            'No description available for this episode.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.4,
                          shadows: [
                            BoxShadow(color: Colors.black, blurRadius: 10),
                          ],
                        ),
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        // Back Button Removed as per request
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 48),

                // 3. Actions (Right)
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Episode Still
                      if (episode.stillPath != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  'https://image.tmdb.org/t/p/w780${episode.stillPath}',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Buttons
                      Row(
                        children: [
                          // Download Button
                          Container(
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(
                                task != null &&
                                        task.status == TaskStatus.complete
                                    ? Icons.check_circle
                                    : Icons.download_rounded,
                              ),
                              tooltip:
                                  task != null &&
                                      task.status == TaskStatus.complete
                                  ? 'Downloaded'
                                  : 'Download Episode',
                              onPressed:
                                  task != null &&
                                      task.status == TaskStatus.complete
                                  ? null
                                  : () {
                                      _showDownloadSheet(
                                        context,
                                        ref,
                                        detail,
                                        episode,
                                      );
                                    },
                            ),
                          ),

                          // Play Button with Progress Overlay
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                double progress = 0.0;
                                String label = 'Play';
                                int? startPos;

                                if (historyAsync.hasValue) {
                                  final h = historyAsync.value!
                                      .firstWhereOrNull(
                                        (item) =>
                                            item.seasonNumber ==
                                                _selectedSeason &&
                                            item.episodeNumber ==
                                                episode.episodeNumber,
                                      );
                                  if (h != null &&
                                      !h.isWatched &&
                                      h.positionTicks > 0) {
                                    label =
                                        'Resume ${_formatDuration(h.positionTicks)}';
                                    startPos = h.positionTicks;
                                    if (h.durationTicks > 0) {
                                      progress =
                                          h.positionTicks / h.durationTicks;
                                      if (progress > 1.0) progress = 1.0;
                                    }
                                  }
                                }

                                return SizedBox(
                                  height: 52,
                                  child: Material(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () async {
                                        final downloadedPath =
                                            await _resolveDownloadPath(
                                              ref,
                                              downloadsAsync.asData?.value ??
                                                  [],
                                              detail.imdbId ?? detail.id,
                                              season: _selectedSeason,
                                              episode: episode.episodeNumber,
                                            );

                                        if (!context.mounted) return;

                                        final url =
                                            await showModalBottomSheet<String>(
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
                                                    episode:
                                                        episode.episodeNumber,
                                                    imdbId: detail.imdbId,
                                                    startPosition: startPos,
                                                    downloadedPath:
                                                        downloadedPath,
                                                  ),
                                            );

                                        if (url != null && context.mounted) {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PlayerScreen(
                                                url: url,
                                                externalId:
                                                    detail.imdbId ??
                                                    widget.itemId,
                                                title:
                                                    'S${_selectedSeason}E${episode.episodeNumber} - ${episode.name}',
                                                type: 'show',
                                                season: _selectedSeason,
                                                episode: episode.episodeNumber,
                                                startPosition: startPos ?? 0,
                                                imdbId: detail.imdbId,
                                              ),
                                            ),
                                          );

                                          if (mounted) {
                                            if (widget.offlineMode) {
                                              ref.invalidate(
                                                offlineMediaDetailProvider(
                                                  id: widget.itemId,
                                                ),
                                              );
                                            } else {
                                              ref.invalidate(
                                                mediaDetailProvider(
                                                  id: widget.itemId,
                                                  type: widget.type ?? 'movie',
                                                ),
                                              );
                                              ref.invalidate(
                                                mediaHistoryProvider(
                                                  externalId: widget.itemId,
                                                  type: 'show',
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      },
                                      child: Stack(
                                        children: [
                                          // Fix for width: Use FractionallySizedBox inside the Stack if we want it relative to the button width
                                          if (progress > 0)
                                            Positioned.fill(
                                              child: LayoutBuilder(
                                                builder:
                                                    (context, constraints) {
                                                      return Align(
                                                        alignment: Alignment
                                                            .centerLeft,
                                                        child: Container(
                                                          width:
                                                              constraints
                                                                  .maxWidth *
                                                              progress,
                                                          color: Colors.black
                                                              .withOpacity(
                                                                0.25,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                              ),
                                            ),

                                          // Content
                                          Center(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.play_arrow_rounded,
                                                  size: 28,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  label,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildShowMainView(
    BuildContext context,
    MediaDetail detail,
    AsyncValue<List<TaskRecord>> downloadsAsync,
    AsyncValue<List<HistoryItem>> historyAsync,
  ) {
    String? posterUrl = detail.posterUrl;
    if (!widget.offlineMode && posterUrl != null && posterUrl.startsWith('/')) {
      posterUrl = 'https://image.tmdb.org/t/p/w780$posterUrl';
    }

    final logoUrl = detail.logo;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackdrop(context, detail.backdropUrl),

        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48.0, 32.0, 48.0, 64.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Column 1: Poster (25%) - Isolated
                Expanded(
                  flex: 3,
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

                // Right Side: Info + Actions + Seasons
                Expanded(
                  flex: 9,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Top Row: Info (5) | Actions (4)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Info
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  detail.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayMedium
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
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(width: 16),
                                    ],
                                    if (detail.releaseDate != null) ...[
                                      Text(
                                        detail.releaseDate!.split('-').first,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(width: 16),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.white70,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'SHOW',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  detail.overview ?? '',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        height: 1.4,
                                        fontSize: 16,
                                        shadows: [
                                          BoxShadow(
                                            color: Colors.black,
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                  maxLines:
                                      4, // Reduced lines for Show view to make room for seasons
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 48),

                          // Actions
                          Expanded(
                            flex: 4,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (logoUrl != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 24.0,
                                    ),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxHeight: 120,
                                      ),
                                      child: widget.offlineMode
                                          ? Image.file(
                                              File(logoUrl),
                                              fit: BoxFit.contain,
                                            )
                                          : Image.network(
                                              logoUrl,
                                              fit: BoxFit.contain,
                                            ),
                                    ),
                                  ),

                                const SizedBox(height: 16),
                                // Buttons Row
                                Row(
                                  children: [
                                    // Library Button
                                    if (!widget.offlineMode)
                                      _buildLibraryButton(context, ref),

                                    // Download Button (Batch Show)
                                    if (!widget.offlineMode)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          right: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.download_rounded,
                                          ),
                                          tooltip: 'Download Show',
                                          onPressed: () {
                                            // TODO: Implement Batch Download Show
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Download Show not implemented yet',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),

                                    // Play Button
                                    Expanded(
                                      child: SizedBox(
                                        height: 52,
                                        child: FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.play_arrow_rounded,
                                            size: 28,
                                          ),
                                          label: const Text(
                                            'Play',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () {
                                            // Default play logic (S1E1 or Continue)
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Continue Watching (If available)
                      _buildContinueWatching(context, detail, historyAsync),

                      const SizedBox(height: 16),

                      // Seasons List
                      SizedBox(
                        height: 250, // Increased height for hover effect
                        child: _buildSeasonList(context, detail),
                      ),
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

  Widget _buildContinueWatching(
    BuildContext context,
    MediaDetail detail,
    AsyncValue<List<HistoryItem>> historyAsync,
  ) {
    if (!historyAsync.hasValue || historyAsync.value!.isEmpty)
      return const SizedBox.shrink();

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

    // Determine what to show
    // If watched, show next episode if available. If not watched, show current.
    // For now, simplify: if current is unfinished, show it.

    if (latest.isWatched) {
      // TODO: Handle "Up Next" using latest.nextEpisode / nextSeason
      // For now, don't show "Continue Watching" if last item was fully watched
      return const SizedBox.shrink();
    }

    if (latest.positionTicks < (latest.durationTicks * 0.05)) {
      // If barely started, maybe skip? or show "Start"? User said "continue watching".
      // Keep it.
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // Episode Still
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: latest.backdropPath.isNotEmpty
                ? Image.network(
                    'https://image.tmdb.org/t/p/w300${latest.backdropPath}',
                    height: 80,
                    width: 140,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 80,
                    width: 140,
                    color: Colors.black,
                    child: const Center(child: Icon(Icons.play_arrow)),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Continue Watching S${latest.seasonNumber}E${latest.episodeNumber}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  latest.title,
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
            onPressed: () {
              // Logic to resume playback
              // We can reuse the play logic from buttons
              // For now, just print or TODO
            },
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryButton(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        final statusAsync = ref.watch(libraryStatusProvider(widget.itemId));
        return statusAsync.when(
          data: (inLibrary) => Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(inLibrary ? Icons.check : Icons.add),
              tooltip: inLibrary ? 'Remove from Library' : 'Add to Library',
              onPressed: () async {
                try {
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
                      .read(libraryStatusProvider(widget.itemId).notifier)
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
            ),
          ),
          loading: () => Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(right: 16),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildSeasonList(BuildContext context, MediaDetail detail) {
    if (widget.offlineMode) return const SizedBox.shrink();

    final seasonsAsync = ref.watch(showSeasonsProvider(widget.itemId));

    return seasonsAsync.when(
      data: (seasons) {
        if (seasons.isEmpty) return const SizedBox.shrink();
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: seasons.length,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (context, index) {
            final season = seasons[index];
            return _SeasonCard(
              season: season,
              onTap: () {
                setState(() {
                  _selectedSeason = season.seasonNumber;
                  _viewMode = ShowViewMode.season;
                });
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(child: Text('Error: $e')),
    );
  }
} // End Class

class _SeasonCard extends StatefulWidget {
  final DiscoverySeason season;
  final VoidCallback onTap;

  const _SeasonCard({required this.season, required this.onTap});

  @override
  State<_SeasonCard> createState() => _SeasonCardState();
}

class _SeasonCardState extends State<_SeasonCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.season.posterPath != null
                    ? Image.network(
                        'https://image.tmdb.org/t/p/w342${widget.season.posterPath}',
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Center(child: Icon(Icons.tv)),
                      ),

                // Sliding Gradient Box
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  left: 0,
                  right: 0,
                  bottom: _isHovered ? 0 : -80, // Slide up from bottom
                  height: 80,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.9),
                          Colors.transparent,
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      widget.season.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeCard extends StatefulWidget {
  final DiscoveryEpisode episode;
  final HistoryItem? history;
  final TaskRecord? downloadTask;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onDownload;

  const _EpisodeCard({
    required this.episode,
    this.history,
    this.downloadTask,
    required this.onTap,
    required this.onPlay,
    required this.onDownload,
  });

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
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
                            ? Image.network(
                                'https://image.tmdb.org/t/p/w300${widget.episode.stillPath}',
                                fit: BoxFit.cover,
                                width: double.infinity,
                              )
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
              IconButton(
                onPressed: widget.onDownload,
                icon: Icon(
                  widget.downloadTask != null &&
                          widget.downloadTask!.status == TaskStatus.complete
                      ? Icons.check_circle
                      : Icons.download_rounded,
                ),
                tooltip: 'Download',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
