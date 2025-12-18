import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:rivulet/features/auth/profiles_provider.dart';
import 'package:rivulet/features/discovery/discovery_provider.dart';
import 'dart:convert';
import 'package:background_downloader/background_downloader.dart';
import 'package:path/path.dart' as p;
import 'package:rivulet/features/widgets/action_scale.dart';
import 'dart:io';

import '../widgets/stream_selection_sheet.dart';
import '../domain/discovery_models.dart';
import '../../downloads/services/download_service.dart';
import '../../downloads/providers/downloads_provider.dart';
import '../../downloads/providers/offline_providers.dart';
import '../../player/player_screen.dart';
import '../widgets/media_detail/backdrop_background.dart';
import '../widgets/media_detail/poster_banner.dart';
import 'package:rivulet/features/discovery/widgets/expandable_text.dart';
import '../widgets/media_detail/play_button.dart';
import '../widgets/media_detail/library_button.dart';
import '../widgets/media_detail/season_list.dart';
import '../widgets/media_detail/episode_card.dart';
import '../widgets/media_detail/continue_watching_card.dart';
import '../widgets/media_detail/download_button.dart';

// Enum for Show View State
enum ShowViewMode { main, season, episode }

class MediaDetailScreen extends ConsumerStatefulWidget {
  final String itemId;
  final String? type; // 'movie' or 'show'
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
  ShowViewMode _viewMode = ShowViewMode.main;
  int? _selectedSeason;
  DiscoveryEpisode? _selectedEpisode;
  SeasonDetail? _seasonDetail;

  @override
  Widget build(BuildContext context) {
    final detailAsync = widget.offlineMode
        ? ref.watch(offlineMediaDetailProvider(id: widget.itemId))
        : ref.watch(
            mediaDetailProvider(
              id: widget.itemId,
              type: widget.type ?? 'movie',
            ),
          );

    String? effectiveHistoryId;
    if (widget.itemId.startsWith('tt')) {
      effectiveHistoryId = widget.itemId;
    } else if (detailAsync.asData?.value.imdbId != null) {
      effectiveHistoryId = detailAsync.asData!.value.imdbId;
    }

    final historyAsync = (effectiveHistoryId != null)
        ? (widget.offlineMode
              ? ref.watch(offlineMediaHistoryProvider(id: widget.itemId))
              : ref.watch(
                  mediaHistoryProvider(
                    externalId: effectiveHistoryId,
                    type: widget.type ?? 'movie',
                  ),
                ))
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
              return _buildMovieLayout(context, detail, historyAsync);
            } else {
              // Show Layout
              return _buildShowLayout(context, detail, historyAsync);
            }
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Future<void> _playMovie(int? startPos, String mediaId, String title) async {
    await _playMedia(startPos, mediaId, 'movie', null, null, title);
  }

  Future<void> _playEpisode(
    int? startPos,
    String mediaId,
    int seasonNumber,
    int episodeNumber,
    String title,
  ) async {
    await _playMedia(
      startPos,
      mediaId,
      'show',
      seasonNumber,
      episodeNumber,
      title,
    );
  }

