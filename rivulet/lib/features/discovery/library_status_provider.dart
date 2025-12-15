import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'repository/discovery_repository.dart';

part 'library_status_provider.g.dart';

@riverpod
class LibraryStatus extends _$LibraryStatus {
  @override
  FutureOr<bool> build(String id) async {
    return ref.read(discoveryRepositoryProvider).checkLibraryStatus(id);
  }

  Future<void> toggle(String type, {String? idOverride}) async {
    final inLibrary = state.value ?? false;
    final targetId = idOverride ?? id;
    // For removing, we can use the original ID (TMDB) as backend lookup handles it.
    // For adding, we prefer the override (IMDb).
    // But consistency matters. If we remove, we should ideally use the same ID used to check.
    // RemoveFromLibrary(id) finds by external_ids. So "123" (TMDB) works to remove record with "tt..." (IMDb) if both stored.

    state = const AsyncValue.loading();

    try {
      final repo = ref.read(discoveryRepositoryProvider);
      if (inLibrary) {
        // Remove using the ID we used to check (safe)
        await repo.removeFromLibrary(id);
      } else {
        // Add using the preferred ID (e.g. IMDb)
        await repo.addToLibrary(targetId, type);
      }
      // Refresh status
      ref.invalidateSelf();
      await future;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
