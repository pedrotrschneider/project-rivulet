// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the library items.

@ProviderFor(Library)
const libraryProvider = LibraryProvider._();

/// Provider for the library items.
final class LibraryProvider
    extends $AsyncNotifierProvider<Library, List<DiscoveryItem>> {
  /// Provider for the library items.
  const LibraryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryHash();

  @$internal
  @override
  Library create() => Library();
}

String _$libraryHash() => r'1111f07054805dd497c0cd07c8ce04d4b033b4ed';

/// Provider for the library items.

abstract class _$Library extends $AsyncNotifier<List<DiscoveryItem>> {
  FutureOr<List<DiscoveryItem>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<DiscoveryItem>>, List<DiscoveryItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<DiscoveryItem>>, List<DiscoveryItem>>,
              AsyncValue<List<DiscoveryItem>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
