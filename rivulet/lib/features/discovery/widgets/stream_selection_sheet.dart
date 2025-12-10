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
                  return ListView.separated(
                    itemCount: streams.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final stream = streams[index];
                      return ListTile(
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
                            Text(stream.source),
                          ],
                        ),
                        onTap: () => _handleStreamSelection(
                          stream.magnet,
                          stream.fileIndex,
                        ),
                      );
                    },
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
