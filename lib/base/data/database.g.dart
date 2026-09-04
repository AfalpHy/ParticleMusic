// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MetadataItemsTable extends MetadataItems
    with TableInfo<$MetadataItemsTable, MetadataItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetadataItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedMeta = const VerificationMeta(
    'modified',
  );
  @override
  late final GeneratedColumn<int> modified = GeneratedColumn<int>(
    'modified',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumArtistMeta = const VerificationMeta(
    'albumArtist',
  );
  @override
  late final GeneratedColumn<String> albumArtist = GeneratedColumn<String>(
    'album_artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackMeta = const VerificationMeta('track');
  @override
  late final GeneratedColumn<int> track = GeneratedColumn<int>(
    'track',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discMeta = const VerificationMeta('disc');
  @override
  late final GeneratedColumn<int> disc = GeneratedColumn<int>(
    'disc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bitrateMeta = const VerificationMeta(
    'bitrate',
  );
  @override
  late final GeneratedColumn<int> bitrate = GeneratedColumn<int>(
    'bitrate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _samplerateMeta = const VerificationMeta(
    'samplerate',
  );
  @override
  late final GeneratedColumn<int> samplerate = GeneratedColumn<int>(
    'samplerate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lyricsMeta = const VerificationMeta('lyrics');
  @override
  late final GeneratedColumn<String> lyrics = GeneratedColumn<String>(
    'lyrics',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _playCountMeta = const VerificationMeta(
    'playCount',
  );
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
    'play_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPlayedMeta = const VerificationMeta(
    'lastPlayed',
  );
  @override
  late final GeneratedColumn<int> lastPlayed = GeneratedColumn<int>(
    'last_played',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    modified,
    format,
    title,
    artist,
    album,
    albumArtist,
    genre,
    year,
    track,
    disc,
    bitrate,
    samplerate,
    duration,
    lyrics,
    playCount,
    lastPlayed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'metadata_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetadataItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('modified')) {
      context.handle(
        _modifiedMeta,
        modified.isAcceptableOrUnknown(data['modified']!, _modifiedMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('album_artist')) {
      context.handle(
        _albumArtistMeta,
        albumArtist.isAcceptableOrUnknown(
          data['album_artist']!,
          _albumArtistMeta,
        ),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('track')) {
      context.handle(
        _trackMeta,
        track.isAcceptableOrUnknown(data['track']!, _trackMeta),
      );
    }
    if (data.containsKey('disc')) {
      context.handle(
        _discMeta,
        disc.isAcceptableOrUnknown(data['disc']!, _discMeta),
      );
    }
    if (data.containsKey('bitrate')) {
      context.handle(
        _bitrateMeta,
        bitrate.isAcceptableOrUnknown(data['bitrate']!, _bitrateMeta),
      );
    }
    if (data.containsKey('samplerate')) {
      context.handle(
        _samplerateMeta,
        samplerate.isAcceptableOrUnknown(data['samplerate']!, _samplerateMeta),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('lyrics')) {
      context.handle(
        _lyricsMeta,
        lyrics.isAcceptableOrUnknown(data['lyrics']!, _lyricsMeta),
      );
    }
    if (data.containsKey('play_count')) {
      context.handle(
        _playCountMeta,
        playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta),
      );
    }
    if (data.containsKey('last_played')) {
      context.handle(
        _lastPlayedMeta,
        lastPlayed.isAcceptableOrUnknown(data['last_played']!, _lastPlayedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MetadataItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetadataItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      modified: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      ),
      albumArtist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_artist'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      track: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track'],
      ),
      disc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}disc'],
      ),
      bitrate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bitrate'],
      ),
      samplerate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}samplerate'],
      ),
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      ),
      lyrics: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lyrics'],
      ),
      playCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}play_count'],
      )!,
      lastPlayed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_played'],
      ),
    );
  }

  @override
  $MetadataItemsTable createAlias(String alias) {
    return $MetadataItemsTable(attachedDatabase, alias);
  }
}

