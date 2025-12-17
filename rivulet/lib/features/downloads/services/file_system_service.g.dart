// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_system_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(fileSystemService)
const fileSystemServiceProvider = FileSystemServiceProvider._();

final class FileSystemServiceProvider
    extends
        $FunctionalProvider<
          FileSystemService,
          FileSystemService,
          FileSystemService
        >
    with $Provider<FileSystemService> {
  const FileSystemServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileSystemServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileSystemServiceHash();

  @$internal
  @override
  $ProviderElement<FileSystemService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FileSystemService create(Ref ref) {
    return fileSystemService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FileSystemService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FileSystemService>(value),
    );
  }
}

String _$fileSystemServiceHash() => r'11360f2b499626938b18ebcda33307112ffc5e12';
