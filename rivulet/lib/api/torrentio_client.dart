import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final torrentioClientProvider = Provider((ref) => TorrentioClient());

class TorrentioClient {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://torrentio.strem.fun',
  ));

  Future<List<TorrentioStream>> getStreams(String imdbId) async {
    try {
      final response = await _dio.get('/stream/movie/$imdbId.json');
      
      if (response.data == null || response.data['streams'] == null) {
        return [];
      }

      final streams = (response.data['streams'] as List)
          .map((e) => TorrentioStream.fromJson(e))
          .toList();
      
      return streams;
    } catch (e) {
      // In a real app, we would log this error
      print('Error fetching streams: $e');
      return [];
    }
  }
}

class TorrentioStream {
  final String? name;
  final String? title;
  final String? infoHash;
  final String? fileIdx;
  final String? behaviorHints;

  TorrentioStream({
    this.name,
    this.title,
    this.infoHash,
    this.fileIdx,
    this.behaviorHints,
  });

  factory TorrentioStream.fromJson(Map<String, dynamic> json) {
    return TorrentioStream(
      name: json['name'],
      title: json['title'],
      infoHash: json['infoHash'],
      fileIdx: json['fileIdx']?.toString(),
      behaviorHints: json['behaviorHints']?.toString(),
    );
  }
  
  // Helper to extract resolution/quality from title
  String get quality {
    if (title == null) return 'Unknown';
    if (title!.contains('4k') || title!.contains('2160p')) return '4K';
    if (title!.contains('1080p')) return '1080p';
    if (title!.contains('720p')) return '720p';
    return 'SD';
  }
}
