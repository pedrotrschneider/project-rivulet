import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:rivulet/features/discovery/domain/discovery_models.dart';
import 'package:rivulet/features/discovery/discovery_provider.dart';

// 1. Change the callback signature
typedef PlayCallback = void Function(int? startPosition);

class ConnectedPlayButton extends ConsumerWidget {
  final String externalId;
  final String type;
  final int? seasonNumber;
  final int? episodeNumber;
  final PlayCallback onPressed; // 2. Use the new signature

  const ConnectedPlayButton({
    super.key,
    required this.externalId,
    required this.type,
    this.seasonNumber,
    this.episodeNumber,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(
      mediaHistoryProvider(externalId: externalId, type: type),
    );

    double progress = 0.0;
    String label = 'Play';
    int? startPos; // 3. Local variable to store calculated position

    final historyList = historyAsync.value ?? [];

    if (historyList.isNotEmpty) {
      HistoryItem? item;

      if (type == 'movie') {
        item = historyList.firstOrNull;
      } else if (seasonNumber != null && episodeNumber != null) {
        item = historyList.firstWhereOrNull((h) =>
            h.seasonNumber == seasonNumber &&
            h.episodeNumber == episodeNumber);
      }

      if (item != null && !item.isWatched && item.positionTicks > 0) {
        // Capture the position to pass back later
        startPos = item.positionTicks;

        final duration = Duration(microseconds: item.positionTicks ~/ 10);
        final timeString = duration.inHours > 0
            ? '${duration.inHours}h ${duration.inMinutes.remainder(60)}m'
            : '${duration.inMinutes}m';

        label = 'Resume $timeString';

        if (item.durationTicks > 0) {
          progress = item.positionTicks / item.durationTicks;
          if (progress > 1.0) progress = 1.0;
        }
      }
    }

    return PlayButton(
      label: label,
      progress: progress,
      // 4. When clicked, invoke the callback with the position we found
      onPressed: () => onPressed(startPos),
    );
  }
}

class PlayButton extends StatelessWidget {
  final String label;
  final double progress;
  final VoidCallback? onPressed;

  const PlayButton({
    super.key,
    this.label = 'Play',
    this.progress = 0.0,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Material(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Stack(
            children: [
              // Progress Bar (Dark Overlay)
              if (progress > 0)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: constraints.maxWidth * progress,
                          color: Colors.black.withOpacity(0.25),
                        ),
                      );
                    },
                  ),
                ),

              // Content
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 28,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
