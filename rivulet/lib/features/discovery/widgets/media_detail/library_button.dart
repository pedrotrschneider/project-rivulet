import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rivulet/features/discovery/discovery_provider.dart';
import '../../library_status_provider.dart';
import 'package:rivulet/features/widgets/action_scale.dart'; 

class LibraryButton extends ConsumerWidget {
  final String itemId;
  final String type;
  final bool offlineMode;

  const LibraryButton({
    super.key,
    required this.itemId,
    required this.type,
    this.offlineMode = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (offlineMode) return const SizedBox.shrink();

    final statusAsync = ref.watch(libraryStatusProvider(itemId));

    return statusAsync.when(
      data: (inLibrary) => ActionScale(
        scale: 1.1,
        breathingIntensity: 0.15,
        builder: (context, node) {
          return Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              focusNode: node, 
              icon: Icon(inLibrary ? Icons.check : Icons.add),
              tooltip: inLibrary ? 'Remove from Library' : 'Add to Library',
              onPressed: () async {
                try {
                  final detail = ref
                      .read(mediaDetailProvider(id: itemId, type: type))
                      .value;

                  final idToAdd = detail?.imdbId ??
                      (detail?.id.isNotEmpty == true ? detail!.id : itemId);
                  final typeToAdd = detail?.type ?? type;

                  await ref
                      .read(libraryStatusProvider(itemId).notifier)
                      .toggle(typeToAdd, idOverride: idToAdd);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          inLibrary
                              ? 'Removed from Library'
                              : 'Added to Library',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Action failed: $e')),
                    );
                  }
                }
              },
            ),
          );
        },
      ),
      loading: () => Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.only(right: 16),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}