import 'dart:typed_data';

import 'package:audio_tags_lofty/audio_tags.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common_widgets/lyrics.dart';

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
}
