import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/profile.dart';
import 'profiles_repository.dart';

part 'profiles_provider.g.dart';

/// Provider that fetches and caches the list of profiles for the current account.
@riverpod
class Profiles extends _$Profiles {
  @override
  Future<List<Profile>> build() async {
    final repo = ref.read(profilesRepositoryProvider);
    return await repo.fetchProfiles();
  }

  /// Refreshes the profile list from the server.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(profilesRepositoryProvider);
      final profiles = await repo.fetchProfiles();
      state = AsyncValue.data(profiles);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Creates a new profile and refreshes the list.
  Future<void> createProfile(String name) async {
    final repo = ref.read(profilesRepositoryProvider);
    await repo.createProfile(name);
    await refresh();
  }
}

/// Provider for the currently selected profile ID.
/// Persists the selection to SharedPreferences.
@riverpod
class SelectedProfile extends _$SelectedProfile {
  static const _key = 'selected_profile_id';

  @override
  String? build() {
    // Load asynchronously on first access
    _loadFromPrefs();
    return null;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key);
    if (id != null) {
      state = id;
    }
  }

  /// Load the selected profile from storage.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key);
  }

  /// Select a profile and persist the choice.
  Future<void> select(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, profileId);
    state = profileId;
  }

  /// Clear the selected profile (e.g., on logout).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = null;
  }
}
