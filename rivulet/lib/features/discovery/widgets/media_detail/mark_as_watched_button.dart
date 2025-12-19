import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rivulet/features/discovery/domain/discovery_models.dart';
import 'package:rivulet/features/widgets/action_scale.dart';
import 'package:rivulet/features/discovery/discovery_provider.dart';
import 'package:rivulet/features/downloads/providers/offline_providers.dart';

import 'package:collection/collection.dart';

typedef MarkAsWatchedCallback =
    Future<void> Function({
      required String mediaId,
      required String type,
      required bool isWatched,
      int? season,
      int? episode,
    });

class DynamicWatchedButton extends ConsumerWidget {
  final MediaDetail detail;
  final DiscoverySeason? selectedSeason;
  final DiscoveryEpisode? selectedEpisode;
  final MarkAsWatchedCallback markAsWatched;
  final bool offlineMode;

  const DynamicWatchedButton({
    super.key,
    required this.detail,
    required this.selectedSeason,
    required this.selectedEpisode,
    required this.markAsWatched,
    required this.offlineMode,
  });

  bool _isWatched(AsyncValue<List<HistoryItem>> historyAsync) {
    if (historyAsync.value == null) {
      return false;
    }

    if (selectedSeason == null || selectedEpisode == null) {
      return historyAsync.value!
              .firstWhereOrNull(
                (h) => h.mediaId == detail.imdbId || h.mediaId == detail.id,
              )
              ?.isWatched ??
          false;
    }

    return historyAsync.value!
            .firstWhereOrNull(
              (h) =>
                  h.seasonNumber == selectedSeason!.seasonNumber &&
                  h.episodeNumber == selectedEpisode!.episodeNumber,
            )
            ?.isWatched ??
        false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = offlineMode
        ? ref.watch(offlineMediaHistoryProvider(id: detail.id))
        : ref.watch(mediaHistoryProvider(externalId: detail.id));

    return _isWatched(historyAsync)
        ? MarkAsUnwatchedButton(
            onPressed: () {
              markAsWatched(
                mediaId: detail.imdbId!,
                type: detail.type,
                season: selectedSeason?.seasonNumber,
                episode: selectedEpisode?.episodeNumber,
                isWatched: !_isWatched(historyAsync),
              );
            },
          )
        : MarkAsWatchedButton(
            onPressed: () {
              markAsWatched(
                mediaId: detail.imdbId!,
                type: detail.type,
                season: selectedSeason?.seasonNumber,
                episode: selectedEpisode?.episodeNumber,
                isWatched: !_isWatched(historyAsync),
              );
            },
          );
  }
}

class MarkAsWatchedButton extends ConsumerWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const MarkAsWatchedButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Mark as Watched',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ActionScale(
      scale: 1.1,
      breathingIntensity: 0.15,
      builder: (context, node) {
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton.filledTonal(
            onPressed: onPressed,
            icon: const Icon(Icons.visibility),
            tooltip: tooltip,
          ),
        );
      },
    );
  }
}

class MarkAsUnwatchedButton extends ConsumerWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const MarkAsUnwatchedButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Mark as Unwatched',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ActionScale(
      scale: 1.1,
      breathingIntensity: 0.15,
      builder: (context, node) {
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton.filledTonal(
            onPressed: onPressed,
            icon: const Icon(Icons.visibility_off),
            tooltip: tooltip,
          ),
        );
      },
    );
  }
}
