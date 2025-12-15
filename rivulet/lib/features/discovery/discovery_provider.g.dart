// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DiscoverySearch)
const discoverySearchProvider = DiscoverySearchProvider._();

final class DiscoverySearchProvider
    extends $AsyncNotifierProvider<DiscoverySearch, List<DiscoveryItem>> {
  const DiscoverySearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoverySearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoverySearchHash();

  @$internal
  @override
  DiscoverySearch create() => DiscoverySearch();
}

String _$discoverySearchHash() => r'621911d8292de90a16187991f2c6f2129173b622';

abstract class _$DiscoverySearch extends $AsyncNotifier<List<DiscoveryItem>> {
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

@ProviderFor(mediaDetail)
const mediaDetailProvider = MediaDetailFamily._();

final class MediaDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<MediaDetail>,
          MediaDetail,
          FutureOr<MediaDetail>
        >
    with $FutureModifier<MediaDetail>, $FutureProvider<MediaDetail> {
  const MediaDetailProvider._({
    required MediaDetailFamily super.from,
    required ({String id, String type}) super.argument,
  }) : super(
         retry: null,
         name: r'mediaDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mediaDetailHash();

  @override
  String toString() {
    return r'mediaDetailProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<MediaDetail> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MediaDetail> create(Ref ref) {
    final argument = this.argument as ({String id, String type});
    return mediaDetail(ref, id: argument.id, type: argument.type);
  }

  @override
  bool operator ==(Object other) {
    return other is MediaDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaDetailHash() => r'e93dff1148849f9fa1a6647c0ffe14996b3974c3';

final class MediaDetailFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<MediaDetail>,
          ({String id, String type})
        > {
  const MediaDetailFamily._()
    : super(
        retry: null,
        name: r'mediaDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MediaDetailProvider call({required String id, required String type}) =>
      MediaDetailProvider._(argument: (id: id, type: type), from: this);

  @override
  String toString() => r'mediaDetailProvider';
}

@ProviderFor(showSeasons)
const showSeasonsProvider = ShowSeasonsFamily._();

final class ShowSeasonsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DiscoverySeason>>,
          List<DiscoverySeason>,
          FutureOr<List<DiscoverySeason>>
        >
    with
        $FutureModifier<List<DiscoverySeason>>,
        $FutureProvider<List<DiscoverySeason>> {
  const ShowSeasonsProvider._({
    required ShowSeasonsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'showSeasonsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$showSeasonsHash();

  @override
  String toString() {
    return r'showSeasonsProvider'
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
    return showSeasons(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ShowSeasonsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$showSeasonsHash() => r'cb5ce17cb1d0b604e35d0c3e49244650663d387a';

final class ShowSeasonsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<DiscoverySeason>>, String> {
  const ShowSeasonsFamily._()
    : super(
        retry: null,
        name: r'showSeasonsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ShowSeasonsProvider call(String id) =>
      ShowSeasonsProvider._(argument: id, from: this);

  @override
  String toString() => r'showSeasonsProvider';
}

@ProviderFor(seasonEpisodes)
const seasonEpisodesProvider = SeasonEpisodesFamily._();

final class SeasonEpisodesProvider
    extends
        $FunctionalProvider<
          AsyncValue<SeasonDetail>,
          SeasonDetail,
          FutureOr<SeasonDetail>
        >
    with $FutureModifier<SeasonDetail>, $FutureProvider<SeasonDetail> {
  const SeasonEpisodesProvider._({
    required SeasonEpisodesFamily super.from,
    required ({String id, int seasonNum}) super.argument,
  }) : super(
         retry: null,
         name: r'seasonEpisodesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$seasonEpisodesHash();

  @override
  String toString() {
    return r'seasonEpisodesProvider'
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
    return seasonEpisodes(ref, id: argument.id, seasonNum: argument.seasonNum);
  }

  @override
  bool operator ==(Object other) {
    return other is SeasonEpisodesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$seasonEpisodesHash() => r'0f97561a66f627b8792cdc61ebe878107ac81843';

final class SeasonEpisodesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<SeasonDetail>,
          ({String id, int seasonNum})
        > {
  const SeasonEpisodesFamily._()
    : super(
        retry: null,
        name: r'seasonEpisodesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SeasonEpisodesProvider call({required String id, required int seasonNum}) =>
      SeasonEpisodesProvider._(
        argument: (id: id, seasonNum: seasonNum),
        from: this,
      );

  @override
  String toString() => r'seasonEpisodesProvider';
}

@ProviderFor(streamScraper)
const streamScraperProvider = StreamScraperFamily._();

final class StreamScraperProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StreamResult>>,
          List<StreamResult>,
          FutureOr<List<StreamResult>>
        >
    with
        $FutureModifier<List<StreamResult>>,
        $FutureProvider<List<StreamResult>> {
  const StreamScraperProvider._({
    required StreamScraperFamily super.from,
    required ({String externalId, String type, int? season, int? episode})
    super.argument,
  }) : super(
         retry: null,
         name: r'streamScraperProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$streamScraperHash();

  @override
  String toString() {
    return r'streamScraperProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<StreamResult>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<StreamResult>> create(Ref ref) {
    final argument =
        this.argument
            as ({String externalId, String type, int? season, int? episode});
    return streamScraper(
      ref,
      externalId: argument.externalId,
      type: argument.type,
      season: argument.season,
      episode: argument.episode,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StreamScraperProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$streamScraperHash() => r'2dd1003d7d969737f2da955ce8557ab72ec9ec6d';

final class StreamScraperFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<StreamResult>>,
          ({String externalId, String type, int? season, int? episode})
        > {
  const StreamScraperFamily._()
    : super(
        retry: null,
        name: r'streamScraperProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StreamScraperProvider call({
    required String externalId,
    required String type,
    int? season,
    int? episode,
  }) => StreamScraperProvider._(
    argument: (
      externalId: externalId,
      type: type,
      season: season,
      episode: episode,
    ),
    from: this,
  );

  @override
  String toString() => r'streamScraperProvider';
}
