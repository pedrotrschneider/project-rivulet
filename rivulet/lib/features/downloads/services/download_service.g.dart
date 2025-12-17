// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(downloadService)
const downloadServiceProvider = DownloadServiceProvider._();

final class DownloadServiceProvider
    extends
        $FunctionalProvider<DownloadService, DownloadService, DownloadService>
    with $Provider<DownloadService> {
  const DownloadServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadServiceHash();

  @$internal
  @override
  $ProviderElement<DownloadService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DownloadService create(Ref ref) {
    return downloadService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadService>(value),
    );
  }
}

String _$downloadServiceHash() => r'1fa32cce7e198cfafe296adee7ab83353d518450';

@ProviderFor(DownloadRefreshTrigger)
const downloadRefreshTriggerProvider = DownloadRefreshTriggerProvider._();

final class DownloadRefreshTriggerProvider
    extends $NotifierProvider<DownloadRefreshTrigger, int> {
  const DownloadRefreshTriggerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadRefreshTriggerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadRefreshTriggerHash();

  @$internal
  @override
  DownloadRefreshTrigger create() => DownloadRefreshTrigger();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$downloadRefreshTriggerHash() =>
    r'add3996e00ddaa2bc9301519e292fa7af69167e9';

abstract class _$DownloadRefreshTrigger extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
