import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'library_provider.dart';
import '../discovery/domain/discovery_models.dart';
import '../discovery/screens/media_detail_screen.dart';
import '../auth/auth_provider.dart';

/// Library screen displaying the user's saved media collection.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryProvider);
    final serverUrl = ref.watch(serverUrlProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(libraryProvider.notifier).refresh(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: libraryAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.movie_filter_outlined,
                      size: 64,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your library is empty',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add movies and shows from the Discover tab',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                childAspectRatio: 2 / 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _LibraryItemCard(item: item, serverUrl: serverUrl);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Failed to load library',
                  style: TextStyle(color: Colors.red.shade300),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.read(libraryProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryItemCard extends StatelessWidget {
  final DiscoveryItem item;
  final String? serverUrl;

  const _LibraryItemCard({required this.item, this.serverUrl});

  @override
  Widget build(BuildContext context) {
    String? imageUrl = item.posterUrl;

    // Construct full URL for local images
    if (imageUrl != null && imageUrl.startsWith('/') && serverUrl != null) {
      // imageUrl is like "/images/foo.jpg"
      // we need "http://host:8080/api/v1/images/foo.jpg"
      // serverUrl is "http://host:8080" (or with /api/v1 depending on config, usually base host)
      // Check auth_provider for how serverUrl is stored. Usually "http://ip:port".
      // Dio provider appends /api/v1.
      // So we should append /api/v1 if not present.

      String base = serverUrl!;
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);

      imageUrl = '$base/api/v1$imageUrl';
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Row(
            children: [
              Icon(
                item.type == 'movie' ? Icons.movie : Icons.tv,
                size: 14,
                color: Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                item.type == 'movie' ? 'Movie' : 'Series',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(Icons.movie, size: 48),
    );
  }
}
