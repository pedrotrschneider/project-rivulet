// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profiles_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that fetches and caches the list of profiles for the current account.

@ProviderFor(Profiles)
const profilesProvider = ProfilesProvider._();

/// Provider that fetches and caches the list of profiles for the current account.
final class ProfilesProvider
    extends $AsyncNotifierProvider<Profiles, List<Profile>> {
  /// Provider that fetches and caches the list of profiles for the current account.
  const ProfilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profilesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profilesHash();

  @$internal
  @override
  Profiles create() => Profiles();
}

String _$profilesHash() => r'499e58309be9545cb745938eeeba708c858b99d0';

/// Provider that fetches and caches the list of profiles for the current account.

abstract class _$Profiles extends $AsyncNotifier<List<Profile>> {
  FutureOr<List<Profile>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<List<Profile>>, List<Profile>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Profile>>, List<Profile>>,
              AsyncValue<List<Profile>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider for the currently selected profile ID.
/// Persists the selection to SharedPreferences.

@ProviderFor(SelectedProfile)
const selectedProfileProvider = SelectedProfileProvider._();

/// Provider for the currently selected profile ID.
/// Persists the selection to SharedPreferences.
final class SelectedProfileProvider
    extends $NotifierProvider<SelectedProfile, String?> {
  /// Provider for the currently selected profile ID.
  /// Persists the selection to SharedPreferences.
  const SelectedProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedProfileHash();

  @$internal
  @override
  SelectedProfile create() => SelectedProfile();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$selectedProfileHash() => r'7e38c93eface61682ea9c7c96980183024070795';

/// Provider for the currently selected profile ID.
/// Persists the selection to SharedPreferences.

abstract class _$SelectedProfile extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
