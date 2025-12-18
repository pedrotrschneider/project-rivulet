// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_history_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(offlineHistoryService)
const offlineHistoryServiceProvider = OfflineHistoryServiceProvider._();

final class OfflineHistoryServiceProvider
    extends
        $FunctionalProvider<
          OfflineHistoryService,
          OfflineHistoryService,
          OfflineHistoryService
        >
    with $Provider<OfflineHistoryService> {
  const OfflineHistoryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineHistoryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineHistoryServiceHash();

  @$internal
  @override
  $ProviderElement<OfflineHistoryService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OfflineHistoryService create(Ref ref) {
    return offlineHistoryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OfflineHistoryService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OfflineHistoryService>(value),
    );
  }
}

String _$offlineHistoryServiceHash() =>
    r'1c0e0d5edd75bbef0210a02e33eef55d7c3c1d0e';
