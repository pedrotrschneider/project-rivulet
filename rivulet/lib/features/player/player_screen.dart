import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:rivulet/features/discovery/repository/discovery_repository.dart';
import 'package:rivulet/features/discovery/discovery_provider.dart';
import 'package:rivulet/features/downloads/services/offline_history_service.dart';
import 'package:rivulet/features/downloads/providers/offline_providers.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String url;
  final String externalId;
  final String title;
  final String type;
  final int? season;
  final int? episode;
  final int startPosition; // Ticks (microseconds * 10)
  final String? imdbId;
  final bool offlineMode;

  const PlayerScreen({
    super.key,
    required this.url,
    required this.externalId,
    required this.title,
    required this.type,
    this.season,
    this.episode,
    this.startPosition = 0,
    this.imdbId,
    this.offlineMode = false,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String _title = 'Loading...';
  Timer? _progressTimer;

  // Track selection
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      // Register FVP for better playback support
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Resumed from ${_formatDuration(position)}"),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      String newTitle = widget.title;
      // Try to get title from metadata if available/generic
      // But widget.title is usually passed from discovery, so prefer that unless it's empty?
      // Keeping original behavior: explicit title passed in constructor is usually correct.

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _title = newTitle;
        });
      }

      _controller.play();
      _startProgressTracking();
      _startHideControlsTimer();
    } catch (e) {
      debugPrint("Error initializing: $e");
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
    _progressTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _reportProgress();
    });
  }

  Future<void> _reportProgress() async {
    if (!_controller.value.isInitialized) return;

    final position = _controller.value.position;
    final duration = _controller.value.duration;

    bool isWatched = false;
    if (duration.inSeconds > 0) {
      if (position.inSeconds / duration.inSeconds > 0.9) {
        isWatched = true;
      }
    }

    final Map<String, dynamic> progress = {
      'external_id': widget.externalId,
      'imdb_id': widget.imdbId,
      'type': widget.type,
      'season': widget.season ?? 0,
      'episode': widget.episode ?? 0,
      'position_ticks': position.inMicroseconds * 10,
      'duration_ticks': duration.inMicroseconds * 10,
      'is_watched': isWatched,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    try {
      if (widget.offlineMode) {
        // Offline save
        await ref
            .read(offlineHistoryServiceProvider)
            .saveOfflineProgress(widget.externalId, progress);
      } else {
        // Online sync
        await ref.read(discoveryRepositoryProvider).updateProgress([progress]);
      }
    } catch (e) {
      debugPrint('Failed to sync progress: $e');
    }

    if (widget.offlineMode) {
      ref.invalidate(offlineMediaHistoryProvider(id: widget.externalId));
    } else {
      ref.invalidate(mediaHistoryProvider(externalId: widget.externalId));
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
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
    _hideControlsTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: _isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(),
            ),
            if (_showControls && _isInitialized) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.black45,
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  BackButton(
                    color: Colors.white,
                    onPressed: () {
                      _reportProgress().then((_) => Navigator.pop(context));
                    },
                  ),
                  Expanded(
                    child: Text(
                      _title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.audiotrack, color: Colors.white),
                    onPressed: () => _showTrackSelector(context, 'audio'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.subtitles, color: Colors.white),
                    onPressed: () => _showTrackSelector(context, 'subtitle'),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Play/Pause
            IconButton(
              iconSize: 64,
              icon: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                  _startHideControlsTimer();
                });
              },
            ),
            const Spacer(),
            // Bottom Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    _formatDuration(_controller.value.position),
                    style: const TextStyle(color: Colors.white),
                  ),
                  Expanded(
                    child: VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: Theme.of(context).colorScheme.primary,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white10,
                      ),
                    ),
                  ),
                  Text(
                    _formatDuration(_controller.value.duration),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
