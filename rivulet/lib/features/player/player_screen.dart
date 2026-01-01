import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
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
  late VlcPlayerController _controller;
  bool _isInitialized = false;
  String _title = 'Loading...';
  Timer? _progressTimer;

  // Track selection
  bool _showControls = true;
  Timer? _hideControlsTimer;

  // Track info cache
  Map<int, String> _audioTracks = {};
  Map<int, String> _subtitleTracks = {};

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      // Note: flutter_vlc_player doesn't support httpHeaders in the same way as video_player
      // If authorization is needed, it might need to be passed in the URL or via VLC options if supported.
      // For now, proceeding without headers as per plan.

      _controller = VlcPlayerController.network(
        widget.url,
        hwAcc: HwAcc.full,
        autoPlay: true,
        options: VlcPlayerOptions(),
      );

      // Listen for initialization
      _controller.addListener(_onPlayerStateChange);

      // Resume logic will be handled after initialization is confirmed
      // requires checking controller.value.isInitialized in listener appromixately

      String newTitle = widget.title;
      if (mounted) {
        setState(() {
          _title = newTitle;
        });
      }

      _startProgressTracking();
      _startHideControlsTimer();
    } catch (e) {
      debugPrint("Error initializing: $e");
    }
  }

  void _onPlayerStateChange() async {
    if (_controller.value.isInitialized && !_isInitialized) {
      setState(() {
        _isInitialized = true;
      });

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

      // Initial track fetch
      _refreshTracks();
    }
  }

  Future<void> _refreshTracks() async {
    final audio = await _controller.getAudioTracks();
    final subs = await _controller.getSpuTracks();
    if (mounted) {
      setState(() {
        _audioTracks = audio;
        _subtitleTracks = subs;
      });
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

  void _showTrackSelector(BuildContext context, String type) async {
    // Refresh tracks before showing
    await _refreshTracks();

    if (!mounted) return;

    final tracks = type == 'audio' ? _audioTracks : _subtitleTracks;

    if (tracks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No tracks available")));
      return;
    }

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
            // For subtitles, allow turning off (usually id -1 or similar in some players,
            // but VLC usually treats key as ID. 'Disabled' is often a specific ID or handled by the lib)
            // flutter_vlc_player documentation says setSpuTrack(int)
            if (type ==
                'subtitle') // Optional "Off" button if needed, assuming -1 turns it off
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text("Off"),
                onTap: () {
                  _controller.setSpuTrack(-1);
                  Navigator.pop(ctx);
                },
              ),
            ...tracks.entries.map((entry) {
              final id = entry.key;
              final name = entry.value;

              return ListTile(
                leading: Icon(
                  type == 'audio' ? Icons.audiotrack : Icons.subtitles,
                ),
                title: Text(name),
                onTap: () {
                  if (type == 'audio') {
                    _controller.setAudioTrack(id);
                  } else {
                    _controller.setSpuTrack(id);
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
    _controller.removeListener(_onPlayerStateChange);
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
              child: VlcPlayer(
                controller: _controller,
                aspectRatio: _controller.value.aspectRatio > 0
                    ? _controller.value.aspectRatio
                    : 16 / 9,
                placeholder: const Center(child: CircularProgressIndicator()),
              ),
            ),
            if (_showControls && _isInitialized) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    // We used to use VideoProgressIndicator, but VlcPlayer doesn't work with it directly.
    // We need to build a custom slider or use standard Slider.

    final duration = _controller.value.duration;
    final position = _controller.value.position;
    final maxDuration = duration.inMilliseconds.toDouble();
    final currentPos = position.inMilliseconds.toDouble();

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
                if (_controller.value.isPlaying) {
                  _controller.pause();
                } else {
                  _controller.play();
                }
                setState(() {}); // Force update icon
                _startHideControlsTimer();
              },
            ),
            const Spacer(),
            // Bottom Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(color: Colors.white),
                  ),
                  Expanded(
                    child: Slider(
                      value: currentPos.clamp(
                        0.0,
                        maxDuration > 0 ? maxDuration : 0.0,
                      ),
                      min: 0.0,
                      max: maxDuration > 0 ? maxDuration : 1.0,
                      onChanged: (value) {
                        // Seek
                        _controller.seekTo(
                          Duration(milliseconds: value.toInt()),
                        );
                        _startHideControlsTimer();
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
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
