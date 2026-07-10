import 'dart:convert';
import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/lyric.dart';
import 'package:sylvakru/base/utils/path.dart';

class MyAudioMetadata {
  final String id;

  String? path;
  DateTime? modified;

  final SourceType sourceType;

  final AudioMetadata _audioMetadata;

  bool pictureLoaded = false;
  late bool pictureExist;
  late String picturePath;
  Color? coverArtColor;
  Color? lowerLuminance;

  ParsedLyrics? parsedLyrics;

  bool cacheExist = false;
  String? cachePath;

  final isFavoriteNotifier = ValueNotifier(false);
  final updateNotifier = ValueNotifier(0);

  int playCount;
  DateTime? lastPlayed;

  MyAudioMetadata(
    this._audioMetadata, {
    required this.id,
    this.path,
    this.modified,
    this.sourceType = .local,
    this.playCount = 0,
    this.lastPlayed,
  }) {
    final md5Hash = md5.convert(utf8.encode(id)).toString();
    picturePath = '${getPicturesPath(sourceType)}/$md5Hash';
    if (File(picturePath).existsSync()) {
      pictureLoaded = true;
      pictureExist = true;
    } else {
      pictureExist = false;
    }

    if (sourceType != .local) {
      cachePath = '${getCachesPath(sourceType)}/$md5Hash';
      cacheExist = File(cachePath!).existsSync();
    }
  }

  String? get format => _audioMetadata.format;
  String? get title => _audioMetadata.title;
  String? get artist => _audioMetadata.artist;
  String? get album => _audioMetadata.album;
  String? get albumArtist => _audioMetadata.albumArtist;
  String? get genre => _audioMetadata.genre;

  int? get year => _audioMetadata.year;
  int? get track => _audioMetadata.track;
  int? get disc => _audioMetadata.disc;
  int? get bitrate => _audioMetadata.bitrate;
  int? get samplerate => _audioMetadata.samplerate;

  Duration? get duration => _audioMetadata.duration;

  bool get isDsd {
    final fmt = format?.toLowerCase();
    if (fmt == 'dsf' || fmt == 'dff') {
      return true;
    }
    final lowerPath = (cachePath ?? path ?? '').toLowerCase();
    return lowerPath.endsWith('.dsf') || lowerPath.endsWith('.dff');
  }

  /// DSD 倍率（64/128/256/512）；samplerate 存的是真实 DSD 速率，
  /// 不在 44.1k 速率族时返回 null。
  int? get dsdMultiple {
    final rate = samplerate;
    if (!isDsd || rate == null || rate < 2822400 || rate % 44100 != 0) {
      return null;
    }
    return rate ~/ 44100;
  }

  String? get lyrics => _audioMetadata.lyrics;

  set title(String? value) => _audioMetadata.title = value;
  set artist(String? value) => _audioMetadata.artist = value;
  set album(String? value) => _audioMetadata.album = value;
  set albumArtist(String? value) => _audioMetadata.albumArtist = value;
  set genre(String? value) => _audioMetadata.genre = value;

  set year(int? value) => _audioMetadata.year = value;
  set track(int? value) => _audioMetadata.track = value;
  set disc(int? value) => _audioMetadata.disc = value;
  set bitrate(int? value) => _audioMetadata.bitrate = value;
  set samplerate(int? value) => _audioMetadata.samplerate = value;

  set lyrics(String? value) => _audioMetadata.lyrics = value;
  set duration(Duration? value) => _audioMetadata.duration = value;

  factory MyAudioMetadata.fromOpenSonicMap(
    Map<String, dynamic> song,
    SourceType sourceType,
  ) {
    return MyAudioMetadata(
      AudioMetadata(
        // suffix 是真实文件扩展名（flac/dsf/…）；contentType 对 DSD 是
        // audio/x-dsf 之类的变体，直接截取会得到 x-dsf 导致识别不到 DSD
        format:
            (song['suffix'] as String?) ??
            (song['contentType'] as String?)?.split('audio/').last,
        title: song['title'],
        artist: song['artist'],
        album: song['album'],
        albumArtist: song['displayAlbumArtist'],
        genre: song['genre'],
        year: song['year'],
        track: song['track'],
        disc: song['discNumber'],
        bitrate: song['bitRate'],
        samplerate: song['samplingRate'],
        duration: song['duration'] != null
            ? Duration(seconds: song['duration'])
            : null,
      ),
      sourceType: sourceType,
      id: song['id'],
      playCount: song['playCount'] as int? ?? 0,
      lastPlayed: song['played'] != null
          ? DateTime.parse(song['played'])
          : null,
    );
  }

  factory MyAudioMetadata.fromEmbyMap(Map<String, dynamic> song) {
    final mediaSources = (song['MediaSources'] as List?) ?? [];
    final primarySource = mediaSources.isNotEmpty ? mediaSources.first : null;
    final streams = (primarySource?['MediaStreams'] as List?) ?? [];

    final audioStream = streams.firstWhere(
      (s) => s['Type'] == 'Audio',
      orElse: () => null,
    );

    final lyricStream = streams.firstWhere(
      (s) => s['Type'] == 'Subtitle',
      orElse: () => null,
    );

    final container = primarySource?['Container'] as String?;
    return MyAudioMetadata(
      AudioMetadata(
        // DSD 的 Codec 是 dsd_lsbf_planar 之类的解码器名，用容器名才能识别 DSD
        format: (container == 'dsf' || container == 'dff')
            ? container
            : audioStream?['Codec'] ?? container,

        title: song['Name'],

        artist:
            (song['ArtistItems'] as List?)?.map((a) => a['Name']).join('/') ??
            (song['Artists'] as List?)?.join('/'),

        album: song['Album'],

        albumArtist: song['AlbumArtist'],

        genre: (song['Genres'] as List?)?.join('/'),

        year: song['ProductionYear'],

        track: song['IndexNumber'],

        disc: song['ParentIndexNumber'],

        bitrate: audioStream?['BitRate'] ?? primarySource?['Bitrate'],

        samplerate: audioStream?['SampleRate'],

        duration: song['RunTimeTicks'] != null
            ? Duration(microseconds: song['RunTimeTicks'] ~/ 10)
            : null,

        lyrics: lyricStream?['Extradata'],
      ),

      sourceType: SourceType.emby,

      id: song['Id'],

      playCount: song['UserData']?['PlayCount'] as int? ?? 0,

      lastPlayed: song['UserData']?['LastPlayedDate'] != null
          ? DateTime.parse(song['UserData']['LastPlayedDate'])
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  String toString() {
    return "$_audioMetadata\n"
        "playCount:$playCount\n"
        "lastPlayed:$lastPlayed";
  }
}
