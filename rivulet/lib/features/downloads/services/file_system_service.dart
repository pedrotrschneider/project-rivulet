import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_system_service.g.dart';

@Riverpod(keepAlive: true)
FileSystemService fileSystemService(Ref ref) {
  return const FileSystemService();
}

class FileSystemService {
  const FileSystemService();

  static const String _dataDirName = '.rivulet_data';

  Future<Directory> _getBaseDir() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDocDir.path, _dataDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getMediaDirectory(String id) async {
    final base = await _getBaseDir();
    final dir = Directory(p.join(base.path, id));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getSeasonDirectory(String id, int season) async {
    final mediaDir = await getMediaDirectory(id);
    final seasonStr = 'S${season.toString().padLeft(2, '0')}';
    final dir = Directory(p.join(mediaDir.path, seasonStr));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getEpisodeDirectory(
    String id,
    int season,
    int episode,
  ) async {
    final seasonDir = await getSeasonDirectory(id, season);
    final episodeStr = 'E${episode.toString().padLeft(2, '0')}';
    final dir = Directory(p.join(seasonDir.path, episodeStr));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> writeJson(
    Directory dir,
    String filename,
    dynamic data, // Accept Map or List
  ) async {
    final file = File(p.join(dir.path, filename));
    await file.writeAsString(jsonEncode(data));
    return file;
  }

  Future<Map<String, dynamic>?> readJson(Directory dir, String filename) async {
    final file = File(p.join(dir.path, filename));
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('Error reading JSON $filename: $e');
      return null;
    }
  }

  Future<List<dynamic>?> readJsonList(Directory dir, String filename) async {
    final file = File(p.join(dir.path, filename));
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      return jsonDecode(content) as List<dynamic>;
    } catch (e) {
      print('Error reading JSON List $filename: $e');
      return null;
    }
  }

  Future<File?> downloadImage(
    String url,
    Directory dir,
    String filename,
  ) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(p.join(dir.path, filename));
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (e) {
      print('Error downloading image $url: $e');
    }
    return null;
  }

  /// Helper to delete directory if empty (cleanup)
  Future<void> deleteIfEmpty(Directory dir) async {
    if (await dir.exists()) {
      final list = dir.listSync();
      if (list.isEmpty) {
        await dir.delete();
      }
    }
  }

  /// Helper to delete media directory recursively
  Future<void> deleteMedia(String id) async {
    final dir = await getMediaDirectory(id);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<List<Directory>> listMedia() async {
    final base = await _getBaseDir();
    if (!await base.exists()) return [];
    try {
      return base.listSync().whereType<Directory>().toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Directory>> listSeasons(String id) async {
    final mediaDir = await getMediaDirectory(id);
    if (!await mediaDir.exists()) return [];
    try {
      return mediaDir.listSync().whereType<Directory>().where((d) {
        final name = p.basename(d.path);
        return name.startsWith('S') && int.tryParse(name.substring(1)) != null;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Directory>> listEpisodes(String id, int season) async {
    final seasonDir = await getSeasonDirectory(id, season);
    if (!await seasonDir.exists()) return [];
    try {
      return seasonDir.listSync().whereType<Directory>().where((d) {
        final name = p.basename(d.path);
        return name.startsWith('E') && int.tryParse(name.substring(1)) != null;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> openDownloadsFolder() async {
    final base = await _getBaseDir();
    if (Platform.isLinux) {
      await Process.run('xdg-open', [base.path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [base.path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [base.path]);
    }
  }
}
