import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rivulet/features/discovery/discovery_provider.dart';
import 'package:rivulet/features/discovery/repository/discovery_repository.dart';
import 'package:rivulet/features/discovery/domain/discovery_models.dart';
import 'package:rivulet/features/auth/auth_provider.dart';
import 'package:rivulet/features/discovery/screens/media_detail_screen.dart';

import '../discovery/widgets/stream_selection_sheet.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Refresh history when screen is mounted (e.g. tab switch)
    Future.microtask(() => ref.invalidate(historyProvider));
  }

  void _performSearch() {
    if (_controller.text.isNotEmpty) {
      ref.read(discoverySearchProvider.notifier).search(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(discoverySearchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Search movies & shows...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _performSearch,
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                // 1. History Section (Always Visible)
                const _HistorySection(),

                // 2. Search Results
                ...searchState.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return [
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              'Search for something to start watching',
                            ),
                          ),
                        ),
                      ];
                    }

                    final movies = items
                        .where((i) => i.type == 'movie')
                        .toList();
                    final shows = items
                        .where((i) => i.type != 'movie')
                        .toList();

                    return [
                      if (movies.isNotEmpty) ...[
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                            child: Text(
                              'Movies',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        _buildGrid(movies),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                      if (shows.isNotEmpty) ...[
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Text(
                              'TV Shows',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        _buildGrid(shows),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ];
                  },
                  error: (err, stack) => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('Error: $err')),
                    ),
                  ],
                  loading: () => [
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<dynamic> items) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150,
          childAspectRatio: 2 / 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = items[index];

          // Handle relative TMDB paths
          String? imageUrl = item.posterUrl;
          if (imageUrl != null && imageUrl.startsWith('/')) {
            imageUrl = 'https://image.tmdb.org/t/p/w500$imageUrl';
          }

          return InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      MediaDetailScreen(itemId: item.id, type: item.type),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[800],
                            child: const Icon(Icons.movie, size: 48),
                          ),
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.movie, size: 48),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (item.year != null)
                  Text(
                    item.year!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          );
        }, childCount: items.length),
      ),
    );
  }
}

class _HistorySection extends ConsumerWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return historyAsync.when(
      data: (history) {
        if (history.isEmpty)
          return const SliverToBoxAdapter(child: SizedBox.shrink());

        final continueWatching = history;

        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (continueWatching.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Continue Watching',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: continueWatching.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = continueWatching[index];
                      return _HistoryCard(item: item);
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
      error: (e, s) =>
          SliverToBoxAdapter(child: Text('Error loading history: $e')),
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  final HistoryItem item;

  const _HistoryCard({required this.item});

  void _openStreamSelection(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StreamSelectionSheet(
        externalId: item.mediaId,
        title:
            item.seriesName ?? ((item.type == 'movie') ? 'Movie' : 'Episode'),
        type: item.type == 'episode' ? 'show' : 'movie',
        season: item.nextSeason ?? item.seasonNumber,
        episode: item.nextEpisode ?? item.episodeNumber,
        startPosition: item.positionTicks,
        nextSeason: item.nextSeason,
        nextEpisode: item.nextEpisode,
      ),
    ).then((_) {
      if (context.mounted) {
        ref.invalidate(historyProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Safer image URL construction
    final serverUrl = '${ref.watch(serverUrlProvider) ?? ''}/api/v1';
    String imageUrl = '';

    // Helper to join URL parts cleanly
    String joinUrl(String base, String path) {
      if (base.isEmpty) return path;
      if (base.endsWith('/') && path.startsWith('/')) {
        return '$base${path.substring(1)}';
      }
      if (!base.endsWith('/') && !path.startsWith('/')) {
        return '$base/$path';
      }
      return '$base$path';
    }

    if (item.backdropPath.isNotEmpty) {
      imageUrl = item.backdropPath.startsWith('/')
          ? joinUrl(serverUrl, item.backdropPath)
          : item.backdropPath;
    } else if (item.posterPath.isNotEmpty) {
      imageUrl = item.posterPath.startsWith('/')
          ? joinUrl(serverUrl, item.posterPath)
          : item.posterPath;
    }

    return SizedBox(
      width: 280,
      child: InkWell(
        onTap: () {
          // Always try to open stream selection for "continue watching" items
          _openStreamSelection(context, ref);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white),
                    ),
                  ),
                  if (!item.isWatched)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(8),
                        ),
                        child: LinearProgressIndicator(
                          value: item.durationTicks > 0
                              ? item.positionTicks / item.durationTicks
                              : 0,
                          color: Colors.deepPurple,
                          backgroundColor: Colors.black26,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.seriesName != null ? '${item.seriesName}' : item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (item.seasonNumber != null)
              Text(
                item.isWatched
                    ? 'S${item.nextSeason} E${item.nextEpisode}'
                    : 'S${item.seasonNumber} E${item.episodeNumber}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (item.seasonNumber != null)
              Text(
                item.isWatched && item.nextEpisodeTitle != null
                    ? item.nextEpisodeTitle!
                    : item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

final historyProvider = FutureProvider<List<HistoryItem>>((ref) async {
  final repo = ref.watch(discoveryRepositoryProvider);
  return repo.getHistory();
});
