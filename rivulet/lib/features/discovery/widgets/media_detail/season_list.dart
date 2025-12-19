import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rivulet/features/discovery/discovery_provider.dart';
import 'package:rivulet/features/discovery/domain/discovery_models.dart';
import 'package:rivulet/features/widgets/action_scale.dart';
import 'package:rivulet/features/downloads/providers/offline_providers.dart';

class VerticalOverflowClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0.0, -1000.0, size.width, size.height + 1000.0);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

class SeasonList extends ConsumerStatefulWidget {
  final String itemId;
  final bool offlineMode;
  final int? selectedSeason;
  final ValueChanged<DiscoverySeason> onSeasonSelected;
  final String? showPosterPath;
  final Widget? leading;
  final FocusNode? focusNode;

  const SeasonList({
    super.key,
    required this.itemId,
    this.offlineMode = false,
    required this.onSeasonSelected,
    this.selectedSeason,
    required this.showPosterPath,
    this.leading,
    this.focusNode,
  });

  @override
  ConsumerState<SeasonList> createState() => _SeasonListState();
}

class _SeasonListState extends ConsumerState<SeasonList> {
  late FocusNode _internalFocusNode;
  bool _hasRequestedInitialFocus = false;

  static const double _seasonCardWidth = 140.0;
  static const double _separatorWidth = 16.0;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
  }

  @override
  void dispose() {
    super.dispose();
  }

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  Widget build(BuildContext context) {
    // Switch provider based on mode
    final seasonsAsync = widget.offlineMode
        ? ref.watch(offlineAvailableSeasonsProvider(id: widget.itemId))
        : ref.watch(showSeasonsProvider(widget.itemId));

    return seasonsAsync.when(
      data: (seasons) {
        if (seasons.isEmpty && widget.leading == null) {
          return const SizedBox.shrink();
        }

        if (!_hasRequestedInitialFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _effectiveFocusNode.requestFocus();
              _hasRequestedInitialFocus = true;
            }
          });
        }

        final totalCount = seasons.length + (widget.leading != null ? 1 : 0);

        return LayoutBuilder(
          builder: (context, constraints) {
            final centerPadding = (constraints.maxWidth - _seasonCardWidth) / 2;

            return ClipRect(
              clipper: VerticalOverflowClipper(),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: totalCount,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: _separatorWidth),
                clipBehavior: Clip.none,
                padding: EdgeInsets.only(
                  right: centerPadding > 0 ? centerPadding : 0,
                ),
                itemBuilder: (context, index) {
                  if (widget.leading != null) {
                    if (index == 0) return widget.leading!;
                    final season = seasons[index - 1];
                    return SeasonCard(
                      focusNode: index == 1 ? _effectiveFocusNode : null,
                      season: season,
                      showPosterPath: widget.showPosterPath,
                      isSelected: season.seasonNumber == widget.selectedSeason,
                      onTap: () => widget.onSeasonSelected(season),
                      offlineMode: widget.offlineMode,
                    );
                  }

                  final season = seasons[index];
                  return SeasonCard(
                    focusNode: index == 0 ? _effectiveFocusNode : null,
                    season: season,
                    showPosterPath: widget.showPosterPath,
                    isSelected: season.seasonNumber == widget.selectedSeason,
                    onTap: () => widget.onSeasonSelected(season),
                    offlineMode: widget.offlineMode,
                  );
                },
              ),
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
  final FocusNode? focusNode;
  final bool offlineMode;

  const SeasonCard({
    super.key,
    required this.season,
    required this.onTap,
    this.isSelected = false,
    required this.showPosterPath,
    this.focusNode,
    this.offlineMode = false,
  });

  @override
  State<SeasonCard> createState() => _SeasonCardState();
}

class _SeasonCardState extends State<SeasonCard> {
  // We track the node we created separately so we know if we own it
  FocusNode? _internalNode;

  // Helper to get the node we should be using right now
  FocusNode get _effectiveNode => widget.focusNode ?? _internalNode!;

  @override
  void initState() {
    super.initState();
    _initNode();
    _effectiveNode.addListener(_onFocusChange);
  }

  void _initNode() {
    if (widget.focusNode == null) {
      _internalNode = FocusNode();
    }
  }

  @override
  void didUpdateWidget(SeasonCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      final oldEffectiveNode = oldWidget.focusNode ?? _internalNode;
      oldEffectiveNode?.removeListener(_onFocusChange);

      _effectiveNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _effectiveNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (_effectiveNode.hasFocus && mounted) {
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionScale(
      focusNode: _effectiveNode,
      duration: const Duration(milliseconds: 200),
      builder: (context, node) => InkWell(
        focusNode: node,
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
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
                    child: _buildImage(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 140,
              child: Text(
                widget.season.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (widget.offlineMode) {
      // Offline: Try local file paths or fallbacks
      if (widget.season.posterPath != null &&
          widget.season.posterPath!.isNotEmpty) {
        return Image.file(
          File(widget.season.posterPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      } else if (widget.showPosterPath != null &&
          widget.showPosterPath!.isNotEmpty) {
        if (widget.showPosterPath!.startsWith('http') ||
            widget.showPosterPath!.startsWith('/')) {
          return Image.file(
            File(widget.showPosterPath!),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          );
        }
        return Image.file(
          File(widget.showPosterPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }
      return _buildPlaceholder();
    } else {
      // Online
      if (widget.season.posterPath != null && widget.season.posterPath != '') {
        return Image.network(
          'https://image.tmdb.org/t/p/w342${widget.season.posterPath}',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      } else if (widget.showPosterPath != null && widget.showPosterPath != '') {
        return Image.network(
          'https://image.tmdb.org/t/p/w342${widget.showPosterPath}',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Center(child: Icon(Icons.tv)),
    );
  }
}
