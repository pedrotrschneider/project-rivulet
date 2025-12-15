// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LibraryStatus)
const libraryStatusProvider = LibraryStatusFamily._();

final class LibraryStatusProvider
    extends $AsyncNotifierProvider<LibraryStatus, bool> {
  const LibraryStatusProvider._({
    required LibraryStatusFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'libraryStatusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$libraryStatusHash();

  @override
  String toString() {
    return r'libraryStatusProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LibraryStatus create() => LibraryStatus();

  @override
  bool operator ==(Object other) {
    return other is LibraryStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$libraryStatusHash() => r'be5d1acc22c7e17911603e32a2e7014e6736c76e';

final class LibraryStatusFamily extends $Family
    with
        $ClassFamilyOverride<
          LibraryStatus,
          AsyncValue<bool>,
          bool,
          FutureOr<bool>,
          String
        > {
  const LibraryStatusFamily._()
    : super(
        retry: null,
        name: r'libraryStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LibraryStatusProvider call(String id) =>
      LibraryStatusProvider._(argument: id, from: this);

  @override
  String toString() => r'libraryStatusProvider';
}

abstract class _$LibraryStatus extends $AsyncNotifier<bool> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<bool> build(String id);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
