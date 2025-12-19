// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Returns a list of unique media available on the filesystem.
/// Used for the "Library" view in Downloads screen.

@ProviderFor(downloadedContent)
const downloadedContentProvider = DownloadedContentProvider._();

/// Returns a list of unique media available on the filesystem.
/// Used for the "Library" view in Downloads screen.

final class DownloadedContentProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MediaDetail>>,
          List<MediaDetail>,
          FutureOr<List<MediaDetail>>
        >
    with
        $FutureModifier<List<MediaDetail>>,
        $FutureProvider<List<MediaDetail>> {
  /// Returns a list of unique media available on the filesystem.
  /// Used for the "Library" view in Downloads screen.
  const DownloadedContentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadedContentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadedContentHash();

  @$internal
  @override
  $FutureProviderElement<List<MediaDetail>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MediaDetail>> create(Ref ref) {
    return downloadedContent(ref);
  }
}

String _$downloadedContentHash() => r'c612e9a3049decf33306b93e0e00c6f9acde5007';

/// Helper to get media detail from filesystem for offline mode

@ProviderFor(offlineMediaDetail)
const offlineMediaDetailProvider = OfflineMediaDetailFamily._();

/// Helper to get media detail from filesystem for offline mode

final class OfflineMediaDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<MediaDetail>,
          MediaDetail,
          FutureOr<MediaDetail>
        >
    with $FutureModifier<MediaDetail>, $FutureProvider<MediaDetail> {
  /// Helper to get media detail from filesystem for offline mode
  const OfflineMediaDetailProvider._({
    required OfflineMediaDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'offlineMediaDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$offlineMediaDetailHash();

  @override
  String toString() {
    return r'offlineMediaDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MediaDetail> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MediaDetail> create(Ref ref) {
    final argument = this.argument as String;
    return offlineMediaDetail(ref, id: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OfflineMediaDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$offlineMediaDetailHash() =>
    r'05735fb2292399c685639dd795b2b910f4134f4d';

/// Helper to get media detail from filesystem for offline mode

final class OfflineMediaDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MediaDetail>, String> {
  const OfflineMediaDetailFamily._()
    : super(
        retry: null,
        name: r'offlineMediaDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Helper to get media detail from filesystem for offline mode

  OfflineMediaDetailProvider call({required String id}) =>
      OfflineMediaDetailProvider._(argument: id, from: this);

  @override
  String toString() => r'offlineMediaDetailProvider';
}

/// Helper to get seasons/episodes from filesystem

@ProviderFor(offlineSeasonEpisodes)
const offlineSeasonEpisodesProvider = OfflineSeasonEpisodesFamily._();

/// Helper to get seasons/episodes from filesystem

final class OfflineSeasonEpisodesProvider
    extends
        $FunctionalProvider<
          AsyncValue<SeasonDetail>,
          SeasonDetail,
          FutureOr<SeasonDetail>
        >
    with $FutureModifier<SeasonDetail>, $FutureProvider<SeasonDetail> {
  /// Helper to get seasons/episodes from filesystem
  const OfflineSeasonEpisodesProvider._({
    required OfflineSeasonEpisodesFamily super.from,
    required ({String id, int seasonNum}) super.argument,
  }) : super(
         retry: null,
         name: r'offlineSeasonEpisodesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$offlineSeasonEpisodesHash();

  @override
  String toString() {
    return r'offlineSeasonEpisodesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<SeasonDetail> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SeasonDetail> create(Ref ref) {
    final argument = this.argument as ({String id, int seasonNum});
    return offlineSeasonEpisodes(
      ref,
      id: argument.id,
      seasonNum: argument.seasonNum,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OfflineSeasonEpisodesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$offlineSeasonEpisodesHash() =>
    r'8a8639a3a400d15ca5abf569db5abe17ae339c89';

/// Helper to get seasons/episodes from filesystem

final class OfflineSeasonEpisodesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<SeasonDetail>,
          ({String id, int seasonNum})
        > {
  const OfflineSeasonEpisodesFamily._()
    : super(
        retry: null,
        name: r'offlineSeasonEpisodesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Helper to get seasons/episodes from filesystem

  OfflineSeasonEpisodesProvider call({
    required String id,
    required int seasonNum,
  }) => OfflineSeasonEpisodesProvider._(
    argument: (id: id, seasonNum: seasonNum),
    from: this,
  );

  @override
  String toString() => r'offlineSeasonEpisodesProvider';
}

@ProviderFor(offlineAvailableSeasons)
const offlineAvailableSeasonsProvider = OfflineAvailableSeasonsFamily._();

final class OfflineAvailableSeasonsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DiscoverySeason>>,
          List<DiscoverySeason>,
          FutureOr<List<DiscoverySeason>>
        >
    with
        $FutureModifier<List<DiscoverySeason>>,
        $FutureProvider<List<DiscoverySeason>> {
  const OfflineAvailableSeasonsProvider._({
    required OfflineAvailableSeasonsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'offlineAvailableSeasonsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$offlineAvailableSeasonsHash();

  @override
  String toString() {
    return r'offlineAvailableSeasonsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<DiscoverySeason>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<DiscoverySeason>> create(Ref ref) {
    final argument = this.argument as String;
    return offlineAvailableSeasons(ref, id: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OfflineAvailableSeasonsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$offlineAvailableSeasonsHash() =>
    r'aaa2434273c351c33e511f3ec74799800ca92cf0';

final class OfflineAvailableSeasonsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<DiscoverySeason>>, String> {
  const OfflineAvailableSeasonsFamily._()
    : super(
        retry: null,
        name: r'offlineAvailableSeasonsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  OfflineAvailableSeasonsProvider call({required String id}) =>
      OfflineAvailableSeasonsProvider._(argument: id, from: this);

  @override
  String toString() => r'offlineAvailableSeasonsProvider';
}

@ProviderFor(offlineMediaHistory)
const offlineMediaHistoryProvider = OfflineMediaHistoryFamily._();

final class OfflineMediaHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HistoryItem>>,
          List<HistoryItem>,
          FutureOr<List<HistoryItem>>
        >
    with
        $FutureModifier<List<HistoryItem>>,
        $FutureProvider<List<HistoryItem>> {
  const OfflineMediaHistoryProvider._({
    required OfflineMediaHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'offlineMediaHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$offlineMediaHistoryHash();

  @override
  String toString() {
    return r'offlineMediaHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<HistoryItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<HistoryItem>> create(Ref ref) {
    final argument = this.argument as String;
    return offlineMediaHistory(ref, id: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OfflineMediaHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$offlineMediaHistoryHash() =>
    r'eedc9b579e9f154918987e35b91407950b831789';

final class OfflineMediaHistoryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<HistoryItem>>, String> {
  const OfflineMediaHistoryFamily._()
    : super(
        retry: null,
        name: r'offlineMediaHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  OfflineMediaHistoryProvider call({required String id}) =>
      OfflineMediaHistoryProvider._(argument: id, from: this);

  @override
  String toString() => r'offlineMediaHistoryProvider';
}
