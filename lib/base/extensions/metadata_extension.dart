import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:drift/drift.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/database.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/utils/path.dart';

extension MetadataItemMapper on MetadataItem {
  MyAudioMetadata toMetadata() {
    String path = id;
    if (sourceType == .local && Platform.isIOS) {
      path = revertIOSPath(path);
    }

    return MyAudioMetadata(
      AudioMetadata(
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
        duration: duration != null ? Duration(milliseconds: duration!) : null,
        lyrics: lyrics,
      ),

      id: id,
      path: path,

      modified: modified != null
          ? DateTime.fromMillisecondsSinceEpoch(modified!)
          : null,

      playCount: playCount,

      lastPlayed: lastPlayed != null
          ? DateTime.fromMillisecondsSinceEpoch(lastPlayed!)
          : null,
    );
  }
}

extension MyAudioMetadataMapper on MyAudioMetadata {
  MetadataItemsCompanion toCompanion() {
    return MetadataItemsCompanion.insert(
      id: id,

      modified: Value(modified?.millisecondsSinceEpoch),

      format: Value(format),

      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      albumArtist: Value(albumArtist),
      genre: Value(genre),

      year: Value(year),
      track: Value(track),
      disc: Value(disc),

      bitrate: Value(bitrate),
      samplerate: Value(samplerate),

      duration: Value(duration?.inMilliseconds),

      lyrics: Value(lyrics),

      playCount: Value(playCount),

      lastPlayed: Value(lastPlayed?.millisecondsSinceEpoch),
    );
  }
}