class MetadataItem extends DataClass implements Insertable<MetadataItem> {
  final String id;
  final int? modified;
  final String? format;
  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? genre;
  final int? year;
  final int? track;
  final int? disc;
  final int? bitrate;
  final int? samplerate;
  final int? duration;
  final String? lyrics;
  final int playCount;
  final int? lastPlayed;
  const MetadataItem({
    required this.id,
    this.modified,
    this.format,
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.genre,
    this.year,
    this.track,
    this.disc,
    this.bitrate,
    this.samplerate,
    this.duration,
    this.lyrics,
    required this.playCount,
    this.lastPlayed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || modified != null) {
      map['modified'] = Variable<int>(modified);
    }
    if (!nullToAbsent || format != null) {
      map['format'] = Variable<String>(format);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    if (!nullToAbsent || albumArtist != null) {
      map['album_artist'] = Variable<String>(albumArtist);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || track != null) {
      map['track'] = Variable<int>(track);
    }
    if (!nullToAbsent || disc != null) {
      map['disc'] = Variable<int>(disc);
    }
    if (!nullToAbsent || bitrate != null) {
      map['bitrate'] = Variable<int>(bitrate);
    }
    if (!nullToAbsent || samplerate != null) {
      map['samplerate'] = Variable<int>(samplerate);
    }
    if (!nullToAbsent || duration != null) {
      map['duration'] = Variable<int>(duration);
    }
    if (!nullToAbsent || lyrics != null) {
      map['lyrics'] = Variable<String>(lyrics);
    }
    map['play_count'] = Variable<int>(playCount);
    if (!nullToAbsent || lastPlayed != null) {
      map['last_played'] = Variable<int>(lastPlayed);
    }
    return map;
  }

  MetadataItemsCompanion toCompanion(bool nullToAbsent) {
    return MetadataItemsCompanion(
      id: Value(id),
      modified: modified == null && nullToAbsent
          ? const Value.absent()
          : Value(modified),
      format: format == null && nullToAbsent
          ? const Value.absent()
          : Value(format),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      album: album == null && nullToAbsent
          ? const Value.absent()
          : Value(album),
      albumArtist: albumArtist == null && nullToAbsent
          ? const Value.absent()
          : Value(albumArtist),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      track: track == null && nullToAbsent
          ? const Value.absent()
          : Value(track),
      disc: disc == null && nullToAbsent ? const Value.absent() : Value(disc),
      bitrate: bitrate == null && nullToAbsent
          ? const Value.absent()
          : Value(bitrate),
      samplerate: samplerate == null && nullToAbsent
          ? const Value.absent()
          : Value(samplerate),
      duration: duration == null && nullToAbsent
          ? const Value.absent()
          : Value(duration),
      lyrics: lyrics == null && nullToAbsent
          ? const Value.absent()
          : Value(lyrics),
      playCount: Value(playCount),
      lastPlayed: lastPlayed == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayed),
    );
  }