  Future<void> _playMedia(
    int? startPos,
    String mediaId,
    String type,
    int? seasonNumber,
    int? episodeNumber,
    String title,
  ) async {
    final downloadedPath = await _resolveDownloadPath(
      ref,
      mediaId,
      season: seasonNumber,
      episode: episodeNumber,
    );

    if (!mounted) return;

    // Offline Mode Auto-Play Logic
    if (widget.offlineMode) {
      if (downloadedPath != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(
              url: downloadedPath,
              externalId: mediaId,
              title: title,
              type: type,
              season: seasonNumber ?? 0,
              episode: episodeNumber ?? 0,
              startPosition: startPos ?? 0,
              imdbId: mediaId,
              offlineMode: true,
            ),
          ),
        );
        // Refresh details on return to update history/progress
        if (mounted) {
          if (widget.offlineMode) {
            ref.invalidate(offlineMediaDetailProvider(id: widget.itemId));
            ref.invalidate(offlineMediaHistoryProvider(id: widget.itemId));
          } else {
            ref.invalidate(mediaDetailProvider(id: widget.itemId, type: type));
            ref.invalidate(
              mediaHistoryProvider(externalId: widget.itemId, type: type),
            );
          }
        }
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download not found for offline playback'),
          ),
        );
        return;
      }
    }

    final url = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StreamSelectionSheet(
        externalId: mediaId,
        title: title,
        type: type,
        season: seasonNumber,
        episode: episodeNumber,
        imdbId: mediaId,
        startPosition: startPos,
        downloadedPath: downloadedPath,
      ),
    );

    if (url != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            url: url,
            externalId: mediaId,
            title: 'S${seasonNumber}E$episodeNumber',
            type: type,
            season: seasonNumber,
            episode: episodeNumber,
            startPosition: startPos ?? 0,
            imdbId: mediaId,
            offlineMode: widget.offlineMode,
          ),
        ),
      );

      if (mounted) {
        if (widget.offlineMode) {
          ref.invalidate(offlineMediaDetailProvider(id: widget.itemId));
          ref.invalidate(offlineMediaHistoryProvider(id: widget.itemId));
        } else {
          ref.invalidate(mediaDetailProvider(id: widget.itemId, type: type));
          ref.invalidate(
            mediaHistoryProvider(externalId: widget.itemId, type: type),
          );
        }
      }
    }
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
  ) async {
    final existingDownloads = await ref.read(allDownloadsProvider.future);
    bool cancelRemaining = false;
    SeasonDetail seasonDetail = _seasonDetail!;

    for (int i = 0; i < episodes.length; i++) {
      if (cancelRemaining) break;

      final episode = episodes[i];

      // Check if already downloaded
      final isDownloaded = existingDownloads.any((record) {
        final meta = _getTaskMetadata(record);
        final targetId = detail.imdbId ?? detail.id;

        return (meta['mediaId'] == targetId || meta['mediaId'] == detail.id) &&
            meta['season'] == seasonDetail.seasonNumber &&
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
          title:
              'Downloading S${seasonDetail.seasonNumber}E${episode.episodeNumber}',
          type: 'show',
          season: seasonDetail.seasonNumber,
          episode: episode.episodeNumber,
          imdbId: detail.imdbId,
          onStreamSelected: (url, filename, quality) {
            ref
                .read(downloadServiceProvider)
                .startEpisodeDownload(
                  mediaUuid: detail.id,
                  url: url,
                  title:
                      'S${seasonDetail.seasonNumber}E${episode.episodeNumber} - ${episode.name}',
                  posterPath: detail.posterUrl,
                  backdropPath: detail.backdropUrl,
                  logoPath: detail.logo,
                  overview: detail.overview,
                  imdbId: detail.imdbId,
                  voteAverage: detail.rating,
                  showTitle: detail.title,
                  seasonNumber: seasonDetail.seasonNumber,
                  seasonName: seasonDetail.name,
                  seasonOverview: seasonDetail.overview,
                  episodeNumber: episode.episodeNumber,
                  episodeOverview: episode.overview,
                  episodeStillPath: episode.stillPath,
                  episodeTitle: episode.name, // Pass name as title
                  seasonPosterPath: _getSeasonPosterPath(
                    seasonDetail.seasonNumber,
                  ),
                  seasons: ref
                      .read(showSeasonsProvider(widget.itemId))
                      .value
                      ?.map((s) => s.toJson())
                      .toList(),
                  profileId: ref.read(selectedProfileProvider),
                );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Queued S${seasonDetail.seasonNumber}E${episode.episodeNumber}',
                ),
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

  void _movieDownloadSheet(
    BuildContext context,
    WidgetRef ref,
    MediaDetail detail,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StreamSelectionSheet(
        externalId: detail.imdbId ?? detail.id,
        title: detail.title,
        type: 'movie',
        imdbId: detail.imdbId,
        onStreamSelected: (url, filename, quality) {
          ref
              .read(downloadServiceProvider)
              .startMovieDownload(
                mediaUuid: detail.id,
                url: url,
                title: detail.title,
                posterPath: detail.posterUrl,
                backdropPath: detail.backdropUrl,
                logoPath: detail.logo,
                overview: detail.overview,
                imdbId: detail.imdbId,
                voteAverage: detail.rating,
                profileId: ref.read(selectedProfileProvider),
              );
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Download started')));
        },
      ),
    );
  }

  void _showDownloadSheet(
    BuildContext context,
    WidgetRef ref,
    MediaDetail detail,
    DiscoveryEpisode episode,
  ) {
    SeasonDetail seasonDetail = _seasonDetail!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StreamSelectionSheet(
        externalId: detail.imdbId ?? widget.itemId,
        title:
            'S${seasonDetail.seasonNumber}E${episode.episodeNumber} - ${episode.name}',
        type: 'show',
        season: seasonDetail.seasonNumber,
        episode: episode.episodeNumber,
        imdbId: detail.imdbId,
        onStreamSelected: (url, _, __) {
          ref
              .read(downloadServiceProvider)
              .startEpisodeDownload(
                mediaUuid: detail.id,
                url: url,
                title:
                    '${detail.title} - S${seasonDetail.seasonNumber}E${episode.episodeNumber}',
                posterPath: detail.posterUrl,
                backdropPath: detail.backdropUrl,
                logoPath: detail.logo,
                overview: detail.overview,
                imdbId: detail.imdbId,
                voteAverage: detail.rating,
                showTitle: detail.title,
                seasonNumber: seasonDetail.seasonNumber,
                seasonName: seasonDetail.name,
                seasonOverview: seasonDetail.overview,
                episodeNumber: episode.episodeNumber,
                episodeOverview: episode.overview,
                episodeStillPath: episode.stillPath,
                episodeTitle: episode.name,
                seasonPosterPath: _getSeasonPosterPath(
                  seasonDetail.seasonNumber,
                ),
                seasons: ref
                    .read(showSeasonsProvider(widget.itemId))
                    .value
                    ?.map((s) => s.toJson())
                    .toList(),
                profileId: ref.read(selectedProfileProvider),
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
    String mediaId, {
    int? season,
    int? episode,
  }) async {
    final downloads = await ref.read(allDownloadsProvider.future);
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

            // Trust task path
            return fullPath;
          }
        }
      }
    }
    return null;
  }

  Widget _buildMovieLayout(
    BuildContext context,
    MediaDetail detail,
    AsyncValue<List<HistoryItem>> historyAsync,
  ) {
    final logoUrl = detail
        .logo; // Assuming fully qualified or handled by Image widget if typical

    return Stack(
      fit: StackFit.expand,
      children: [
        BackdropBackground(
          backdropUrl: detail.backdropUrl,
          offlineMode: widget.offlineMode,
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
                  child: PosterBanner(
                    posterUrl: detail.posterUrl,
                    offlineMode: widget.offlineMode,
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
                          if (!widget.offlineMode)
                            LibraryButton(
                              itemId: widget.itemId,
                              type:
                                  widget.type ??
                                  'movie', // defaulting to type logic
                              offlineMode: widget.offlineMode,
                            ),

                          // Download Button (Square)
                          if (!widget.offlineMode)
                            Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: DownloadButton(
                                mediaId: detail.id,
                                imdbId: detail.imdbId,
                                tooltip: 'Download Movie',
                                onDownload: () {
                                  _movieDownloadSheet(context, ref, detail);
                                },
                              ),
                            ),

                          // Play Button with Progress Overlay
                          Expanded(
                            child: ConnectedPlayButton(
                              externalId: detail.imdbId ?? detail.id,
                              type: 'movie',
                              offlineMode: widget.offlineMode,
                              onPressed: (int? startPos) async {
                                _playMovie(
                                  startPos,
                                  detail.imdbId!,
                                  detail.title,
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
    AsyncValue<List<HistoryItem>> historyAsync,
  ) {
    switch (_viewMode) {
      case ShowViewMode.main:
        return _buildShowMainView(context, detail, historyAsync);
      case ShowViewMode.season:
        return _buildSeasonLayout(context, detail, historyAsync);
      case ShowViewMode.episode:
        return _buildEpisodeLayout(context, detail, historyAsync);
    }
  }

  Widget _buildSeasonLayout(
    BuildContext context,
    MediaDetail detail,
    AsyncValue<List<HistoryItem>> historyAsync,
  ) {
    // 1. Fetch Episodes
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (seasonDetail) {
        _seasonDetail = seasonDetail;
        final episodes = seasonDetail.episodes;

        // Find Season Poster
        final seasonsAsync = widget.offlineMode
            ? ref.watch(offlineAvailableSeasonsProvider(id: widget.itemId))
            : ref.watch(showSeasonsProvider(widget.itemId));
        final seasonPoster = seasonsAsync.value
            ?.where((s) => s.seasonNumber == _selectedSeason)
            .firstOrNull
            ?.posterPath;

        final posterUrlToUse = seasonPoster != null
            ? (widget.offlineMode
                  ? seasonPoster
                  : 'https://image.tmdb.org/t/p/w780$seasonPoster')
            : (detail.posterUrl != null && detail.posterUrl!.startsWith('/')
                  ? (widget.offlineMode
                        ? detail.posterUrl
                        : 'https://image.tmdb.org/t/p/w780${detail.posterUrl}')
                  : detail.posterUrl);

        return Stack(
          fit: StackFit.expand,
          children: [
            BackdropBackground(
              backdropUrl: detail.backdropUrl,
              offlineMode: widget.offlineMode,
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Poster (Flex 3)
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          PosterBanner(
                            posterUrl: posterUrlToUse,
                            offlineMode: widget.offlineMode,
                            placeholderIcon: Icons.tv,
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
                              ActionScale(
                                builder: (context, node) {
                                  return FilledButton.icon(
                                    focusNode: node,
                                    onPressed: () {
                                      // Batch Download
                                      _startBulkDownload(episodes, detail);
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
                                  );
                                },
                              ),
                              const SizedBox(width: 24),
                              // Title Group
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      detail.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Season $_selectedSeason'
                                      '${seasonDetail.name.isNotEmpty && seasonDetail.name != "Season $_selectedSeason" ? " - ${seasonDetail.name}" : ""}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.secondary,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (seasonDetail.overview != null &&
                              seasonDetail.overview!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            ExpandableText(
                              seasonDetail.overview!,
                              maxLines: 3,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],

                          const Divider(height: 32),

                          // Episode List
                          Expanded(
                            child: ListView.separated(
                              itemCount: episodes.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final episode = episodes[index];

                                // Find History
                                final historyItem = historyAsync.value
                                    ?.firstWhereOrNull(
                                      (h) =>
                                          (h.mediaId == detail.id ||
                                              h.mediaId == detail.imdbId) &&
                                          h.seasonNumber == _selectedSeason &&
                                          h.episodeNumber ==
                                              episode.episodeNumber,
                                    );

                                return EpisodeCard(
                                  episode: episode,
                                  history: historyItem,
                                  mediaId: detail.id,
                                  imdbId: detail.imdbId,
                                  season: _selectedSeason!,
                                  offlineMode: widget.offlineMode,
                                  onTap: () {
                                    setState(() {
                                      _selectedEpisode = episode;
                                      _viewMode = ShowViewMode.episode;
                                    });
                                  },
                                  onDownload: () {
                                    _showDownloadSheet(
                                      context,
                                      ref,
                                      detail,
                                      episode,
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
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEpisodeLayout(
    BuildContext context,
    MediaDetail detail,
    AsyncValue<List<HistoryItem>> historyAsync,
  ) {
    if (_selectedEpisode == null) {
      return const Center(child: Text("No Episode Selected"));
    }
    final episode = _selectedEpisode!;

    // Resolving Season Poster
    final seasonsAsync = widget.offlineMode
        ? ref.watch(offlineAvailableSeasonsProvider(id: widget.itemId))
        : ref.watch(showSeasonsProvider(widget.itemId));
    final seasonPoster = seasonsAsync.value
        ?.where((s) => s.seasonNumber == _selectedSeason)
        .firstOrNull
        ?.posterPath;

    final posterUrlToUse = seasonPoster != null
        ? (widget.offlineMode
              ? seasonPoster
              : 'https://image.tmdb.org/t/p/w780$seasonPoster')
        : (detail.posterUrl != null && detail.posterUrl!.startsWith('/')
              ? (widget.offlineMode
                    ? detail.posterUrl
                    : 'https://image.tmdb.org/t/p/w780${detail.posterUrl}')
              : detail.posterUrl);

    return Stack(
      fit: StackFit.expand,
      children: [
        BackdropBackground(
          backdropUrl: detail.backdropUrl,
          offlineMode: widget.offlineMode,
        ), // Use Show backdrop
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48.0, 32.0, 48.0, 64.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 1. Poster (Season)
                Expanded(
                  flex: 3,
                  child: PosterBanner(
                    posterUrl: posterUrlToUse,
                    offlineMode: widget.offlineMode,
                    placeholderIcon: Icons.tv,
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
                        '${detail.title} • S$_selectedSeason E${episode.episodeNumber}',
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
                                child: Stack(
                                  children: [
                                    widget.offlineMode
                                        ? Image.file(
                                            File(episode.stillPath!),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                  color: Colors.grey[900],
                                                  child: const Icon(Icons.tv),
                                                ),
                                          )
                                        : Image.network(
                                            'https://image.tmdb.org/t/p/w780${episode.stillPath}',
                                            fit: BoxFit.cover,
                                          ),
                                    if (historyAsync.value
                                            ?.firstWhereOrNull(
                                              (h) =>
                                                  h.seasonNumber ==
                                                      _selectedSeason &&
                                                  h.episodeNumber ==
                                                      episode.episodeNumber,
                                            )
                                            ?.isWatched ??
                                        false)
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.6,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.remove_red_eye_rounded,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Buttons
                      Row(
                        children: [
                          if (!widget.offlineMode)
                            // Download Button
                            DownloadButton(
                              mediaId: detail.id,
                              imdbId: detail.imdbId,
                              season: _selectedSeason,
                              episode: episode.episodeNumber,
                              tooltip: 'Download Episode',
                              onDownload: () {
                                _showDownloadSheet(
                                  context,
                                  ref,
                                  detail,
                                  episode,
                                );
                              },
                            ),

                          // Play Button with Progress Overlay
                          Expanded(
                            child: ConnectedPlayButton(
                              externalId: detail.imdbId!,
                              type: detail.type,
                              seasonNumber: _selectedSeason,
                              episodeNumber: episode.episodeNumber,
                              offlineMode: widget.offlineMode,
                              onPressed: (int? startPos) async {
                                _playEpisode(
                                  startPos,
                                  detail.imdbId!,
                                  _selectedSeason!,
                                  episode.episodeNumber,
                                  episode.name,
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
    AsyncValue<List<HistoryItem>> historyAsync,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        BackdropBackground(
          backdropUrl: detail.backdropUrl,
          offlineMode: widget.offlineMode,
        ),

        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48.0, 32.0, 48.0, 64.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Column 1: Poster (25%) - Isolated
                Expanded(
                  flex: 3,
                  child: PosterBanner(
                    posterUrl: detail.posterUrl,
                    offlineMode: widget.offlineMode,
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
                                        detail.rating!.toStringAsFixed(1),
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
                                    const SizedBox(width: 16),
                                    if (!widget.offlineMode)
                                      LibraryButton(
                                        itemId: widget.itemId,
                                        type: widget.type ?? 'show',
                                        offlineMode: widget.offlineMode,
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

                          // Actions (Logo Only now)
                          Expanded(
                            flex: 4,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (detail.logo != null &&
                                    detail.logo!.isNotEmpty)
                                  widget.offlineMode
                                      ? Image.file(
                                          File(detail.logo!),
                                          width: 300,
                                          fit: BoxFit.contain,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const SizedBox.shrink(),
                                        )
                                      : Image.network(
                                          detail.logo!.startsWith('/') ||
                                                  detail.logo!.startsWith(
                                                    'http',
                                                  )
                                              ? (detail.logo!.startsWith('/')
                                                    ? 'https://image.tmdb.org/t/p/w500${detail.logo}'
                                                    : detail.logo!)
                                              : 'https://image.tmdb.org/t/p/w500/${detail.logo}',
                                          width: 300,
                                          fit: BoxFit.contain,
                                        ),
                                // Cleaned up buttons and continue watching from here
                              ],
                            ),
                          ),
                        ],
                      ),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [Expanded(child: const SizedBox(height: 32))],
                      ),

                      // Seasons List (with Continue Watching)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 250,
                              child: SeasonList(
                                itemId: widget.itemId,
                                offlineMode: widget.offlineMode,
                                selectedSeason: _selectedSeason,
                                showPosterPath: detail.posterUrl,
                                leading: ContinueWatchingCard(
                                  detail: detail,
                                  historyAsync: historyAsync,
                                  onResume: _playEpisode,
                                  offlineMode: widget.offlineMode,
                                ),
                                onSeasonSelected: (seasonNum) {
                                  setState(() {
                                    _selectedSeason = seasonNum;
                                    _viewMode = ShowViewMode.season;
                                  });
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
          ),
        ),
      ],
    );
  }
}
