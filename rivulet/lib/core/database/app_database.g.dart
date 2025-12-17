// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MediaCacheTable extends MediaCache
    with TableInfo<$MediaCacheTable, MediaCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAccessedMeta = const VerificationMeta(
    'lastAccessed',
  );
  @override
  late final GeneratedColumn<DateTime> lastAccessed = GeneratedColumn<DateTime>(
    'last_accessed',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [uuid, metadataJson, lastAccessed];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_metadataJsonMeta);
    }
    if (data.containsKey('last_accessed')) {
      context.handle(
        _lastAccessedMeta,
        lastAccessed.isAcceptableOrUnknown(
          data['last_accessed']!,
          _lastAccessedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  MediaCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaCacheData(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      )!,
      lastAccessed: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_accessed'],
      )!,
    );
  }

  @override
  $MediaCacheTable createAlias(String alias) {
    return $MediaCacheTable(attachedDatabase, alias);
  }
}

class MediaCacheData extends DataClass implements Insertable<MediaCacheData> {
  final String uuid;
  final String metadataJson;
  final DateTime lastAccessed;
  const MediaCacheData({
    required this.uuid,
    required this.metadataJson,
    required this.lastAccessed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['metadata_json'] = Variable<String>(metadataJson);
    map['last_accessed'] = Variable<DateTime>(lastAccessed);
    return map;
  }

  MediaCacheCompanion toCompanion(bool nullToAbsent) {
    return MediaCacheCompanion(
      uuid: Value(uuid),
      metadataJson: Value(metadataJson),
      lastAccessed: Value(lastAccessed),
    );
  }

  factory MediaCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaCacheData(
      uuid: serializer.fromJson<String>(json['uuid']),
      metadataJson: serializer.fromJson<String>(json['metadataJson']),
      lastAccessed: serializer.fromJson<DateTime>(json['lastAccessed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'metadataJson': serializer.toJson<String>(metadataJson),
      'lastAccessed': serializer.toJson<DateTime>(lastAccessed),
    };
  }

  MediaCacheData copyWith({
    String? uuid,
    String? metadataJson,
    DateTime? lastAccessed,
  }) => MediaCacheData(
    uuid: uuid ?? this.uuid,
    metadataJson: metadataJson ?? this.metadataJson,
    lastAccessed: lastAccessed ?? this.lastAccessed,
  );
  MediaCacheData copyWithCompanion(MediaCacheCompanion data) {
    return MediaCacheData(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      lastAccessed: data.lastAccessed.present
          ? data.lastAccessed.value
          : this.lastAccessed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaCacheData(')
          ..write('uuid: $uuid, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('lastAccessed: $lastAccessed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(uuid, metadataJson, lastAccessed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaCacheData &&
          other.uuid == this.uuid &&
          other.metadataJson == this.metadataJson &&
          other.lastAccessed == this.lastAccessed);
}

class MediaCacheCompanion extends UpdateCompanion<MediaCacheData> {
  final Value<String> uuid;
  final Value<String> metadataJson;
  final Value<DateTime> lastAccessed;
  final Value<int> rowid;
  const MediaCacheCompanion({
    this.uuid = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.lastAccessed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaCacheCompanion.insert({
    required String uuid,
    required String metadataJson,
    this.lastAccessed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       metadataJson = Value(metadataJson);
  static Insertable<MediaCacheData> custom({
    Expression<String>? uuid,
    Expression<String>? metadataJson,
    Expression<DateTime>? lastAccessed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (lastAccessed != null) 'last_accessed': lastAccessed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaCacheCompanion copyWith({
    Value<String>? uuid,
    Value<String>? metadataJson,
    Value<DateTime>? lastAccessed,
    Value<int>? rowid,
  }) {
    return MediaCacheCompanion(
      uuid: uuid ?? this.uuid,
      metadataJson: metadataJson ?? this.metadataJson,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (lastAccessed.present) {
      map['last_accessed'] = Variable<DateTime>(lastAccessed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaCacheCompanion(')
          ..write('uuid: $uuid, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('lastAccessed: $lastAccessed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, Download> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaUuidMeta = const VerificationMeta(
    'mediaUuid',
  );
  @override
  late final GeneratedColumn<String> mediaUuid = GeneratedColumn<String>(
    'media_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES media_cache (uuid)',
    ),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DownloadTaskStatus, String>
  status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DownloadTaskStatus>($DownloadsTable.$converterstatus);
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _posterPathMeta = const VerificationMeta(
    'posterPath',
  );
  @override
  late final GeneratedColumn<String> posterPath = GeneratedColumn<String>(
    'poster_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backdropPathMeta = const VerificationMeta(
    'backdropPath',
  );
  @override
  late final GeneratedColumn<String> backdropPath = GeneratedColumn<String>(
    'backdrop_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _overviewMeta = const VerificationMeta(
    'overview',
  );
  @override
  late final GeneratedColumn<String> overview = GeneratedColumn<String>(
    'overview',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imdbIdMeta = const VerificationMeta('imdbId');
  @override
  late final GeneratedColumn<String> imdbId = GeneratedColumn<String>(
    'imdb_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voteAverageMeta = const VerificationMeta(
    'voteAverage',
  );
  @override
  late final GeneratedColumn<double> voteAverage = GeneratedColumn<double>(
    'vote_average',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _showTitleMeta = const VerificationMeta(
    'showTitle',
  );
  @override
  late final GeneratedColumn<String> showTitle = GeneratedColumn<String>(
    'show_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seasonNumberMeta = const VerificationMeta(
    'seasonNumber',
  );
  @override
  late final GeneratedColumn<int> seasonNumber = GeneratedColumn<int>(
    'season_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeNumberMeta = const VerificationMeta(
    'episodeNumber',
  );
  @override
  late final GeneratedColumn<int> episodeNumber = GeneratedColumn<int>(
    'episode_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeOverviewMeta = const VerificationMeta(
    'episodeOverview',
  );
  @override
  late final GeneratedColumn<String> episodeOverview = GeneratedColumn<String>(
    'episode_overview',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeStillPathMeta = const VerificationMeta(
    'episodeStillPath',
  );
  @override
  late final GeneratedColumn<String> episodeStillPath = GeneratedColumn<String>(
    'episode_still_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeTitleMeta = const VerificationMeta(
    'episodeTitle',
  );
  @override
  late final GeneratedColumn<String> episodeTitle = GeneratedColumn<String>(
    'episode_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    taskId,
    mediaUuid,
    filePath,
    status,
    progress,
    title,
    posterPath,
    backdropPath,
    type,
    overview,
    imdbId,
    voteAverage,
    showTitle,
    seasonNumber,
    episodeNumber,
    episodeOverview,
    episodeStillPath,
    episodeTitle,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<Download> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('media_uuid')) {
      context.handle(
        _mediaUuidMeta,
        mediaUuid.isAcceptableOrUnknown(data['media_uuid']!, _mediaUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaUuidMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('poster_path')) {
      context.handle(
        _posterPathMeta,
        posterPath.isAcceptableOrUnknown(data['poster_path']!, _posterPathMeta),
      );
    }
    if (data.containsKey('backdrop_path')) {
      context.handle(
        _backdropPathMeta,
        backdropPath.isAcceptableOrUnknown(
          data['backdrop_path']!,
          _backdropPathMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('overview')) {
      context.handle(
        _overviewMeta,
        overview.isAcceptableOrUnknown(data['overview']!, _overviewMeta),
      );
    }
    if (data.containsKey('imdb_id')) {
      context.handle(
        _imdbIdMeta,
        imdbId.isAcceptableOrUnknown(data['imdb_id']!, _imdbIdMeta),
      );
    }
    if (data.containsKey('vote_average')) {
      context.handle(
        _voteAverageMeta,
        voteAverage.isAcceptableOrUnknown(
          data['vote_average']!,
          _voteAverageMeta,
        ),
      );
    }
    if (data.containsKey('show_title')) {
      context.handle(
        _showTitleMeta,
        showTitle.isAcceptableOrUnknown(data['show_title']!, _showTitleMeta),
      );
    }
    if (data.containsKey('season_number')) {
      context.handle(
        _seasonNumberMeta,
        seasonNumber.isAcceptableOrUnknown(
          data['season_number']!,
          _seasonNumberMeta,
        ),
      );
    }
    if (data.containsKey('episode_number')) {
      context.handle(
        _episodeNumberMeta,
        episodeNumber.isAcceptableOrUnknown(
          data['episode_number']!,
          _episodeNumberMeta,
        ),
      );
    }
    if (data.containsKey('episode_overview')) {
      context.handle(
        _episodeOverviewMeta,
        episodeOverview.isAcceptableOrUnknown(
          data['episode_overview']!,
          _episodeOverviewMeta,
        ),
      );
    }
    if (data.containsKey('episode_still_path')) {
      context.handle(
        _episodeStillPathMeta,
        episodeStillPath.isAcceptableOrUnknown(
          data['episode_still_path']!,
          _episodeStillPathMeta,
        ),
      );
    }
    if (data.containsKey('episode_title')) {
      context.handle(
        _episodeTitleMeta,
        episodeTitle.isAcceptableOrUnknown(
          data['episode_title']!,
          _episodeTitleMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId};
  @override
  Download map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Download(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      mediaUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_uuid'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      status: $DownloadsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      posterPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster_path'],
      ),
      backdropPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backdrop_path'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      overview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}overview'],
      ),
      imdbId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imdb_id'],
      ),
      voteAverage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}vote_average'],
      ),
      showTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}show_title'],
      ),
      seasonNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season_number'],
      ),
      episodeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_number'],
      ),
      episodeOverview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_overview'],
      ),
      episodeStillPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_still_path'],
      ),
      episodeTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_title'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DownloadTaskStatus, String, String>
  $converterstatus = const EnumNameConverter<DownloadTaskStatus>(
    DownloadTaskStatus.values,
  );
}

class Download extends DataClass implements Insertable<Download> {
  final String taskId;
  final String mediaUuid;
  final String? filePath;
  final DownloadTaskStatus status;
  final double progress;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String type;
  final String? overview;
  final String? imdbId;
  final double? voteAverage;
  final String? showTitle;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeOverview;
  final String? episodeStillPath;
  final String? episodeTitle;
  final DateTime createdAt;
  const Download({
    required this.taskId,
    required this.mediaUuid,
    this.filePath,
    required this.status,
    required this.progress,
    required this.title,
    this.posterPath,
    this.backdropPath,
    required this.type,
    this.overview,
    this.imdbId,
    this.voteAverage,
    this.showTitle,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeOverview,
    this.episodeStillPath,
    this.episodeTitle,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<String>(taskId);
    map['media_uuid'] = Variable<String>(mediaUuid);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    {
      map['status'] = Variable<String>(
        $DownloadsTable.$converterstatus.toSql(status),
      );
    }
    map['progress'] = Variable<double>(progress);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || posterPath != null) {
      map['poster_path'] = Variable<String>(posterPath);
    }
    if (!nullToAbsent || backdropPath != null) {
      map['backdrop_path'] = Variable<String>(backdropPath);
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || overview != null) {
      map['overview'] = Variable<String>(overview);
    }
    if (!nullToAbsent || imdbId != null) {
      map['imdb_id'] = Variable<String>(imdbId);
    }
    if (!nullToAbsent || voteAverage != null) {
      map['vote_average'] = Variable<double>(voteAverage);
    }
    if (!nullToAbsent || showTitle != null) {
      map['show_title'] = Variable<String>(showTitle);
    }
    if (!nullToAbsent || seasonNumber != null) {
      map['season_number'] = Variable<int>(seasonNumber);
    }
    if (!nullToAbsent || episodeNumber != null) {
      map['episode_number'] = Variable<int>(episodeNumber);
    }
    if (!nullToAbsent || episodeOverview != null) {
      map['episode_overview'] = Variable<String>(episodeOverview);
    }
    if (!nullToAbsent || episodeStillPath != null) {
      map['episode_still_path'] = Variable<String>(episodeStillPath);
    }
    if (!nullToAbsent || episodeTitle != null) {
      map['episode_title'] = Variable<String>(episodeTitle);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      taskId: Value(taskId),
      mediaUuid: Value(mediaUuid),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      status: Value(status),
      progress: Value(progress),
      title: Value(title),
      posterPath: posterPath == null && nullToAbsent
          ? const Value.absent()
          : Value(posterPath),
      backdropPath: backdropPath == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropPath),
      type: Value(type),
      overview: overview == null && nullToAbsent
          ? const Value.absent()
          : Value(overview),
      imdbId: imdbId == null && nullToAbsent
          ? const Value.absent()
          : Value(imdbId),
      voteAverage: voteAverage == null && nullToAbsent
          ? const Value.absent()
          : Value(voteAverage),
      showTitle: showTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(showTitle),
      seasonNumber: seasonNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(seasonNumber),
      episodeNumber: episodeNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeNumber),
      episodeOverview: episodeOverview == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeOverview),
      episodeStillPath: episodeStillPath == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeStillPath),
      episodeTitle: episodeTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeTitle),
      createdAt: Value(createdAt),
    );
  }

  factory Download.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Download(
      taskId: serializer.fromJson<String>(json['taskId']),
      mediaUuid: serializer.fromJson<String>(json['mediaUuid']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      status: $DownloadsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      progress: serializer.fromJson<double>(json['progress']),
      title: serializer.fromJson<String>(json['title']),
      posterPath: serializer.fromJson<String?>(json['posterPath']),
      backdropPath: serializer.fromJson<String?>(json['backdropPath']),
      type: serializer.fromJson<String>(json['type']),
      overview: serializer.fromJson<String?>(json['overview']),
      imdbId: serializer.fromJson<String?>(json['imdbId']),
      voteAverage: serializer.fromJson<double?>(json['voteAverage']),
      showTitle: serializer.fromJson<String?>(json['showTitle']),
      seasonNumber: serializer.fromJson<int?>(json['seasonNumber']),
      episodeNumber: serializer.fromJson<int?>(json['episodeNumber']),
      episodeOverview: serializer.fromJson<String?>(json['episodeOverview']),
      episodeStillPath: serializer.fromJson<String?>(json['episodeStillPath']),
      episodeTitle: serializer.fromJson<String?>(json['episodeTitle']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<String>(taskId),
      'mediaUuid': serializer.toJson<String>(mediaUuid),
      'filePath': serializer.toJson<String?>(filePath),
      'status': serializer.toJson<String>(
        $DownloadsTable.$converterstatus.toJson(status),
      ),
      'progress': serializer.toJson<double>(progress),
      'title': serializer.toJson<String>(title),
      'posterPath': serializer.toJson<String?>(posterPath),
      'backdropPath': serializer.toJson<String?>(backdropPath),
      'type': serializer.toJson<String>(type),
      'overview': serializer.toJson<String?>(overview),
      'imdbId': serializer.toJson<String?>(imdbId),
      'voteAverage': serializer.toJson<double?>(voteAverage),
      'showTitle': serializer.toJson<String?>(showTitle),
      'seasonNumber': serializer.toJson<int?>(seasonNumber),
      'episodeNumber': serializer.toJson<int?>(episodeNumber),
      'episodeOverview': serializer.toJson<String?>(episodeOverview),
      'episodeStillPath': serializer.toJson<String?>(episodeStillPath),
      'episodeTitle': serializer.toJson<String?>(episodeTitle),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Download copyWith({
    String? taskId,
    String? mediaUuid,
    Value<String?> filePath = const Value.absent(),
    DownloadTaskStatus? status,
    double? progress,
    String? title,
    Value<String?> posterPath = const Value.absent(),
    Value<String?> backdropPath = const Value.absent(),
    String? type,
    Value<String?> overview = const Value.absent(),
    Value<String?> imdbId = const Value.absent(),
    Value<double?> voteAverage = const Value.absent(),
    Value<String?> showTitle = const Value.absent(),
    Value<int?> seasonNumber = const Value.absent(),
    Value<int?> episodeNumber = const Value.absent(),
    Value<String?> episodeOverview = const Value.absent(),
    Value<String?> episodeStillPath = const Value.absent(),
    Value<String?> episodeTitle = const Value.absent(),
    DateTime? createdAt,
  }) => Download(
    taskId: taskId ?? this.taskId,
    mediaUuid: mediaUuid ?? this.mediaUuid,
    filePath: filePath.present ? filePath.value : this.filePath,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    title: title ?? this.title,
    posterPath: posterPath.present ? posterPath.value : this.posterPath,
    backdropPath: backdropPath.present ? backdropPath.value : this.backdropPath,
    type: type ?? this.type,
    overview: overview.present ? overview.value : this.overview,
    imdbId: imdbId.present ? imdbId.value : this.imdbId,
    voteAverage: voteAverage.present ? voteAverage.value : this.voteAverage,
    showTitle: showTitle.present ? showTitle.value : this.showTitle,
    seasonNumber: seasonNumber.present ? seasonNumber.value : this.seasonNumber,
    episodeNumber: episodeNumber.present
        ? episodeNumber.value
        : this.episodeNumber,
    episodeOverview: episodeOverview.present
        ? episodeOverview.value
        : this.episodeOverview,
    episodeStillPath: episodeStillPath.present
        ? episodeStillPath.value
        : this.episodeStillPath,
    episodeTitle: episodeTitle.present ? episodeTitle.value : this.episodeTitle,
    createdAt: createdAt ?? this.createdAt,
  );
  Download copyWithCompanion(DownloadsCompanion data) {
    return Download(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      mediaUuid: data.mediaUuid.present ? data.mediaUuid.value : this.mediaUuid,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      title: data.title.present ? data.title.value : this.title,
      posterPath: data.posterPath.present
          ? data.posterPath.value
          : this.posterPath,
      backdropPath: data.backdropPath.present
          ? data.backdropPath.value
          : this.backdropPath,
      type: data.type.present ? data.type.value : this.type,
      overview: data.overview.present ? data.overview.value : this.overview,
      imdbId: data.imdbId.present ? data.imdbId.value : this.imdbId,
      voteAverage: data.voteAverage.present
          ? data.voteAverage.value
          : this.voteAverage,
      showTitle: data.showTitle.present ? data.showTitle.value : this.showTitle,
      seasonNumber: data.seasonNumber.present
          ? data.seasonNumber.value
          : this.seasonNumber,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      episodeOverview: data.episodeOverview.present
          ? data.episodeOverview.value
          : this.episodeOverview,
      episodeStillPath: data.episodeStillPath.present
          ? data.episodeStillPath.value
          : this.episodeStillPath,
      episodeTitle: data.episodeTitle.present
          ? data.episodeTitle.value
          : this.episodeTitle,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Download(')
          ..write('taskId: $taskId, ')
          ..write('mediaUuid: $mediaUuid, ')
          ..write('filePath: $filePath, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('backdropPath: $backdropPath, ')
          ..write('type: $type, ')
          ..write('overview: $overview, ')
          ..write('imdbId: $imdbId, ')
          ..write('voteAverage: $voteAverage, ')
          ..write('showTitle: $showTitle, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('episodeOverview: $episodeOverview, ')
          ..write('episodeStillPath: $episodeStillPath, ')
          ..write('episodeTitle: $episodeTitle, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    taskId,
    mediaUuid,
    filePath,
    status,
    progress,
    title,
    posterPath,
    backdropPath,
    type,
    overview,
    imdbId,
    voteAverage,
    showTitle,
    seasonNumber,
    episodeNumber,
    episodeOverview,
    episodeStillPath,
    episodeTitle,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Download &&
          other.taskId == this.taskId &&
          other.mediaUuid == this.mediaUuid &&
          other.filePath == this.filePath &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.title == this.title &&
          other.posterPath == this.posterPath &&
          other.backdropPath == this.backdropPath &&
          other.type == this.type &&
          other.overview == this.overview &&
          other.imdbId == this.imdbId &&
          other.voteAverage == this.voteAverage &&
          other.showTitle == this.showTitle &&
          other.seasonNumber == this.seasonNumber &&
          other.episodeNumber == this.episodeNumber &&
          other.episodeOverview == this.episodeOverview &&
          other.episodeStillPath == this.episodeStillPath &&
          other.episodeTitle == this.episodeTitle &&
          other.createdAt == this.createdAt);
}

class DownloadsCompanion extends UpdateCompanion<Download> {
  final Value<String> taskId;
  final Value<String> mediaUuid;
  final Value<String?> filePath;
  final Value<DownloadTaskStatus> status;
  final Value<double> progress;
  final Value<String> title;
  final Value<String?> posterPath;
  final Value<String?> backdropPath;
  final Value<String> type;
  final Value<String?> overview;
  final Value<String?> imdbId;
  final Value<double?> voteAverage;
  final Value<String?> showTitle;
  final Value<int?> seasonNumber;
  final Value<int?> episodeNumber;
  final Value<String?> episodeOverview;
  final Value<String?> episodeStillPath;
  final Value<String?> episodeTitle;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DownloadsCompanion({
    this.taskId = const Value.absent(),
    this.mediaUuid = const Value.absent(),
    this.filePath = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.title = const Value.absent(),
    this.posterPath = const Value.absent(),
    this.backdropPath = const Value.absent(),
    this.type = const Value.absent(),
    this.overview = const Value.absent(),
    this.imdbId = const Value.absent(),
    this.voteAverage = const Value.absent(),
    this.showTitle = const Value.absent(),
    this.seasonNumber = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.episodeOverview = const Value.absent(),
    this.episodeStillPath = const Value.absent(),
    this.episodeTitle = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadsCompanion.insert({
    required String taskId,
    required String mediaUuid,
    this.filePath = const Value.absent(),
    required DownloadTaskStatus status,
    this.progress = const Value.absent(),
    required String title,
    this.posterPath = const Value.absent(),
    this.backdropPath = const Value.absent(),
    required String type,
    this.overview = const Value.absent(),
    this.imdbId = const Value.absent(),
    this.voteAverage = const Value.absent(),
    this.showTitle = const Value.absent(),
    this.seasonNumber = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.episodeOverview = const Value.absent(),
    this.episodeStillPath = const Value.absent(),
    this.episodeTitle = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       mediaUuid = Value(mediaUuid),
       status = Value(status),
       title = Value(title),
       type = Value(type);
  static Insertable<Download> custom({
    Expression<String>? taskId,
    Expression<String>? mediaUuid,
    Expression<String>? filePath,
    Expression<String>? status,
    Expression<double>? progress,
    Expression<String>? title,
    Expression<String>? posterPath,
    Expression<String>? backdropPath,
    Expression<String>? type,
    Expression<String>? overview,
    Expression<String>? imdbId,
    Expression<double>? voteAverage,
    Expression<String>? showTitle,
    Expression<int>? seasonNumber,
    Expression<int>? episodeNumber,
    Expression<String>? episodeOverview,
    Expression<String>? episodeStillPath,
    Expression<String>? episodeTitle,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (mediaUuid != null) 'media_uuid': mediaUuid,
      if (filePath != null) 'file_path': filePath,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (title != null) 'title': title,
      if (posterPath != null) 'poster_path': posterPath,
      if (backdropPath != null) 'backdrop_path': backdropPath,
      if (type != null) 'type': type,
      if (overview != null) 'overview': overview,
      if (imdbId != null) 'imdb_id': imdbId,
      if (voteAverage != null) 'vote_average': voteAverage,
      if (showTitle != null) 'show_title': showTitle,
      if (seasonNumber != null) 'season_number': seasonNumber,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (episodeOverview != null) 'episode_overview': episodeOverview,
      if (episodeStillPath != null) 'episode_still_path': episodeStillPath,
      if (episodeTitle != null) 'episode_title': episodeTitle,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadsCompanion copyWith({
    Value<String>? taskId,
    Value<String>? mediaUuid,
    Value<String?>? filePath,
    Value<DownloadTaskStatus>? status,
    Value<double>? progress,
    Value<String>? title,
    Value<String?>? posterPath,
    Value<String?>? backdropPath,
    Value<String>? type,
    Value<String?>? overview,
    Value<String?>? imdbId,
    Value<double?>? voteAverage,
    Value<String?>? showTitle,
    Value<int?>? seasonNumber,
    Value<int?>? episodeNumber,
    Value<String?>? episodeOverview,
    Value<String?>? episodeStillPath,
    Value<String?>? episodeTitle,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return DownloadsCompanion(
      taskId: taskId ?? this.taskId,
      mediaUuid: mediaUuid ?? this.mediaUuid,
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      type: type ?? this.type,
      overview: overview ?? this.overview,
      imdbId: imdbId ?? this.imdbId,
      voteAverage: voteAverage ?? this.voteAverage,
      showTitle: showTitle ?? this.showTitle,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      episodeOverview: episodeOverview ?? this.episodeOverview,
      episodeStillPath: episodeStillPath ?? this.episodeStillPath,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (mediaUuid.present) {
      map['media_uuid'] = Variable<String>(mediaUuid.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $DownloadsTable.$converterstatus.toSql(status.value),
      );
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (posterPath.present) {
      map['poster_path'] = Variable<String>(posterPath.value);
    }
    if (backdropPath.present) {
      map['backdrop_path'] = Variable<String>(backdropPath.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (overview.present) {
      map['overview'] = Variable<String>(overview.value);
    }
    if (imdbId.present) {
      map['imdb_id'] = Variable<String>(imdbId.value);
    }
    if (voteAverage.present) {
      map['vote_average'] = Variable<double>(voteAverage.value);
    }
    if (showTitle.present) {
      map['show_title'] = Variable<String>(showTitle.value);
    }
    if (seasonNumber.present) {
      map['season_number'] = Variable<int>(seasonNumber.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<int>(episodeNumber.value);
    }
    if (episodeOverview.present) {
      map['episode_overview'] = Variable<String>(episodeOverview.value);
    }
    if (episodeStillPath.present) {
      map['episode_still_path'] = Variable<String>(episodeStillPath.value);
    }
    if (episodeTitle.present) {
      map['episode_title'] = Variable<String>(episodeTitle.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('taskId: $taskId, ')
          ..write('mediaUuid: $mediaUuid, ')
          ..write('filePath: $filePath, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('backdropPath: $backdropPath, ')
          ..write('type: $type, ')
          ..write('overview: $overview, ')
          ..write('imdbId: $imdbId, ')
          ..write('voteAverage: $voteAverage, ')
          ..write('showTitle: $showTitle, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('episodeOverview: $episodeOverview, ')
          ..write('episodeStillPath: $episodeStillPath, ')
          ..write('episodeTitle: $episodeTitle, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MediaCacheTable mediaCache = $MediaCacheTable(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [mediaCache, downloads];
}

typedef $$MediaCacheTableCreateCompanionBuilder =
    MediaCacheCompanion Function({
      required String uuid,
      required String metadataJson,
      Value<DateTime> lastAccessed,
      Value<int> rowid,
    });
typedef $$MediaCacheTableUpdateCompanionBuilder =
    MediaCacheCompanion Function({
      Value<String> uuid,
      Value<String> metadataJson,
      Value<DateTime> lastAccessed,
      Value<int> rowid,
    });

final class $$MediaCacheTableReferences
    extends BaseReferences<_$AppDatabase, $MediaCacheTable, MediaCacheData> {
  $$MediaCacheTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DownloadsTable, List<Download>>
  _downloadsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.downloads,
    aliasName: $_aliasNameGenerator(db.mediaCache.uuid, db.downloads.mediaUuid),
  );

  $$DownloadsTableProcessedTableManager get downloadsRefs {
    final manager = $$DownloadsTableTableManager(
      $_db,
      $_db.downloads,
    ).filter((f) => f.mediaUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!));

    final cache = $_typedResult.readTableOrNull(_downloadsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MediaCacheTableFilterComposer
    extends Composer<_$AppDatabase, $MediaCacheTable> {
  $$MediaCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAccessed => $composableBuilder(
    column: $table.lastAccessed,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> downloadsRefs(
    Expression<bool> Function($$DownloadsTableFilterComposer f) f,
  ) {
    final $$DownloadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.mediaUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableFilterComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MediaCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaCacheTable> {
  $$MediaCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAccessed => $composableBuilder(
    column: $table.lastAccessed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaCacheTable> {
  $$MediaCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAccessed => $composableBuilder(
    column: $table.lastAccessed,
    builder: (column) => column,
  );

  Expression<T> downloadsRefs<T extends Object>(
    Expression<T> Function($$DownloadsTableAnnotationComposer a) f,
  ) {
    final $$DownloadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.mediaUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableAnnotationComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MediaCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MediaCacheTable,
          MediaCacheData,
          $$MediaCacheTableFilterComposer,
          $$MediaCacheTableOrderingComposer,
          $$MediaCacheTableAnnotationComposer,
          $$MediaCacheTableCreateCompanionBuilder,
          $$MediaCacheTableUpdateCompanionBuilder,
          (MediaCacheData, $$MediaCacheTableReferences),
          MediaCacheData,
          PrefetchHooks Function({bool downloadsRefs})
        > {
  $$MediaCacheTableTableManager(_$AppDatabase db, $MediaCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                Value<DateTime> lastAccessed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaCacheCompanion(
                uuid: uuid,
                metadataJson: metadataJson,
                lastAccessed: lastAccessed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String metadataJson,
                Value<DateTime> lastAccessed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaCacheCompanion.insert(
                uuid: uuid,
                metadataJson: metadataJson,
                lastAccessed: lastAccessed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MediaCacheTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({downloadsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (downloadsRefs) db.downloads],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (downloadsRefs)
                    await $_getPrefetchedData<
                      MediaCacheData,
                      $MediaCacheTable,
                      Download
                    >(
                      currentTable: table,
                      referencedTable: $$MediaCacheTableReferences
                          ._downloadsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MediaCacheTableReferences(
                            db,
                            table,
                            p0,
                          ).downloadsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.mediaUuid == item.uuid,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MediaCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MediaCacheTable,
      MediaCacheData,
      $$MediaCacheTableFilterComposer,
      $$MediaCacheTableOrderingComposer,
      $$MediaCacheTableAnnotationComposer,
      $$MediaCacheTableCreateCompanionBuilder,
      $$MediaCacheTableUpdateCompanionBuilder,
      (MediaCacheData, $$MediaCacheTableReferences),
      MediaCacheData,
      PrefetchHooks Function({bool downloadsRefs})
    >;
typedef $$DownloadsTableCreateCompanionBuilder =
    DownloadsCompanion Function({
      required String taskId,
      required String mediaUuid,
      Value<String?> filePath,
      required DownloadTaskStatus status,
      Value<double> progress,
      required String title,
      Value<String?> posterPath,
      Value<String?> backdropPath,
      required String type,
      Value<String?> overview,
      Value<String?> imdbId,
      Value<double?> voteAverage,
      Value<String?> showTitle,
      Value<int?> seasonNumber,
      Value<int?> episodeNumber,
      Value<String?> episodeOverview,
      Value<String?> episodeStillPath,
      Value<String?> episodeTitle,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$DownloadsTableUpdateCompanionBuilder =
    DownloadsCompanion Function({
      Value<String> taskId,
      Value<String> mediaUuid,
      Value<String?> filePath,
      Value<DownloadTaskStatus> status,
      Value<double> progress,
      Value<String> title,
      Value<String?> posterPath,
      Value<String?> backdropPath,
      Value<String> type,
      Value<String?> overview,
      Value<String?> imdbId,
      Value<double?> voteAverage,
      Value<String?> showTitle,
      Value<int?> seasonNumber,
      Value<int?> episodeNumber,
      Value<String?> episodeOverview,
      Value<String?> episodeStillPath,
      Value<String?> episodeTitle,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$DownloadsTableReferences
    extends BaseReferences<_$AppDatabase, $DownloadsTable, Download> {
  $$DownloadsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MediaCacheTable _mediaUuidTable(_$AppDatabase db) =>
      db.mediaCache.createAlias(
        $_aliasNameGenerator(db.downloads.mediaUuid, db.mediaCache.uuid),
      );

  $$MediaCacheTableProcessedTableManager get mediaUuid {
    final $_column = $_itemColumn<String>('media_uuid')!;

    final manager = $$MediaCacheTableTableManager(
      $_db,
      $_db.mediaCache,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mediaUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DownloadsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DownloadTaskStatus, DownloadTaskStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posterPath => $composableBuilder(
    column: $table.posterPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backdropPath => $composableBuilder(
    column: $table.backdropPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overview => $composableBuilder(
    column: $table.overview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imdbId => $composableBuilder(
    column: $table.imdbId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get voteAverage => $composableBuilder(
    column: $table.voteAverage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get showTitle => $composableBuilder(
    column: $table.showTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeOverview => $composableBuilder(
    column: $table.episodeOverview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeStillPath => $composableBuilder(
    column: $table.episodeStillPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeTitle => $composableBuilder(
    column: $table.episodeTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MediaCacheTableFilterComposer get mediaUuid {
    final $$MediaCacheTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaUuid,
      referencedTable: $db.mediaCache,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaCacheTableFilterComposer(
            $db: $db,
            $table: $db.mediaCache,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posterPath => $composableBuilder(
    column: $table.posterPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backdropPath => $composableBuilder(
    column: $table.backdropPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overview => $composableBuilder(
    column: $table.overview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imdbId => $composableBuilder(
    column: $table.imdbId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get voteAverage => $composableBuilder(
    column: $table.voteAverage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get showTitle => $composableBuilder(
    column: $table.showTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeOverview => $composableBuilder(
    column: $table.episodeOverview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeStillPath => $composableBuilder(
    column: $table.episodeStillPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeTitle => $composableBuilder(
    column: $table.episodeTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MediaCacheTableOrderingComposer get mediaUuid {
    final $$MediaCacheTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaUuid,
      referencedTable: $db.mediaCache,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaCacheTableOrderingComposer(
            $db: $db,
            $table: $db.mediaCache,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DownloadTaskStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get posterPath => $composableBuilder(
    column: $table.posterPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backdropPath => $composableBuilder(
    column: $table.backdropPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get overview =>
      $composableBuilder(column: $table.overview, builder: (column) => column);

  GeneratedColumn<String> get imdbId =>
      $composableBuilder(column: $table.imdbId, builder: (column) => column);

  GeneratedColumn<double> get voteAverage => $composableBuilder(
    column: $table.voteAverage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get showTitle =>
      $composableBuilder(column: $table.showTitle, builder: (column) => column);

  GeneratedColumn<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get episodeOverview => $composableBuilder(
    column: $table.episodeOverview,
    builder: (column) => column,
  );

  GeneratedColumn<String> get episodeStillPath => $composableBuilder(
    column: $table.episodeStillPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get episodeTitle => $composableBuilder(
    column: $table.episodeTitle,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MediaCacheTableAnnotationComposer get mediaUuid {
    final $$MediaCacheTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaUuid,
      referencedTable: $db.mediaCache,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaCacheTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaCache,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadsTable,
          Download,
          $$DownloadsTableFilterComposer,
          $$DownloadsTableOrderingComposer,
          $$DownloadsTableAnnotationComposer,
          $$DownloadsTableCreateCompanionBuilder,
          $$DownloadsTableUpdateCompanionBuilder,
          (Download, $$DownloadsTableReferences),
          Download,
          PrefetchHooks Function({bool mediaUuid})
        > {
  $$DownloadsTableTableManager(_$AppDatabase db, $DownloadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> taskId = const Value.absent(),
                Value<String> mediaUuid = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<DownloadTaskStatus> status = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> posterPath = const Value.absent(),
                Value<String?> backdropPath = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> overview = const Value.absent(),
                Value<String?> imdbId = const Value.absent(),
                Value<double?> voteAverage = const Value.absent(),
                Value<String?> showTitle = const Value.absent(),
                Value<int?> seasonNumber = const Value.absent(),
                Value<int?> episodeNumber = const Value.absent(),
                Value<String?> episodeOverview = const Value.absent(),
                Value<String?> episodeStillPath = const Value.absent(),
                Value<String?> episodeTitle = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadsCompanion(
                taskId: taskId,
                mediaUuid: mediaUuid,
                filePath: filePath,
                status: status,
                progress: progress,
                title: title,
                posterPath: posterPath,
                backdropPath: backdropPath,
                type: type,
                overview: overview,
                imdbId: imdbId,
                voteAverage: voteAverage,
                showTitle: showTitle,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber,
                episodeOverview: episodeOverview,
                episodeStillPath: episodeStillPath,
                episodeTitle: episodeTitle,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String taskId,
                required String mediaUuid,
                Value<String?> filePath = const Value.absent(),
                required DownloadTaskStatus status,
                Value<double> progress = const Value.absent(),
                required String title,
                Value<String?> posterPath = const Value.absent(),
                Value<String?> backdropPath = const Value.absent(),
                required String type,
                Value<String?> overview = const Value.absent(),
                Value<String?> imdbId = const Value.absent(),
                Value<double?> voteAverage = const Value.absent(),
                Value<String?> showTitle = const Value.absent(),
                Value<int?> seasonNumber = const Value.absent(),
                Value<int?> episodeNumber = const Value.absent(),
                Value<String?> episodeOverview = const Value.absent(),
                Value<String?> episodeStillPath = const Value.absent(),
                Value<String?> episodeTitle = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadsCompanion.insert(
                taskId: taskId,
                mediaUuid: mediaUuid,
                filePath: filePath,
                status: status,
                progress: progress,
                title: title,
                posterPath: posterPath,
                backdropPath: backdropPath,
                type: type,
                overview: overview,
                imdbId: imdbId,
                voteAverage: voteAverage,
                showTitle: showTitle,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber,
                episodeOverview: episodeOverview,
                episodeStillPath: episodeStillPath,
                episodeTitle: episodeTitle,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mediaUuid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mediaUuid) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mediaUuid,
                                referencedTable: $$DownloadsTableReferences
                                    ._mediaUuidTable(db),
                                referencedColumn: $$DownloadsTableReferences
                                    ._mediaUuidTable(db)
                                    .uuid,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadsTable,
      Download,
      $$DownloadsTableFilterComposer,
      $$DownloadsTableOrderingComposer,
      $$DownloadsTableAnnotationComposer,
      $$DownloadsTableCreateCompanionBuilder,
      $$DownloadsTableUpdateCompanionBuilder,
      (Download, $$DownloadsTableReferences),
      Download,
      PrefetchHooks Function({bool mediaUuid})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MediaCacheTableTableManager get mediaCache =>
      $$MediaCacheTableTableManager(_db, _db.mediaCache);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db, _db.downloads);
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDatabase)
const appDatabaseProvider = AppDatabaseProvider._();

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  const AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'8c69eb46d45206533c176c88a926608e79ca927d';
