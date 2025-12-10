import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart' as fvp;

class PlayerScreen extends StatefulWidget {
  final String url;
  const PlayerScreen({super.key, required this.url});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String _title = 'Loading...';

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    fvp.registerWith(
      options: {
        'global': {'log': 'off'},
      },
    );

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));

    try {
      await _controller.initialize();
      String newTitle = "Unknown Video";
      final info = _controller.getMediaInfo();
      if (info != null) {
        // media.metadata is a Map<String, String> of tags
        final tags = info.metadata;
        print(info);
        if (tags.containsKey('title')) {
          newTitle = tags['title']!;
        } else {
          // 2. Fallback: Extract filename from URL
          final uri = Uri.parse(widget.url);
          // Get the last segment (e.g. "movie.mkv") and remove URI encoding (%20)
          String filename = uri.pathSegments.last;
          filename = Uri.decodeComponent(filename);
          newTitle = filename;
        }
      }
      setState(() {
        _isInitialized = true;
        _title = newTitle;
      });
      _controller.play();
    } catch (e) {
      print("Error initializing: $e");
    }
  }

  void _showTrackSelector(BuildContext context, String type) {
    final info = _controller.getMediaInfo();

    if (info == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No media info available")));
      return;
    }

    // Extract tracks based on type
    final tracks = type == 'audio' ? info.audio : info.subtitle;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Select $type",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            // Option to disable subtitles
            if (type == 'subtitle')
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text("Off"),
                onTap: () {
                  // Fladder Logic: Pass [-1] to disable
                  _controller.setSubtitleTracks([-1]);
                  Navigator.pop(ctx);
                },
              ),

            // List Tracks
            if (tracks != null)
              ...tracks.asMap().entries.map((entry) {
                final index = entry.key;
                final track = entry.value;

                // Build label like Fladder: "Language (Codec)"
                String label = "Track ${index + 1}";
                final lang = track.metadata['language'];
                final codec = track.metadata['codec'];

                if (lang != null) label += " - $lang";
                if (codec != null) label += " ($codec)";

                return ListTile(
                  leading: Icon(
                    type == 'audio' ? Icons.audiotrack : Icons.subtitles,
                  ),
                  title: Text(label),
                  onTap: () {
                    // 5. Use the set methods from FVP extensions
                    if (type == 'audio') {
                      _controller.setAudioTracks([index]);
                    } else {
                      _controller.setSubtitleTracks([index]);
                    }
                    Navigator.pop(ctx);
                  },
                );
              }),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.audiotrack),
            onPressed: () => _showTrackSelector(context, 'audio'),
          ),
          IconButton(
            icon: const Icon(Icons.subtitles),
            onPressed: () => _showTrackSelector(context, 'subtitle'),
          ),
        ],
      ),
      body: Center(
        child: _isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          });
        },
        child: Icon(
          _isInitialized && _controller.value.isPlaying
              ? Icons.pause
              : Icons.play_arrow,
        ),
      ),
    );
  }
}
