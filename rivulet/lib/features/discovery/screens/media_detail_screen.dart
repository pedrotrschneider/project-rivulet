import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:rivulet/features/auth/profiles_provider.dart';
import 'package:rivulet/features/discovery/discovery_provider.dart';
import 'dart:convert';
import 'package:background_downloader/background_downloader.dart';
import 'package:path/path.dart' as p;
import 'package:rivulet/features/discovery/widgets/media_detail/mark_as_watched_button.dart';
import 'package:rivulet/features/widgets/action_scale.dart';
import 'dart:io';

import '../widgets/stream_selection_sheet.dart';
import '../domain/discovery_models.dart';
import '../../downloads/services/download_service.dart';
import '../../downloads/providers/downloads_provider.dart';
import '../../downloads/providers/offline_providers.dart';
import '../../downloads/services/offline_history_service.dart';
import '../../discovery/repository/discovery_repository.dart';
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
  MediaDetail? _mediaDetail;
  List<DiscoverySeason>? _discoverySeasons; // Stores list of seasons metadata
  List<SeasonDetail>?
  _seasonsDetail; // Stores ALL season details (episodes etc)

  // View State (Restored)
  ShowViewMode _viewMode = ShowViewMode.main;
  DiscoverySeason? _selectedSeason;
  DiscoveryEpisode? _selectedEpisode;
  SeasonDetail? _seasonDetail; // Current selected season detail

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (widget.offlineMode) {
        // Offline Mode
        if (_mediaDetail == null) {
          final detail = await ref.read(
            offlineMediaDetailProvider(id: widget.itemId).future,
          );
          _mediaDetail = detail;
        }

        if (_mediaDetail!.type == 'show' || widget.type == 'show') {
          final seasons = await ref.read(
            offlineAvailableSeasonsProvider(id: widget.itemId).future,
          );
          _discoverySeasons = seasons;

          // Load all season details
          final details = <SeasonDetail>[];
          for (final season in seasons) {
            final sDetail = await ref.read(
              offlineSeasonEpisodesProvider(
                id: widget.itemId,
                seasonNum: season.seasonNumber,
              ).future,
            );
            details.add(sDetail);
          }
          _seasonsDetail = details;
        }
      } else {
        // Online Mode
        final repo = ref.read(discoveryRepositoryProvider);
        if (_mediaDetail == null) {
          final detail = await repo.getDetails(
            widget.itemId,
            type: widget.type ?? 'movie',
          );
          _mediaDetail = detail;
        }

        if (_mediaDetail!.type == 'show' || widget.type == 'show') {
          // Fetch Seasons
          if (_discoverySeasons == null) {
            final seasons = await repo.getShowSeasons(widget.itemId);
            _discoverySeasons = seasons;
          }

          // Fetch ALL Season Details
          if (_seasonsDetail == null) {
            final details = await Future.wait(
              _discoverySeasons!.map(
                (s) => repo.getSeasonDetails(widget.itemId, s.seasonNumber),
              ),
            );
            _seasonsDetail = details;
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null || _mediaDetail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Text('Error loading data: ${_errorMessage ?? "Unknown"}'),
        ),
      );
    }

    final detail = _mediaDetail!;

    String? effectiveHistoryId;
    if (widget.itemId.startsWith('tt')) {
      effectiveHistoryId = widget.itemId;
    } else if (detail.imdbId != null) {
      effectiveHistoryId = detail.imdbId;
    }

    final historyAsync = (effectiveHistoryId != null)
        ? (widget.offlineMode
              ? ref.watch(offlineMediaHistoryProvider(id: widget.itemId))
              : ref.watch(mediaHistoryProvider(externalId: effectiveHistoryId)))
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
        body: Builder(
          builder: (context) {
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
        ),
      ),
    );
  }

  void _invalidateHistory(String mediaId, String type) {
    if (widget.offlineMode) {
      ref.invalidate(offlineMediaDetailProvider(id: mediaId));
      ref.invalidate(offlineMediaHistoryProvider(id: mediaId));
    } else {
      ref.invalidate(mediaDetailProvider(id: mediaId, type: type));
      ref.invalidate(mediaHistoryProvider(externalId: mediaId));
    }
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
        _invalidateHistory(mediaId, type);
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
        title: seasonNumber != null
            ? 'S${seasonNumber}E$episodeNumber - $title'
            : title,
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
      _invalidateHistory(mediaId, type);
    }
  }

  Future<void> _markAsWatched({
    required String mediaId,
    required String type,
    int? season,
    int? episode,
    required bool isWatched,
  }) async {
    final progress = {
      'external_id': mediaId,
      'imdb_id': mediaId,
      'type': type,
      'is_watched': isWatched,
      'season': season,
      'episode': episode,
      'position_ticks': 0, // Reset position when marking as watched/unwatched
      'duration_ticks': 0,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    try {
      if (widget.offlineMode) {
        await ref
            .read(offlineHistoryServiceProvider)
            .saveOfflineProgress(mediaId, progress);
      } else {
        await ref.read(discoveryRepositoryProvider).updateProgress([progress]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update history: $e')));
      }
    }

    _invalidateHistory(mediaId, type);
  }

  Future<void> _markSeasonAsWatched(
    SeasonDetail seasonDetail,
    String mediaId,
  ) async {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      const SnackBar(content: Text('Marking season as watched...')),
    );

    try {
      final List<Map<String, dynamic>> batchProgress = [];
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      for (final episode in seasonDetail.episodes) {
        batchProgress.add({
          'external_id': mediaId,
          'imdb_id': mediaId,
          'type': 'show',
          'is_watched': true,
          'season': seasonDetail.seasonNumber,
          'episode': episode.episodeNumber,
          'position_ticks': 0,
          'duration_ticks': 0, // Assume completed
          'timestamp': timestamp,
        });
      }

      if (widget.offlineMode) {
        for (final p in batchProgress) {
          await ref
              .read(offlineHistoryServiceProvider)
              .saveOfflineProgress(mediaId, p);
        }
      } else {
        await ref
            .read(discoveryRepositoryProvider)
            .updateProgress(batchProgress);
      }
    } catch (e) {
      if (mounted) {
        scaffold.hideCurrentSnackBar();
        scaffold.showSnackBar(
          SnackBar(content: Text('Failed to mark season: $e')),
        );
      }
    }

    _invalidateHistory(mediaId, 'show');

    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      const SnackBar(content: Text('Season marked as watched')),
    );
  }

  Future<void> _markSeasonAsUnwatched(
    SeasonDetail seasonDetail,
    String mediaId,
  ) async {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      const SnackBar(content: Text('Marking season as watched...')),
    );

    try {
      final List<Map<String, dynamic>> batchProgress = [];
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      for (final episode in seasonDetail.episodes) {
        batchProgress.add({
          'external_id': mediaId,
          'imdb_id': mediaId,
          'type': 'show',
          'is_watched': false,
          'season': seasonDetail.seasonNumber,
          'episode': episode.episodeNumber,
          'position_ticks': 0,
          'duration_ticks': 0, // Assume completed
          'timestamp': timestamp,
        });
      }

      if (widget.offlineMode) {
        for (final p in batchProgress) {
          await ref
              .read(offlineHistoryServiceProvider)
              .saveOfflineProgress(mediaId, p);
        }
      } else {
        await ref
            .read(discoveryRepositoryProvider)
            .updateProgress(batchProgress);
      }
    } catch (e) {
      if (mounted) {
        scaffold.hideCurrentSnackBar();
        scaffold.showSnackBar(
          SnackBar(content: Text('Failed to mark season: $e')),
        );
      }
    }

    _invalidateHistory(mediaId, 'show');

    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      const SnackBar(content: Text('Season marked as watched')),
    );
  }

  String? _getSeasonPosterPath(int seasonNumber) {
    return _discoverySeasons!
        .where((s) => s.seasonNumber == seasonNumber)
        .firstOrNull
        ?.posterPath;
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
                  seasons: _discoverySeasons?.map((s) => s.toJson()).toList(),
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
        onStreamSelected: (url, _, _) {
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
                seasons: _discoverySeasons?.map((s) => s.toJson()).toList(),
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

        // Content
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 800;
              // clean up unused variable

              if (isMobile) {
                return SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: SizedBox(
                            width: 200,
                            child: PosterBanner(
                              posterUrl: detail.posterUrl,
                              offlineMode: widget.offlineMode,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          detail.title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  const BoxShadow(
                                    color: Colors.black,
                                    blurRadius: 20,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                        ),
                        const SizedBox(height: 8),
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
                            const SizedBox(width: 16),
                            if (!widget.offlineMode)
                              LibraryButton(
                                itemId: widget.itemId,
                                type: widget.type ?? 'movie',
                                offlineMode: widget.offlineMode,
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Actions
                        SizedBox(
                          height: 50,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
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
                              const SizedBox(width: 12),
                              if (!widget.offlineMode)
                                DownloadButton(
                                  mediaId: detail.id,
                                  imdbId: detail.imdbId,
                                  tooltip: 'Download Movie',
                                  onDownload: () {
                                    _movieDownloadSheet(context, ref, detail);
                                  },
                                ),
                              const SizedBox(width: 12),
                              DynamicWatchedButton(
                                detail: detail,
                                selectedSeason: null,
                                selectedEpisode: null,
                                markAsWatched: _markAsWatched,
                                offlineMode: widget.offlineMode,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          detail.overview ?? '',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                height: 1.4,
                                fontSize: 16,
                                shadows: [
                                  const BoxShadow(
                                    color: Colors.black,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                        ),
                        const SizedBox(height: 80), // Bottom padding
                      ],
                    ),
                  ),
                );
              }

              // Desktop Layout (Original)
              return Padding(
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
                                    const BoxShadow(
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
                                  border: Border.all(color: Colors.white70),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'MOVIE',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 16),
                              if (!widget.offlineMode)
                                LibraryButton(
                                  itemId: widget.itemId,
                                  type:
                                      widget.type ??
                                      'movie', // defaulting to type logic
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
                                    const BoxShadow(
                                      color: Colors.black,
                                      blurRadius: 10,
                                    ),
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
                              // Download Button (Square)
                              if (!widget.offlineMode)
                                DownloadButton(
                                  mediaId: detail.id,
                                  imdbId: detail.imdbId,
                                  tooltip: 'Download Movie',
                                  onDownload: () {
                                    _movieDownloadSheet(context, ref, detail);
                                  },
                                ),

                              // Mark as Watched Button (Movie)
                              DynamicWatchedButton(
                                detail: detail,
                                selectedSeason: null,
                                selectedEpisode: null,
                                markAsWatched: _markAsWatched,
                                offlineMode: widget.offlineMode,
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
              );
            },
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
    // 1. Fetch Episodes from CACHE
    final seasonDetail = _seasonsDetail?.firstWhereOrNull(
      (s) => s.seasonNumber == _selectedSeason!.seasonNumber,
    );

    if (seasonDetail == null) {
      return const Center(child: Text('Season details not found'));
    }

    // Update current season detail pointer
    _seasonDetail = seasonDetail;

    final episodes = seasonDetail.episodes;

    // Find Season Poster from CACHE
    final seasonPoster = _discoverySeasons
        ?.firstWhereOrNull(
          (s) => s.seasonNumber == _selectedSeason!.seasonNumber,
        )
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 800;

              if (isMobile) {
                return SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: SizedBox(
                            width: 150,
                            child: PosterBanner(
                              posterUrl: posterUrlToUse,
                              offlineMode: widget.offlineMode,
                              placeholderIcon: Icons.tv,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Title Group
                        Text(
                          detail.title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Season ${_selectedSeason?.seasonNumber}'
                          '${seasonDetail.name.isNotEmpty && seasonDetail.name != "Season ${_selectedSeason?.seasonNumber}" ? " - ${seasonDetail.name}" : ""}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                        const SizedBox(height: 24),
                        // Actions
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ActionScale(
                              builder: (context, node) {
                                return FilledButton.icon(
                                  focusNode: node,
                                  onPressed: () {
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

                            MarkAsWatchedButton(
                              onPressed: () {
                                _markSeasonAsWatched(
                                  seasonDetail,
                                  detail.imdbId ?? detail.id,
                                );
                              },
                              tooltip: 'Mark Season Watched',
                            ),

                            MarkAsUnwatchedButton(
                              onPressed: () {
                                _markSeasonAsUnwatched(
                                  seasonDetail,
                                  detail.imdbId ?? detail.id,
                                );
                              },
                              tooltip: 'Mark Season Unwatched',
                            ),
                          ],
                        ),

                        const Divider(height: 32),

                        // Episode List (ShrinkWrap)
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: episodes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final episode = episodes[index];
                            final historyItem = historyAsync.value
                                ?.firstWhereOrNull(
                                  (h) =>
                                      (h.mediaId == detail.id ||
                                          h.mediaId == detail.imdbId) &&
                                      h.seasonNumber ==
                                          _selectedSeason?.seasonNumber &&
                                      h.episodeNumber == episode.episodeNumber,
                                );

                            return EpisodeCard(
                              episode: episode,
                              history: historyItem,
                              mediaId: detail.id,
                              imdbId: detail.imdbId,
                              season: _selectedSeason!.seasonNumber,
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
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                );
              }

              // Desktop Layout
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
                          PosterBanner(
                            posterUrl: posterUrlToUse,
                            offlineMode: widget.offlineMode,
                            placeholderIcon: Icons.tv,
                          ),
                          const SizedBox(height: 24),
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

                              const SizedBox(width: 16),

                              MarkAsWatchedButton(
                                onPressed: () {
                                  _markSeasonAsWatched(
                                    seasonDetail,
                                    detail.imdbId ?? detail.id,
                                  );
                                },
                                tooltip: 'Mark Season Watched',
                              ),

                              MarkAsUnwatchedButton(
                                onPressed: () {
                                  _markSeasonAsUnwatched(
                                    seasonDetail,
                                    detail.imdbId ?? detail.id,
                                  );
                                },
                                tooltip: 'Mark Season Unwatched',
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
                                      'Season ${_selectedSeason?.seasonNumber}'
                                      '${seasonDetail.name.isNotEmpty && seasonDetail.name != "Season ${_selectedSeason?.seasonNumber}" ? " - ${seasonDetail.name}" : ""}',
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
                                          h.seasonNumber ==
                                              _selectedSeason?.seasonNumber &&
                                          h.episodeNumber ==
                                              episode.episodeNumber,
                                    );

                                return EpisodeCard(
                                  episode: episode,
                                  history: historyItem,
                                  mediaId: detail.id,
                                  imdbId: detail.imdbId,
                                  season: _selectedSeason!.seasonNumber,
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
              );
            },
          ),
        ),
      ],
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

    // Resolving Season Poster from CACHE
    final seasonPoster = _discoverySeasons
        ?.firstWhereOrNull(
          (s) => s.seasonNumber == _selectedSeason!.seasonNumber,
        )
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 800;

              if (isMobile) {
                return SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (episode.stillPath != null)
                          AspectRatio(
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
                                            width: double.infinity,
                                          ),
                                    if (historyAsync.value
                                            ?.firstWhereOrNull(
                                              (h) =>
                                                  h.seasonNumber ==
                                                      _selectedSeason
                                                          ?.seasonNumber &&
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
                        const SizedBox(height: 24),
                        Text(
                          '${detail.title} • S${_selectedSeason?.seasonNumber} E${episode.episodeNumber}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
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
                        ),
                        const SizedBox(height: 16),
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Actions
                        SizedBox(
                          height: 50,
                          child: Row(
                            children: [
                              Expanded(
                                child: ConnectedPlayButton(
                                  externalId: detail.imdbId!,
                                  type: detail.type,
                                  seasonNumber: _selectedSeason!.seasonNumber,
                                  episodeNumber: episode.episodeNumber,
                                  offlineMode: widget.offlineMode,
                                  onPressed: (int? startPos) async {
                                    _playEpisode(
                                      startPos,
                                      detail.imdbId!,
                                      _selectedSeason!.seasonNumber,
                                      episode.episodeNumber,
                                      episode.name,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (!widget.offlineMode)
                                DownloadButton(
                                  mediaId: detail.id,
                                  imdbId: detail.imdbId,
                                  season: _selectedSeason!.seasonNumber,
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
                              const SizedBox(width: 12),
                              DynamicWatchedButton(
                                detail: detail,
                                selectedSeason: _selectedSeason,
                                selectedEpisode: episode,
                                markAsWatched: _markAsWatched,
                                offlineMode: widget.offlineMode,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          episode.overview ??
                              'No description available for this episode.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                height: 1.4,
                                shadows: [
                                  BoxShadow(
                                    color: Colors.black,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                );
              }

              // Desktop Layout
              return Padding(
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
                        // placeholderIcon: Icons.tv, // PosterBanner doesn't take placeholderIcon?
                        // Actually the original code passed placeholderIcon: Icons.tv
                        // BUT PosterBanner definition check...
                        // It seems I might have assumed PosterBanner signature.
                        // Let's keep it as is from original code.
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
                            '${detail.title} • S${_selectedSeason?.seasonNumber} E${episode.episodeNumber}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
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
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            episode.overview ??
                                'No description available for this episode.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  height: 1.4,
                                  shadows: [
                                    BoxShadow(
                                      color: Colors.black,
                                      blurRadius: 10,
                                    ),
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
                                                      child: const Icon(
                                                        Icons.tv,
                                                      ),
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
                                                          _selectedSeason
                                                              ?.seasonNumber &&
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
                                  season: _selectedSeason!.seasonNumber,
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

                              // Mark as Watched Button (Episode)
                              DynamicWatchedButton(
                                detail: detail,
                                selectedSeason: _selectedSeason,
                                selectedEpisode: episode,
                                markAsWatched: _markAsWatched,
                                offlineMode: widget.offlineMode,
                              ),

                              // Play Button with Progress Overlay
                              Expanded(
                                child: ConnectedPlayButton(
                                  externalId: detail.imdbId!,
                                  type: detail.type,
                                  seasonNumber: _selectedSeason!.seasonNumber,
                                  episodeNumber: episode.episodeNumber,
                                  offlineMode: widget.offlineMode,
                                  onPressed: (int? startPos) async {
                                    _playEpisode(
                                      startPos,
                                      detail.imdbId!,
                                      _selectedSeason!.seasonNumber,
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
              );
            },
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 800;

              if (isMobile) {
                return SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: SizedBox(
                            width: 200,
                            child: PosterBanner(
                              posterUrl: detail.posterUrl,
                              offlineMode: widget.offlineMode,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          detail.title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  const BoxShadow(
                                    color: Colors.black,
                                    blurRadius: 20,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                        ),
                        const SizedBox(height: 8),
                        // Metadata Row
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
                                'SHOW',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
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
                        // Overview
                        Text(
                          detail.overview ?? '',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                height: 1.4,
                                fontSize: 16,
                                shadows: [
                                  const BoxShadow(
                                    color: Colors.black,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                        ),
                        const SizedBox(height: 24),
                        // Season List
                        SizedBox(
                          height: 250,
                          child: SeasonList(
                            itemId: widget.itemId,
                            offlineMode: widget.offlineMode,
                            selectedSeason: _selectedSeason?.seasonNumber,
                            showPosterPath: detail.posterUrl,
                            leading: ContinueWatchingCard(
                              detail: detail,
                              historyAsync: historyAsync,
                              onResume: _playEpisode,
                              offlineMode: widget.offlineMode,
                              seasonsDetail: _seasonsDetail!,
                            ),
                            onSeasonSelected: (season) {
                              setState(() {
                                _selectedSeason = season;
                                _viewMode = ShowViewMode.season;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                );
              }

              // Desktop Layout
              return Padding(
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
                                              const BoxShadow(
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
                                            detail.releaseDate!
                                                .split('-')
                                                .first,
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
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            height: 1.4,
                                            fontSize: 16,
                                            shadows: [
                                              const BoxShadow(
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
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => const SizedBox.shrink(),
                                            )
                                          : Image.network(
                                              detail.logo!.startsWith('/') ||
                                                      detail.logo!.startsWith(
                                                        'http',
                                                      )
                                                  ? (detail.logo!.startsWith(
                                                          '/',
                                                        )
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
                            children: [
                              Expanded(child: const SizedBox(height: 32)),
                            ],
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
                                    selectedSeason:
                                        _selectedSeason?.seasonNumber,
                                    showPosterPath: detail.posterUrl,
                                    leading: ContinueWatchingCard(
                                      detail: detail,
                                      historyAsync: historyAsync,
                                      onResume: _playEpisode,
                                      offlineMode: widget.offlineMode,
                                      seasonsDetail: _seasonsDetail!,
                                    ),
                                    onSeasonSelected: (season) {
                                      setState(() {
                                        _selectedSeason = season;
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
              );
            },
          ),
        ),
      ],
    );
  }
}
