import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../discovery/domain/discovery_models.dart';
import 'library_repository.dart';

part 'library_provider.g.dart';

/// Provider for the library items.
@riverpod
class Library extends _$Library {
  @override
  Future<List<DiscoveryItem>> build() async {
    return await _fetchItems();
  }

  Future<List<DiscoveryItem>> _fetchItems({String? type}) async {
    final repo = ref.read(libraryRepositoryProvider);
    final response = await repo.fetchLibrary(type: type);
    return response.results;
  }

  /// Refresh the library.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final items = await _fetchItems();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Filter by type.
  Future<void> filterByType(String? type) async {
    state = const AsyncValue.loading();
    try {
      final items = await _fetchItems(type: type);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
