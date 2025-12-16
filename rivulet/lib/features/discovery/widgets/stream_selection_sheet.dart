import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../player/player_screen.dart';
import '../discovery_provider.dart';
import '../repository/discovery_repository.dart';

class StreamSelectionSheet extends ConsumerStatefulWidget {
  final String externalId;
  final String title; // For header
  final String type;
  final int? season;
  final int? episode;

  const StreamSelectionSheet({
    super.key,
    required this.externalId,
    required this.title,
    required this.type,
    this.season,
    this.episode,
  });

  @override
  ConsumerState<StreamSelectionSheet> createState() =>
      _StreamSelectionSheetState();
}

class _StreamSelectionSheetState extends ConsumerState<StreamSelectionSheet> {
  bool _isResolving = false;
  Set<String> _favoriteHashes = {};
  bool _favoritesLoaded = false;

  @override
  void initState() {
    super.initState();
  }

  void _checkFavorites(List<dynamic> streams) async {
    if (_favoritesLoaded || streams.isEmpty) return;

    // Extract hash from magnet link (cached or parse?)
    // StreamResult likely has magnet. Extract InfoHash?
    // Backend expects 'Hash'.
    // Assuming backend AddFavorite uses the same hash string as we send here.
    // We should parse magnet to get hash? Or just send magnet?
    // User request: "hash of the torrent stream".
    // Magnets usually contain xt=urn:btih:<HASH>.
    // Let's assume we extract it. Or simpler, store the whole magnet if needed, but hash is better.
    // For now, let's use the full magnet link string or a simple hash extractor if available.
    // But StreamResult struct in existing code? Let's check previously viewed code.
    // Step 507 view: `stream.magnet` is String.
    // Let's use a helper to extract hash or just use magnet string as ID if unique.
    // Better to use hash.

    // Quick hash extraction regex failure fallback to full string?
    // Let's implement a simple extractor or assume repo handles it.
    // For now, I will use "magnet" string as "hash" key for simplicity unless I see a helper.
    // Actually, `checkFavoriteStreams` in repo takes `List<String> hashes`.

    try {
      final realHashes = streams.map((s) => _extractHash(s.magnet)).toList();
      final favorites = await ref
          .read(discoveryRepositoryProvider)
          .checkFavoriteStreams(widget.externalId, realHashes);

      if (mounted) {
        setState(() {
          _favoriteHashes = favorites.toSet();
          _favoritesLoaded = true;
        });
      }
    } catch (_) {
      // Silent fail
    }
  }

  String _extractHash(String magnet) {
    final uri = Uri.tryParse(magnet);
    if (uri == null) return magnet;

    // specific to magnet:?xt=urn:btih:HASH
    // simple regex
    final regExp = RegExp(r'xt=urn:btih:([a-zA-Z0-9]+)');
    final match = regExp.firstMatch(magnet);
    if (match != null) return match.group(1) ?? magnet;
    return magnet;
  }

  Future<void> _toggleFavorite(String magnet) async {
    final hash = _extractHash(magnet);
    final isFav = _favoriteHashes.contains(hash);

    // Optimistic update
    setState(() {
      if (isFav) {
        _favoriteHashes.remove(hash);
      } else {
        _favoriteHashes.add(hash);
      }
    });

    try {
      if (isFav) {
        await ref
            .read(discoveryRepositoryProvider)
            .removeFavoriteStream(widget.externalId, hash);
      } else {
        await ref
            .read(discoveryRepositoryProvider)
            .addFavoriteStream(widget.externalId, hash);
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          if (isFav)
            _favoriteHashes.add(hash);
          else
            _favoriteHashes.remove(hash);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favorite: $e')),
        );
      }
    }
  }

  Future<void> _handleStreamSelection(String magnet, int? fileIndex) async {
    setState(() {
      _isResolving = true;
    });

    try {
      final repo = ref.read(discoveryRepositoryProvider);
      final result = await repo.resolveStream(
        magnet: magnet,
        season: widget.season,
        episode: widget.episode,
        fileIndex: fileIndex,
      );

      if (!mounted) return;

      final url = result['url'] as String?;
      if (url != null) {
        // Close sheet and open player
        Navigator.pop(context); // Close sheet
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PlayerScreen(url: url)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resolve stream: ${result['status']}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final streamAsync = ref.watch(
      streamScraperProvider(
        externalId: widget.externalId,
        type: widget.type,
        season: widget.season,
        episode: widget.episode,
      ),
    );

    // Trigger favorites check when data arrives
    ref.listen(
      streamScraperProvider(
        externalId: widget.externalId,
        type: widget.type,
        season: widget.season,
        episode: widget.episode,
      ),
      (prev, next) {
        if (next.hasValue && !_favoritesLoaded) {
          _checkFavorites(next.value!);
        }
      },
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Streams for ${widget.title}',
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          if (_isResolving)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Resolving stream...'),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: streamAsync.when(
                data: (streams) {
                  if (streams.isEmpty) {
                    return const Center(child: Text('No streams found.'));
                  }

                  // Sort/Filter
                  final favStreams = <dynamic>[];
                  final otherStreams = <dynamic>[];

                  for (var s in streams) {
                    final h = _extractHash(s.magnet);
                    if (_favoriteHashes.contains(h)) {
                      favStreams.add(s);
                    } else {
                      otherStreams.add(s);
                    }
                  }

                  // Helper to build tile
                  Widget buildStreamTile(dynamic stream, bool isFav) {
                    return ListTile(
                      leading: IconButton(
                        icon: Icon(
                          isFav ? Icons.star : Icons.star_border,
                          color: isFav ? Colors.amber : null,
                        ),
                        onPressed: () => _toggleFavorite(stream.magnet),
                      ),
                      title: Text(stream.title),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              stream.quality,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(stream.formattedSize),
                          const SizedBox(width: 8),
                          const Icon(Icons.people, size: 16),
                          const SizedBox(width: 4),
                          Text('${stream.seeds}'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              stream.source,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _handleStreamSelection(
                        stream.magnet,
                        stream.fileIndex,
                      ),
                    );
                  }

                  return ListView(
                    children: [
                      if (favStreams.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            "Favorites",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...favStreams.map((s) => buildStreamTile(s, true)),
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            "All Streams",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      ...otherStreams.map((s) => buildStreamTile(s, false)),
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
}
