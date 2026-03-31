import 'dart:typed_data';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common_widgets/lyrics.dart';
import 'package:particle_music/utils.dart';

class MyAudioMetadata {
  final String? filePath;
  final DateTime? modified;
  final String? id;
  final bool isNavidrome;

  final AudioMetadata _audioMetadata;

  bool pictureLoaded = false;
  Color? coverArtColor;
  ParsedLyrics? parsedLyrics;

  String? navidromeUrl;

  final isFavoriteNotifier = ValueNotifier(false);
  final updateNotifier = ValueNotifier(0);

  int playCount;
  DateTime? lastPlayed;

  MyAudioMetadata(
    this._audioMetadata, {
    this.filePath,
    this.modified,
    this.id,
    this.isNavidrome = false,
    this.playCount = 0,
    this.lastPlayed,
  });

  String? get title => _audioMetadata.title;
  String? get artist => _audioMetadata.artist;
  String? get album => _audioMetadata.album;
  String? get genre => _audioMetadata.genre;

  int? get year => _audioMetadata.year;
  int? get track => _audioMetadata.track;
  int? get disc => _audioMetadata.disc;
  int? get bitrate => _audioMetadata.bitrate;
  int? get samplerate => _audioMetadata.samplerate;

  Duration? get duration => _audioMetadata.duration;

  String? get lyrics => _audioMetadata.lyrics;

  Uint8List? get pictureBytes => _audioMetadata.pictureBytes;

  bool get noPicture => pictureLoaded && pictureBytes == null;

  set title(String? value) => _audioMetadata.title = value;
  set artist(String? value) => _audioMetadata.artist = value;
  set album(String? value) => _audioMetadata.album = value;
  set genre(String? value) => _audioMetadata.genre = value;

  set track(int? value) => _audioMetadata.track = value;
  set disc(int? value) => _audioMetadata.disc = value;
  set bitrate(int? value) => _audioMetadata.bitrate = value;
  set samplerate(int? value) => _audioMetadata.samplerate = value;

  set lyrics(String? value) => _audioMetadata.lyrics = value;
  set duration(Duration? value) => _audioMetadata.duration = value;
  set pictureBytes(Uint8List? value) => _audioMetadata.pictureBytes = value;

  factory MyAudioMetadata.fromMap(Map<String, dynamic> map) {
    final path = map['path'] as String;

    return MyAudioMetadata(
      filePath: revertFilePathIfNeed(path),
      modified: DateTime.fromMillisecondsSinceEpoch(map['modified'] as int),
      AudioMetadata(
        title: map['title'] as String?,
        artist: map['artist'] as String?,
        album: map['album'] as String?,
        genre: map['genre'] as String?,
        year: map['year'] as int?,
        track: map['track'] as int?,
        disc: map['disc'] as int?,
        bitrate: map['bitrate'] as int?,
        samplerate: map['samplerate'] as int?,
        duration: map['duration'] != null
            ? Duration(milliseconds: map['duration'] as int)
            : null,
        lyrics: map['lyrics'] as String?,
      ),
    );
  }

  factory MyAudioMetadata.fromNavidromeMap(Map<String, dynamic> song) {
    return MyAudioMetadata(
      AudioMetadata(
        title: song['title'],
        artist: song['artist'],
        album: song['album'],
        genre: song['genre'],
        year: song['year'],
        track: song['track'],
        disc: song['discNumber'],
        bitrate: song['bitrate'],
        samplerate: song['samplingate'],
        duration: song['duration'] != null
            ? Duration(seconds: song['duration'])
            : null,
      ),
      isNavidrome: true,
      id: song['id'],
      playCount: song['playCount'] as int? ?? 0,
      lastPlayed: song['played'] != null
          ? DateTime.parse(song['played'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'modified': modified?.millisecondsSinceEpoch,
      'path': clipFilePathIfNeed(filePath!),
      'title': title,
      'artist': artist,
      'album': album,
      'genre': genre,
      'year': year,
      'track': track,
      'disc': disc,
      'bitrate': bitrate,
      'samplerate': samplerate,
      'duration': duration?.inMilliseconds,
      'lyrics': lyrics,
    };
  }
}
