import 'dart:typed_data';

import 'package:audio_tags_lofty/audio_tags.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common_widgets/lyrics.dart';

class MyAudioMetadata {
  final String filePath;
  final DateTime modified;
  final AudioMetadata _audioMetadata;

  bool pictureLoaded = false;
  Color? coverArtColor;
  ParsedLyrics? parsedLyrics;

  final isFavoriteNotifier = ValueNotifier(false);
  final updateNotifier = ValueNotifier(0);

  MyAudioMetadata(this.filePath, this.modified, this._audioMetadata);

  String? get title => _audioMetadata.title;
  String? get artist => _audioMetadata.artist;
  String? get album => _audioMetadata.album;
  Duration? get duration => _audioMetadata.duration;

  String? get lyrics => _audioMetadata.lyrics;

  Uint8List? get pictureBytes => _audioMetadata.pictureBytes;

  bool get noPicture => pictureLoaded && pictureBytes == null;

  set title(String? value) => _audioMetadata.title = value;
  set artist(String? value) => _audioMetadata.artist = value;
  set album(String? value) => _audioMetadata.album = value;
  set lyrics(String? value) => _audioMetadata.lyrics = value;
  set duration(Duration? value) => _audioMetadata.duration = value;
  set pictureBytes(Uint8List? value) => _audioMetadata.pictureBytes = value;
}