  factory MetadataItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetadataItem(
      id: serializer.fromJson<String>(json['id']),
      modified: serializer.fromJson<int?>(json['modified']),
      format: serializer.fromJson<String?>(json['format']),
      title: serializer.fromJson<String?>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
      albumArtist: serializer.fromJson<String?>(json['albumArtist']),
      genre: serializer.fromJson<String?>(json['genre']),
      year: serializer.fromJson<int?>(json['year']),
      track: serializer.fromJson<int?>(json['track']),
      disc: serializer.fromJson<int?>(json['disc']),
      bitrate: serializer.fromJson<int?>(json['bitrate']),
      samplerate: serializer.fromJson<int?>(json['samplerate']),
      duration: serializer.fromJson<int?>(json['duration']),
      lyrics: serializer.fromJson<String?>(json['lyrics']),
      playCount: serializer.fromJson<int>(json['playCount']),
      lastPlayed: serializer.fromJson<int?>(json['lastPlayed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'modified': serializer.toJson<int?>(modified),
      'format': serializer.toJson<String?>(format),
      'title': serializer.toJson<String?>(title),
      'artist': serializer.toJson<String?>(artist),
      'album': serializer.toJson<String?>(album),
      'albumArtist': serializer.toJson<String?>(albumArtist),
      'genre': serializer.toJson<String?>(genre),
      'year': serializer.toJson<int?>(year),
      'track': serializer.toJson<int?>(track),
      'disc': serializer.toJson<int?>(disc),
      'bitrate': serializer.toJson<int?>(bitrate),
      'samplerate': serializer.toJson<int?>(samplerate),
      'duration': serializer.toJson<int?>(duration),
      'lyrics': serializer.toJson<String?>(lyrics),
      'playCount': serializer.toJson<int>(playCount),
      'lastPlayed': serializer.toJson<int?>(lastPlayed),
    };
  }

  MetadataItem copyWith({
    String? id,
    Value<int?> modified = const Value.absent(),
    Value<String?> format = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> artist = const Value.absent(),
    Value<String?> album = const Value.absent(),
    Value<String?> albumArtist = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<int?> track = const Value.absent(),
    Value<int?> disc = const Value.absent(),
    Value<int?> bitrate = const Value.absent(),
    Value<int?> samplerate = const Value.absent(),
    Value<int?> duration = const Value.absent(),
    Value<String?> lyrics = const Value.absent(),
    int? playCount,
    Value<int?> lastPlayed = const Value.absent(),
  }) => MetadataItem(
    id: id ?? this.id,
    modified: modified.present ? modified.value : this.modified,
    format: format.present ? format.value : this.format,
    title: title.present ? title.value : this.title,
    artist: artist.present ? artist.value : this.artist,
    album: album.present ? album.value : this.album,
    albumArtist: albumArtist.present ? albumArtist.value : this.albumArtist,
    genre: genre.present ? genre.value : this.genre,
    year: year.present ? year.value : this.year,
    track: track.present ? track.value : this.track,
    disc: disc.present ? disc.value : this.disc,
    bitrate: bitrate.present ? bitrate.value : this.bitrate,
    samplerate: samplerate.present ? samplerate.value : this.samplerate,
    duration: duration.present ? duration.value : this.duration,
    lyrics: lyrics.present ? lyrics.value : this.lyrics,
    playCount: playCount ?? this.playCount,
    lastPlayed: lastPlayed.present ? lastPlayed.value : this.lastPlayed,
  );
  MetadataItem copyWithCompanion(MetadataItemsCompanion data) {
    return MetadataItem(
      id: data.id.present ? data.id.value : this.id,
      modified: data.modified.present ? data.modified.value : this.modified,
      format: data.format.present ? data.format.value : this.format,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      albumArtist: data.albumArtist.present
          ? data.albumArtist.value
          : this.albumArtist,
      genre: data.genre.present ? data.genre.value : this.genre,
      year: data.year.present ? data.year.value : this.year,
      track: data.track.present ? data.track.value : this.track,
      disc: data.disc.present ? data.disc.value : this.disc,
      bitrate: data.bitrate.present ? data.bitrate.value : this.bitrate,
      samplerate: data.samplerate.present
          ? data.samplerate.value
          : this.samplerate,
      duration: data.duration.present ? data.duration.value : this.duration,
      lyrics: data.lyrics.present ? data.lyrics.value : this.lyrics,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
      lastPlayed: data.lastPlayed.present
          ? data.lastPlayed.value
          : this.lastPlayed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetadataItem(')
          ..write('id: $id, ')
          ..write('modified: $modified, ')
          ..write('format: $format, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('genre: $genre, ')
          ..write('year: $year, ')
          ..write('track: $track, ')
          ..write('disc: $disc, ')
          ..write('bitrate: $bitrate, ')
          ..write('samplerate: $samplerate, ')
          ..write('duration: $duration, ')
          ..write('lyrics: $lyrics, ')
          ..write('playCount: $playCount, ')
          ..write('lastPlayed: $lastPlayed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    modified,
    format,
    title,
    artist,
    album,
    albumArtist,
    genre,
    year,
    track,
    disc,
    bitrate,
    samplerate,
    duration,
    lyrics,
    playCount,
    lastPlayed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetadataItem &&
          other.id == this.id &&
          other.modified == this.modified &&
          other.format == this.format &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.albumArtist == this.albumArtist &&
          other.genre == this.genre &&
          other.year == this.year &&
          other.track == this.track &&
          other.disc == this.disc &&
          other.bitrate == this.bitrate &&
          other.samplerate == this.samplerate &&
          other.duration == this.duration &&
          other.lyrics == this.lyrics &&
          other.playCount == this.playCount &&
          other.lastPlayed == this.lastPlayed);
}

class MetadataItemsCompanion extends UpdateCompanion<MetadataItem> {
  final Value<String> id;
  final Value<int?> modified;
  final Value<String?> format;
  final Value<String?> title;
  final Value<String?> artist;
  final Value<String?> album;
  final Value<String?> albumArtist;
  final Value<String?> genre;
  final Value<int?> year;
  final Value<int?> track;
  final Value<int?> disc;
  final Value<int?> bitrate;
  final Value<int?> samplerate;
  final Value<int?> duration;
  final Value<String?> lyrics;
  final Value<int> playCount;
  final Value<int?> lastPlayed;
  final Value<int> rowid;
  const MetadataItemsCompanion({
    this.id = const Value.absent(),
    this.modified = const Value.absent(),
    this.format = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.genre = const Value.absent(),
    this.year = const Value.absent(),
    this.track = const Value.absent(),
    this.disc = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.samplerate = const Value.absent(),
    this.duration = const Value.absent(),
    this.lyrics = const Value.absent(),
    this.playCount = const Value.absent(),
    this.lastPlayed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetadataItemsCompanion.insert({
    required String id,
    this.modified = const Value.absent(),
    this.format = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.genre = const Value.absent(),
    this.year = const Value.absent(),
    this.track = const Value.absent(),
    this.disc = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.samplerate = const Value.absent(),
    this.duration = const Value.absent(),
    this.lyrics = const Value.absent(),
    this.playCount = const Value.absent(),
    this.lastPlayed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<MetadataItem> custom({
    Expression<String>? id,
    Expression<int>? modified,
    Expression<String>? format,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? albumArtist,
    Expression<String>? genre,
    Expression<int>? year,
    Expression<int>? track,
    Expression<int>? disc,
    Expression<int>? bitrate,
    Expression<int>? samplerate,
    Expression<int>? duration,
    Expression<String>? lyrics,
    Expression<int>? playCount,
    Expression<int>? lastPlayed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (modified != null) 'modified': modified,
      if (format != null) 'format': format,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (albumArtist != null) 'album_artist': albumArtist,
      if (genre != null) 'genre': genre,
      if (year != null) 'year': year,
      if (track != null) 'track': track,
      if (disc != null) 'disc': disc,
      if (bitrate != null) 'bitrate': bitrate,
      if (samplerate != null) 'samplerate': samplerate,
      if (duration != null) 'duration': duration,
      if (lyrics != null) 'lyrics': lyrics,
      if (playCount != null) 'play_count': playCount,
      if (lastPlayed != null) 'last_played': lastPlayed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetadataItemsCompanion copyWith({
    Value<String>? id,
    Value<int?>? modified,
    Value<String?>? format,
    Value<String?>? title,
    Value<String?>? artist,
    Value<String?>? album,
    Value<String?>? albumArtist,
    Value<String?>? genre,
    Value<int?>? year,
    Value<int?>? track,
    Value<int?>? disc,
    Value<int?>? bitrate,
    Value<int?>? samplerate,
    Value<int?>? duration,
    Value<String?>? lyrics,
    Value<int>? playCount,
    Value<int?>? lastPlayed,
    Value<int>? rowid,
  }) {
    return MetadataItemsCompanion(
      id: id ?? this.id,
      modified: modified ?? this.modified,
      format: format ?? this.format,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      track: track ?? this.track,
      disc: disc ?? this.disc,
      bitrate: bitrate ?? this.bitrate,
      samplerate: samplerate ?? this.samplerate,
      duration: duration ?? this.duration,
      lyrics: lyrics ?? this.lyrics,
      playCount: playCount ?? this.playCount,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (modified.present) {
      map['modified'] = Variable<int>(modified.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (albumArtist.present) {
      map['album_artist'] = Variable<String>(albumArtist.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (track.present) {
      map['track'] = Variable<int>(track.value);
    }
    if (disc.present) {
      map['disc'] = Variable<int>(disc.value);
    }
    if (bitrate.present) {
      map['bitrate'] = Variable<int>(bitrate.value);
    }
    if (samplerate.present) {
      map['samplerate'] = Variable<int>(samplerate.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (lyrics.present) {
      map['lyrics'] = Variable<String>(lyrics.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    if (lastPlayed.present) {
      map['last_played'] = Variable<int>(lastPlayed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetadataItemsCompanion(')
          ..write('id: $id, ')
          ..write('modified: $modified, ')
          ..write('format: $format, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('genre: $genre, ')
          ..write('year: $year, ')
          ..write('track: $track, ')
          ..write('disc: $disc, ')
          ..write('bitrate: $bitrate, ')
          ..write('samplerate: $samplerate, ')
          ..write('duration: $duration, ')
          ..write('lyrics: $lyrics, ')
          ..write('playCount: $playCount, ')
          ..write('lastPlayed: $lastPlayed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$MetadataDB extends GeneratedDatabase {
  _$MetadataDB(QueryExecutor e) : super(e);
  $MetadataDBManager get managers => $MetadataDBManager(this);
  late final $MetadataItemsTable metadataItems = $MetadataItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [metadataItems];
}

typedef $$MetadataItemsTableCreateCompanionBuilder =
    MetadataItemsCompanion Function({
      required String id,
      Value<int?> modified,
      Value<String?> format,
      Value<String?> title,
      Value<String?> artist,
      Value<String?> album,
      Value<String?> albumArtist,
      Value<String?> genre,
      Value<int?> year,
      Value<int?> track,
      Value<int?> disc,
      Value<int?> bitrate,
      Value<int?> samplerate,
      Value<int?> duration,
      Value<String?> lyrics,
      Value<int> playCount,
      Value<int?> lastPlayed,
      Value<int> rowid,
    });
typedef $$MetadataItemsTableUpdateCompanionBuilder =
    MetadataItemsCompanion Function({
      Value<String> id,
      Value<int?> modified,
      Value<String?> format,
      Value<String?> title,
      Value<String?> artist,
      Value<String?> album,
      Value<String?> albumArtist,
      Value<String?> genre,
      Value<int?> year,
      Value<int?> track,
      Value<int?> disc,
      Value<int?> bitrate,
      Value<int?> samplerate,
      Value<int?> duration,
      Value<String?> lyrics,
      Value<int> playCount,
      Value<int?> lastPlayed,
      Value<int> rowid,
    });

class $$MetadataItemsTableFilterComposer
    extends Composer<_$MetadataDB, $MetadataItemsTable> {
  $$MetadataItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modified => $composableBuilder(
    column: $table.modified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get track => $composableBuilder(
    column: $table.track,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get disc => $composableBuilder(
    column: $table.disc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bitrate => $composableBuilder(
    column: $table.bitrate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get samplerate => $composableBuilder(
    column: $table.samplerate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lyrics => $composableBuilder(
    column: $table.lyrics,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPlayed => $composableBuilder(
    column: $table.lastPlayed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetadataItemsTableOrderingComposer
    extends Composer<_$MetadataDB, $MetadataItemsTable> {
  $$MetadataItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modified => $composableBuilder(
    column: $table.modified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get track => $composableBuilder(
    column: $table.track,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get disc => $composableBuilder(
    column: $table.disc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bitrate => $composableBuilder(
    column: $table.bitrate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get samplerate => $composableBuilder(
    column: $table.samplerate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lyrics => $composableBuilder(
    column: $table.lyrics,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPlayed => $composableBuilder(
    column: $table.lastPlayed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetadataItemsTableAnnotationComposer
    extends Composer<_$MetadataDB, $MetadataItemsTable> {
  $$MetadataItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get modified =>
      $composableBuilder(column: $table.modified, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get track =>
      $composableBuilder(column: $table.track, builder: (column) => column);

  GeneratedColumn<int> get disc =>
      $composableBuilder(column: $table.disc, builder: (column) => column);

  GeneratedColumn<int> get bitrate =>
      $composableBuilder(column: $table.bitrate, builder: (column) => column);

  GeneratedColumn<int> get samplerate => $composableBuilder(
    column: $table.samplerate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<String> get lyrics =>
      $composableBuilder(column: $table.lyrics, builder: (column) => column);

  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);

  GeneratedColumn<int> get lastPlayed => $composableBuilder(
    column: $table.lastPlayed,
    builder: (column) => column,
  );
}

class $$MetadataItemsTableTableManager
    extends
        RootTableManager<
          _$MetadataDB,
          $MetadataItemsTable,
          MetadataItem,
          $$MetadataItemsTableFilterComposer,
          $$MetadataItemsTableOrderingComposer,
          $$MetadataItemsTableAnnotationComposer,
          $$MetadataItemsTableCreateCompanionBuilder,
          $$MetadataItemsTableUpdateCompanionBuilder,
          (
            MetadataItem,
            BaseReferences<_$MetadataDB, $MetadataItemsTable, MetadataItem>,
          ),
          MetadataItem,
          PrefetchHooks Function()
        > {
  $$MetadataItemsTableTableManager(_$MetadataDB db, $MetadataItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetadataItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetadataItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetadataItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> modified = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<String?> albumArtist = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> track = const Value.absent(),
                Value<int?> disc = const Value.absent(),
                Value<int?> bitrate = const Value.absent(),
                Value<int?> samplerate = const Value.absent(),
                Value<int?> duration = const Value.absent(),
                Value<String?> lyrics = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<int?> lastPlayed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetadataItemsCompanion(
                id: id,
                modified: modified,
                format: format,
                title: title,
                artist: artist,
                album: album,
                albumArtist: albumArtist,
                genre: genre,
                year: year,
                track: track,
                disc: disc,
                bitrate: bitrate,
                samplerate: samplerate,
                duration: duration,
                lyrics: lyrics,
                playCount: playCount,
                lastPlayed: lastPlayed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> modified = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<String?> albumArtist = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> track = const Value.absent(),
                Value<int?> disc = const Value.absent(),
                Value<int?> bitrate = const Value.absent(),
                Value<int?> samplerate = const Value.absent(),
                Value<int?> duration = const Value.absent(),
                Value<String?> lyrics = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<int?> lastPlayed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetadataItemsCompanion.insert(
                id: id,
                modified: modified,
                format: format,
                title: title,
                artist: artist,
                album: album,
                albumArtist: albumArtist,
                genre: genre,
                year: year,
                track: track,
                disc: disc,
                bitrate: bitrate,
                samplerate: samplerate,
                duration: duration,
                lyrics: lyrics,
                playCount: playCount,
                lastPlayed: lastPlayed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetadataItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$MetadataDB,
      $MetadataItemsTable,
      MetadataItem,
      $$MetadataItemsTableFilterComposer,
      $$MetadataItemsTableOrderingComposer,
      $$MetadataItemsTableAnnotationComposer,
      $$MetadataItemsTableCreateCompanionBuilder,
      $$MetadataItemsTableUpdateCompanionBuilder,
      (
        MetadataItem,
        BaseReferences<_$MetadataDB, $MetadataItemsTable, MetadataItem>,
      ),
      MetadataItem,
      PrefetchHooks Function()
    >;

class $MetadataDBManager {
  final _$MetadataDB _db;
  $MetadataDBManager(this._db);
  $$MetadataItemsTableTableManager get metadataItems =>
      $$MetadataItemsTableTableManager(_db, _db.metadataItems);
}
