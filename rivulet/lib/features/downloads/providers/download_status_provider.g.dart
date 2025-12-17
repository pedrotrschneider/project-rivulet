// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(isDownloaded)
const isDownloadedProvider = IsDownloadedFamily._();

final class IsDownloadedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  const IsDownloadedProvider._({
    required IsDownloadedFamily super.from,
    required ({String mediaId, int? season, int? episode}) super.argument,
  }) : super(
         retry: null,
         name: r'isDownloadedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isDownloadedHash();

  @override
  String toString() {
    return r'isDownloadedProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument =
        this.argument as ({String mediaId, int? season, int? episode});
    return isDownloaded(
      ref,
      mediaId: argument.mediaId,
      season: argument.season,
      episode: argument.episode,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IsDownloadedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isDownloadedHash() => r'b274f524e0a9ae9ec07b80f5f7ce6a92c1718966';

final class IsDownloadedFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<bool>,
          ({String mediaId, int? season, int? episode})
        > {
  const IsDownloadedFamily._()
    : super(
        retry: null,
        name: r'isDownloadedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  IsDownloadedProvider call({
    required String mediaId,
    int? season,
    int? episode,
  }) => IsDownloadedProvider._(
    argument: (mediaId: mediaId, season: season, episode: episode),
    from: this,
  );

  @override
  String toString() => r'isDownloadedProvider';
}

@ProviderFor(activeDownload)
const activeDownloadProvider = ActiveDownloadFamily._();

final class ActiveDownloadProvider
    extends
        $FunctionalProvider<
          AsyncValue<TaskRecord?>,
          TaskRecord?,
          FutureOr<TaskRecord?>
        >
    with $FutureModifier<TaskRecord?>, $FutureProvider<TaskRecord?> {
  const ActiveDownloadProvider._({
    required ActiveDownloadFamily super.from,
    required ({String mediaId, int? season, int? episode}) super.argument,
  }) : super(
         retry: null,
         name: r'activeDownloadProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activeDownloadHash();

  @override
  String toString() {
    return r'activeDownloadProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<TaskRecord?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TaskRecord?> create(Ref ref) {
    final argument =
        this.argument as ({String mediaId, int? season, int? episode});
    return activeDownload(
      ref,
      mediaId: argument.mediaId,
      season: argument.season,
      episode: argument.episode,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ActiveDownloadProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activeDownloadHash() => r'd99ca7d8c191f0351e134cd3aeb61e82dedf353a';

final class ActiveDownloadFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<TaskRecord?>,
          ({String mediaId, int? season, int? episode})
        > {
  const ActiveDownloadFamily._()
    : super(
        retry: null,
        name: r'activeDownloadProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ActiveDownloadProvider call({
    required String mediaId,
    int? season,
    int? episode,
  }) => ActiveDownloadProvider._(
    argument: (mediaId: mediaId, season: season, episode: episode),
    from: this,
  );

  @override
  String toString() => r'activeDownloadProvider';
}
