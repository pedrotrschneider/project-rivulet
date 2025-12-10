class DiscoveryItem {
  final String id;
  final String title;
  final String? posterUrl;
  final String type; // 'movie' or 'show'
  final String? year;

  DiscoveryItem({
    required this.id,
    required this.title,
    this.posterUrl,
    required this.type,
    this.year,
  });

  factory DiscoveryItem.fromJson(Map<String, dynamic> json) {
    // Handle Title (TMDB uses 'name' for TV, 'title' for movies)
    final title =
        json['title'] as String? ?? json['name'] as String? ?? 'Unknown';

    // Handle Poster
    final posterUrl =
        json['poster_url'] as String? ?? json['poster_path'] as String?;

    // Handle Type
    final type =
        json['type'] as String? ?? json['media_type'] as String? ?? 'movie';

    // Handle Year
    String? year = json['year']?.toString();
    if (year == null) {
      final date =
          json['release_date'] as String? ?? json['first_air_date'] as String?;
      if (date != null && date.length >= 4) {
        year = date.substring(0, 4);
      }
    }

    return DiscoveryItem(
      id:
          json['id']?.toString() ??
          json['uuid']?.toString() ??
          '', // Support both formats
      title: title,
      posterUrl: posterUrl,
      type: type,
      year: year,
    );
  }
}

class MediaDetail {
  final String id;
  final String title;
  final String? posterUrl;
  final String? backdropUrl;
  final String? overview;
  final String? releaseDate;
  final double? rating;
  final String type;
  final String? logo;

  MediaDetail({
    required this.id,
    required this.title,
    this.posterUrl,
    this.backdropUrl,
    this.overview,
    this.releaseDate,
    this.rating,
    required this.type,
    this.logo,
  });

  factory MediaDetail.fromJson(Map<String, dynamic> json) {
    // Handle ID (MDBList uses imdbid/tmdbid)
    final id =
        json['id']?.toString() ??
        json['imdbid']?.toString() ??
        json['tmdbid']?.toString() ??
        '';

    // Handle Poster
    final posterUrl =
        json['poster'] as String? ??
        json['poster_url'] as String? ??
        json['poster_path'] as String?;

    // Handle Backdrop
    final backdropUrl =
        json['backdrop'] as String? ??
        json['backdrop_url'] as String? ??
        json['backdrop_path'] as String?;

    // Handle Overview
    final overview =
        json['description'] as String? ?? json['overview'] as String?;

    // Handle Year/Release Date
    String? releaseDate = json['release_date'] as String?;
    if (releaseDate == null && json['year'] != null) {
      releaseDate = json['year'].toString();
    }

    // Handle Rating (Try to extract from MDBList 'ratings' array or use 'score')
    // MDBList ratings: [{"source": "imdb", "value": 8.5}, ...]
    double? rating =
        (json['score'] as num?)?.toDouble() ??
        (json['rating'] as num?)?.toDouble();
    if (rating == null &&
        json['ratings'] is List &&
        (json['ratings'] as List).isNotEmpty) {
      final firstRating = (json['ratings'] as List).first;
      if (firstRating['value'] is num) {
        rating = (firstRating['value'] as num).toDouble();
      }
    }

    return MediaDetail(
      id: id,
      title: json['title'] as String? ?? 'Unknown',
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      overview: overview,
      releaseDate: releaseDate,
      rating: rating,
      type: json['type'] as String? ?? 'movie',
      logo: json['logo'] as String?,
    );
  }
}

class DiscoverySeason {
  final int id;
  final String name;
  final String? posterPath;
  final int seasonNumber;
  final String? airDate;

  DiscoverySeason({
    required this.id,
    required this.name,
    this.posterPath,
    required this.seasonNumber,
    this.airDate,
  });

  factory DiscoverySeason.fromJson(Map<String, dynamic> json) {
    return DiscoverySeason(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Season ${json['season_number']}',
      posterPath: json['poster_path'] as String?,
      seasonNumber: json['season_number'] as int? ?? 0,
      airDate: json['air_date'] as String?,
    );
  }
}

class DiscoveryEpisode {
  final int id;
  final String name;
  final String? overview;
  final String? stillPath;
  final int episodeNumber;
  final String? airDate;
  final double? voteAverage;

  DiscoveryEpisode({
    required this.id,
    required this.name,
    this.overview,
    this.stillPath,
    required this.episodeNumber,
    this.airDate,
    this.voteAverage,
  });

  factory DiscoveryEpisode.fromJson(Map<String, dynamic> json) {
    return DiscoveryEpisode(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Episode ${json['episode_number']}',
      overview: json['overview'] as String?,
      stillPath: json['still_path'] as String?,
      episodeNumber: json['episode_number'] as int? ?? 0,
      airDate: json['air_date'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
    );
  }
}

class SeasonDetail {
  final int id;
  final String name;
  final String? posterPath;
  final int seasonNumber;
  final List<DiscoveryEpisode> episodes;

  SeasonDetail({
    required this.id,
    required this.name,
    this.posterPath,
    required this.seasonNumber,
    required this.episodes,
  });

  factory SeasonDetail.fromJson(Map<String, dynamic> json) {
    return SeasonDetail(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      posterPath: json['poster_path'] as String?,
      seasonNumber: json['season_number'] as int? ?? 0,
      episodes:
          (json['episodes'] as List<dynamic>?)
              ?.map((e) => DiscoveryEpisode.fromJson(e))
              .toList() ??
          [],
    );
  }
}
