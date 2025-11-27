import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rivulet/api/real_debrid_client.dart';
import 'package:rivulet/features/search/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rivulet Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _tokenController,
                  decoration: const InputDecoration(
                    hintText: 'Enter Real Debrid API Token',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Enter IMDB ID (e.g. tt1375666)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        if (_controller.text.isNotEmpty) {
                          ref
                              .read(searchResultsProvider.notifier)
                              .search(_controller.text);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: searchState.when(
              data: (streams) {
                if (streams.isEmpty) {
                  return const Center(child: Text('No streams found'));
                }
                return ListView.builder(
                  itemCount: streams.length,
                  itemBuilder: (context, index) {
                    final stream = streams[index];
                    return ListTile(
                      title: Text(stream.title ?? 'Unknown Title'),
                      subtitle: Text('${stream.quality} • ${stream.name}'),
                      onTap: () async {
                        if (_tokenController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter RD Token'),
                            ),
                          );
                          return;
                        }

                        final rdClient = ref.read(realDebridClientProvider);
                        rdClient.setToken(_tokenController.text.trim());

                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Adding magnet to Real Debrid...'),
                            ),
                          );

                          // 1. Add Magnet
                          // Note: Torrentio usually provides infoHash.
                          if (stream.infoHash == null) {
                            throw Exception('No infoHash');
                          }

                          final magnet =
                              'magnet:?xt=urn:btih:${stream.infoHash}';
                          final torrentId = await rdClient.addMagnet(magnet);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Checking torrent status...'),
                            ),
                          );

                          // 2. Get Info & Select Files
                          var info = await rdClient.getTorrentInfo(torrentId);

                          if (info['status'] == 'waiting_files_selection') {
                            // Select all files (or just the biggest one? For now, 'all')
                            await rdClient.selectFiles(torrentId, 'all');
                            // Refresh info
                            info = await rdClient.getTorrentInfo(torrentId);
                          }

                          if (info['status'] == 'downloaded') {
                            // 3. Unrestrict
                            final links = info['links'] as List;
                            if (links.isEmpty)
                              throw Exception('No links found');

                            // Just take the first link for now
                            final link = links.first as String;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Resolving link...'),
                              ),
                            );

                            final downloadUrl = await rdClient.unrestrictLink(
                              link,
                            );

                            if (downloadUrl != null) {
                              // 4. Play
                              if (context.mounted) {
                                Navigator.of(
                                  context,
                                ).pushNamed('/player', arguments: downloadUrl);
                              }
                            } else {
                              throw Exception('Failed to resolve link');
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Torrent not cached. Status: ${info['status']}',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
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
