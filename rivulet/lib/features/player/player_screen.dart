import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:rivulet/features/discovery/repository/discovery_repository.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String url;
  final String? externalId;
  final String? type;
  final int? season;
  final int? episode;
  final int startPosition; // Ticks (microseconds * 10)
  final int? nextSeason;
  final int? nextEpisode;

  const PlayerScreen({
    super.key,
    required this.url,
    this.externalId,
    this.type,
    this.season,
    this.episode,
    this.startPosition = 0,
    this.nextSeason,
    this.nextEpisode,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String _title = 'Loading...';
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      try {
        fvp.registerWith(
          options: {
            'global': {'log': 'off'},
          },
        );
      } catch (_) {}

      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _controller.initialize();

      // Resume logic
      if (widget.startPosition > 0) {
        final position = Duration(microseconds: widget.startPosition ~/ 10);
        await _controller.seekTo(position);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Resumed from ${_formatDuration(position)}"),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      String newTitle = "Unknown Video";
      final info = _controller.getMediaInfo();
      if (info != null) {
        final tags = info.metadata;
        if (tags.containsKey('title')) {
          newTitle = tags['title']!;
        } else {
          final uri = Uri.parse(widget.url);
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
      _startProgressTracking();
    } catch (e) {
      print("Error initializing: $e");
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return "$hours:${twoDigits(minutes)}:${twoDigits(seconds)}";
    }
    return "$minutes:${twoDigits(seconds)}";
  }

  void _startProgressTracking() {
    // Sync every 15 seconds
    _progressTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _reportProgress();
    });
  }

  Future<void> _reportProgress() async {
    if (!_controller.value.isInitialized || widget.externalId == null) return;

    final position = _controller.value.position;
    final duration = _controller.value.duration;

    // Logic for "Is Watched" (e.g. > 90%)
    bool isWatched = false;
    if (duration.inSeconds > 0) {
      if (position.inSeconds / duration.inSeconds > 0.9) {
        isWatched = true;
      }
    }

    final Map<String, dynamic> progress = {
      'external_id': widget.externalId,
      'type': widget.type,
      'season': widget.season ?? 0,
      'episode': widget.episode ?? 0,
      'position_ticks': position.inMicroseconds * 10,
      'duration_ticks': duration.inMicroseconds * 10,
      'is_watched': isWatched,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      if (widget.nextSeason != null) 'next_season': widget.nextSeason,
      if (widget.nextEpisode != null) 'next_episode': widget.nextEpisode,
    };

    try {
      await ref.read(discoveryRepositoryProvider).updateProgress([progress]);
    } catch (e) {
      print('Failed to sync progress: $e');
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
            if (type == 'subtitle')
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text("Off"),
                onTap: () {
                  _controller.setSubtitleTracks([-1]);
                  Navigator.pop(ctx);
                },
              ),
            if (tracks != null)
              ...tracks.asMap().entries.map((entry) {
                final index = entry.key;
                final track = entry.value;
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
    _progressTimer?.cancel();
    _reportProgress(); // Last sync
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Pause and report progress before popping
        if (_isInitialized) {
          _controller.pause();
          await _reportProgress();
        }
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
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
              ? Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                    // Controls overlay
                    Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            colors: VideoProgressColors(
                              playedColor: Colors.deepPurple,
                              bufferedColor: Colors.deepPurple.shade100,
                              backgroundColor: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _controller.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _controller.value.isPlaying
                                        ? _controller.pause()
                                        : _controller.play();
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
