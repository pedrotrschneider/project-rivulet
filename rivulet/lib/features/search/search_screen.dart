import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rivulet/features/discovery/discovery_provider.dart';
import 'package:rivulet/features/auth/auth_provider.dart';
import 'package:rivulet/features/discovery/screens/media_detail_screen.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final TextEditingController _controller = TextEditingController();

  void _performSearch() {
    if (_controller.text.isNotEmpty) {
      ref.read(discoverySearchProvider.notifier).search(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(discoverySearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
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
            child: searchState.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Search for something to start watching'),
                  );
                }

                // Split into categories
                final movies = items.where((i) => i.type == 'movie').toList();
                final shows = items.where((i) => i.type != 'movie').toList();

                return CustomScrollView(
                  slivers: [
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
                  ],
                );
              },
              error: (err, stack) => Center(child: Text('Error: $err')),
              loading: () => const Center(child: CircularProgressIndicator()),
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
