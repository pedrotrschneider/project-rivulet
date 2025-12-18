import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rivulet/features/discovery/discovery_provider.dart';
import 'package:rivulet/features/discovery/domain/discovery_models.dart';

class SeasonList extends ConsumerWidget {
  final String itemId;
  final bool offlineMode;
  final int? selectedSeason; // Used potentially for highlighting
  final ValueChanged<int> onSeasonSelected;
  final String? showPosterPath;
  final Widget? leading;

  const SeasonList({
    super.key,
    required this.itemId,
    this.offlineMode = false,
    required this.onSeasonSelected,
    this.selectedSeason,
    required this.showPosterPath,
    this.leading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (offlineMode) return const SizedBox.shrink();

    final seasonsAsync = ref.watch(showSeasonsProvider(itemId));

    return seasonsAsync.when(
      data: (seasons) {
        if (seasons.isEmpty && leading == null) return const SizedBox.shrink();

        final totalCount = seasons.length + (leading != null ? 1 : 0);

        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: totalCount,
          separatorBuilder: (_, _) => const SizedBox(width: 16),
          itemBuilder: (context, index) {
            if (leading != null) {
              if (index == 0) return leading!;
              // Adjust index for seasons
              final season = seasons[index - 1];
              return SeasonCard(
                season: season,
                showPosterPath: showPosterPath,
                isSelected: season.seasonNumber == selectedSeason,
                onTap: () => onSeasonSelected(season.seasonNumber),
              );
            }

            final season = seasons[index];
            return SeasonCard(
              season: season,
              showPosterPath: showPosterPath,
              isSelected: season.seasonNumber == selectedSeason,
              onTap: () => onSeasonSelected(season.seasonNumber),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class SeasonCard extends StatefulWidget {
  final DiscoverySeason season;
  final VoidCallback onTap;
  final bool isSelected;
  final String? showPosterPath;

  const SeasonCard({
    super.key,
    required this.season,
    required this.onTap,
    this.isSelected = false,
    required this.showPosterPath,
  });

  @override
  State<SeasonCard> createState() => _SeasonCardState();
}

class _SeasonCardState extends State<SeasonCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: Container(
            decoration: BoxDecoration(
              border: widget.isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.season.posterPath != null &&
                          widget.season.posterPath != ''
                      ? Image.network(
                          'https://image.tmdb.org/t/p/w342${widget.season.posterPath}',
                          fit: BoxFit.cover,
                        )
                      : widget.showPosterPath != null &&
                            widget.showPosterPath != ''
                      ? Image.network(
                          'https://image.tmdb.org/t/p/w342${widget.showPosterPath}',
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: const Center(child: Icon(Icons.tv)),
                        ),

                  // Sliding Gradient Box
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    left: 0,
                    right: 0,
                    bottom: _isHovered ? 0 : -80, // Slide up from bottom
                    height: 80,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.9),
                            Colors.transparent,
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: Text(
                        widget.season.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
