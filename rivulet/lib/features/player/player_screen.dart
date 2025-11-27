import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerScreen extends StatefulWidget {
  final String url;

  const PlayerScreen({super.key, required this.url});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player;
  late final VideoController controller;

  @override
  void initState() {
    super.initState();
    player = Player(
      configuration: const PlayerConfiguration(
        protocolWhitelist: ['http', 'https', 'tcp', 'tls', 'file'],
      ),
    );

    controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: false,
        hwdec: 'auto',
      ),
    );

    // Check for errors
    player.stream.error.listen((error) {
      print('Player error: $error');
    });

    player.open(Media(widget.url));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: Video(controller: controller)),
          Positioned(
            top: 40,
            right: 20,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.audiotrack, color: Colors.white),
                  onPressed: () => _showAudioTracks(context),
                ),
                IconButton(
                  icon: const Icon(Icons.subtitles, color: Colors.white),
                  onPressed: () => _showSubtitleTracks(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSubtitleTracks(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StreamBuilder<Tracks>(
          stream: player.stream.tracks,
          initialData: player.state.tracks,
          builder: (context, snapshot) {
            final tracks = snapshot.data?.subtitle ?? [];
            final current = player.state.track.subtitle;

            return ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                return ListTile(
                  title: Text(
                    track.title ?? track.language ?? 'Track ${index}',
                  ),
                  subtitle: Text(track.id),
                  selected: track == current,
                  trailing: track == current ? const Icon(Icons.check) : null,
                  onTap: () {
                    player.setSubtitleTrack(track);
                    Navigator.pop(context);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAudioTracks(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StreamBuilder<Tracks>(
          stream: player.stream.tracks,
          initialData: player.state.tracks,
          builder: (context, snapshot) {
            final tracks = snapshot.data?.audio ?? [];
            final current = player.state.track.audio;

            return ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                return ListTile(
                  title: Text(
                    track.title ?? track.language ?? 'Track ${index}',
                  ),
                  subtitle: Text(track.id),
                  selected: track == current,
                  trailing: track == current ? const Icon(Icons.check) : null,
                  onTap: () {
                    player.setAudioTrack(track);
                    Navigator.pop(context);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
