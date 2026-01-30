import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';

class MyAudioMetadata {
  final AudioMetadata _audioMetadata;
  final DateTime modified;
  String? picturePath;
  Color? coverArtColor;

  final isFavoriteNotifier = ValueNotifier(false);
  final updateNotifier = ValueNotifier(0);

  MyAudioMetadata(this._audioMetadata, this.modified, {this.picturePath});

  String? get title => _audioMetadata.title;
  String? get artist => _audioMetadata.artist;
  String? get album => _audioMetadata.album;
  String? get lyrics => _audioMetadata.lyrics;

  Duration? get duration => _audioMetadata.duration;

  List<Picture> get pictures => _audioMetadata.pictures;

  File get file => _audioMetadata.file;
  String get filePath => _audioMetadata.file.path;

  set title(String? value) => _audioMetadata.title = value;
  set artist(String? value) => _audioMetadata.artist = value;
  set album(String? value) => _audioMetadata.album = value;
  set lyrics(String? value) => _audioMetadata.lyrics = value;
  set duration(Duration? value) => _audioMetadata.duration = value;
  set pictures(List<Picture> value) => _audioMetadata.pictures = value;
}
