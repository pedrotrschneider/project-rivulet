import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rivulet/features/discovery/discovery_provider.dart';
import 'package:rivulet/features/discovery/repository/discovery_repository.dart';

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

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      mediaDetailProvider(id: widget.itemId, type: widget.type),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add to Library',
            onPressed: () async {
              try {
                // Optimistic UI updates could be added here later
                await ref
                    .read(discoveryRepositoryProvider)
                    .addToLibrary(widget.itemId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to Library')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
                }
              }
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
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
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
                                      title: Text(
                                        '${episode.episodeNumber}. ${episode.name}',
                                      ),
                                      subtitle: Text(
                                        episode.overview ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
    );
  }
}
