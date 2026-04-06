import 'dart:convert';
import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';
import 'package:path/path.dart';

final Set<String> _loftySupportedExts = {
  '.mp2',
  '.mp3',
  '.flac',
  '.m4a',
  '.m4r',
  '.mp4',
  '.aac',
  '.wav',
  '.aiff',
  '.aif',
  '.ogg',
  '.opus',
  '.ape',
  '.mpc',
  '.wv',
  '.spx',
};

class Folder {
  int index;
  final String path;
  final String? iosPath;
  late Directory _dir;
  late File _songFilePathListFile;
  List<MyAudioMetadata> songList = [];
  List<MyAudioMetadata> additionalSongList = [];
  final updateNotifier = ValueNotifier(0);

  Folder(this.index, this.path, {this.iosPath}) {
    if (Platform.isIOS) {
      _dir = Directory(iosPath!);
    } else {
      _dir = Directory(path);
    }
    _songFilePathListFile = File(_getFolderSongFilePathListPath(index));
  }

  Future<void> load() async {
    try {
      if (!_dir.existsSync()) {
        return;
      }

      currentLoadingFolderNotifier.value = path;

      await for (final file in _dir.list()) {
        if (file is! File) continue;

        final ext = extension(file.path).toLowerCase();
        if (!_loftySupportedExts.contains(ext)) {
          continue;
        }

        String filePath = file.path;
        if (Platform.isIOS) {
          filePath = convertIOSPath(filePath);
        }
        MyAudioMetadata? song = library.filePath2Song[filePath];
        bool isAdditional = song == null;
        final modified = (await file.stat()).modified;

        if (song?.modified != modified) {
          final tmp = readMetadata(file.path, false);

          if (tmp != null) {
            song = MyAudioMetadata(
              tmp,
              filePath: filePath,
              iosPath: Platform.isIOS ? file.path : null,
              modified: modified,
            );

            if (isAdditional) {
              additionalSongList.add(song);
            }

            library.filePath2Song[filePath] = song;
          } else {
            song = null;
          }
        }

        if (song != null) {
          library.filePathValidSet.add(filePath);
          loadedCountNotifier.value++;
        }
      }

      await setSongList(_songFilePathListFile, additionalSongList, songList);

      await _saveSongFilePathList();
    } catch (e) {
      logger.output(e.toString());
      return;
    }
  }

  Future<void> _saveSongFilePathList() async {
    await _songFilePathListFile.writeAsString(
      jsonEncode(songList.map((e) => e.filePath!).toList()),
    );
  }

  Future<void> update() async {
    layersManager.updateBackground();
    updateNotifier.value++;
    await _saveSongFilePathList();
  }

  Future<void> updateIndex(int index) async {
    this.index = index;
    _songFilePathListFile = await _songFilePathListFile.rename(
      _getFolderSongFilePathListPath(index),
    );
  }

  Future<void> renameToTmp() async {
    _songFilePathListFile = await _songFilePathListFile.rename(
      "${_getFolderSongFilePathListPath(index)}tmp",
    );
  }

  Future<void> delete() async {
    if (await _songFilePathListFile.exists()) {
      await _songFilePathListFile.delete();
    }
  }

  String _getFolderSongFilePathListPath(int index) {
    return "${appSupportDir.path}/folder_song_file_path_list_$index.txt";
  }

  void clear() {
    songList = [];
    additionalSongList = [];
  }
}
