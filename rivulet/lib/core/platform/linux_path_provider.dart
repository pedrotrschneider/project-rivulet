import 'dart:io';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:path/path.dart' as p;

class LinuxPathProviderOverride extends PathProviderPlatform {
  String _getBasePath() {
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    final dir = Directory(p.join(home, '.rivulet_data'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir.path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return _getBasePath();
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return _getBasePath();
  }

  @override
  Future<String?> getApplicationCachePath() async {
    final base = _getBasePath();
    final dir = Directory(p.join(base, 'cache'));
    if (!dir.existsSync()) dir.createSync();
    return dir.path;
  }

  @override
  Future<String?> getTemporaryPath() async {
    final base = _getBasePath();
    final dir = Directory(p.join(base, 'tmp'));
    if (!dir.existsSync()) dir.createSync();
    return dir.path;
  }

  @override
  Future<String?> getDownloadsPath() async {
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    final dir = Directory(p.join(home, 'Downloads'));
    if (!dir.existsSync()) {
      return _getBasePath();
    }
    return dir.path;
  }
}
