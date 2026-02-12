import 'dart:convert';
import 'dart:io';

import 'package:audio_tags_lofty/audio_tags.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';

late FolderManager folderManager;

class FolderManager {
  late final File _folderPathListFile;
  List<Folder> folderList = [];

  FolderManager() {
    _folderPathListFile = File("${appSupportDir.path}/folder_paths.txt");
    if (!_folderPathListFile.existsSync()) {
      _folderPathListFile.createSync();
    }
  }

  bool get isEmpty => folderList.isEmpty;

  Future<void> initAllFolders() async {
    final folderPathListContent = await _folderPathListFile.readAsString();
    if (folderPathListContent.isEmpty) {
      return;
    }
    List<dynamic> result = jsonDecode(folderPathListContent);
    final folderPathList = result.cast<String>();

    for (int i = 0; i < folderPathList.length; i++) {
      folderList.add(Folder(i, folderPathList[i]));
    }
  }

  Future<void> load() async {
    for (final folder in folderList) {
      await folder.load();
    }
  }

  Future<bool> updateFolders(List<String> pathList) async {
    bool needUpdate = false;
    if (pathList.length == folderList.length) {
      for (int i = 0; i < pathList.length; i++) {
        if (pathList[i] != folderList[i].path) {
          needUpdate = true;
          break;
        }
      }
    } else {
      needUpdate = true;
    }
    if (!needUpdate) {
      return false;
    }
    for (final folder in folderList) {
      await folder.renameToTmp();
    }
    List<Folder> newFolderList = [];
    for (int i = 0; i < pathList.length; i++) {
      String path = pathList[i];
      bool exist = false;
      for (final folder in folderList) {
        if (folder.path == path) {
          await folder.updateIndex(i);
          newFolderList.add(folder);
          exist = true;
          break;
        }
      }
      if (!exist) {
        newFolderList.add(Folder(i, path));
      }
    }

    for (final folder in folderList) {
      if (newFolderList.contains(folder)) {
        continue;
      }
      await folder.delete();
    }

    folderList = newFolderList;

    await _folderPathListFile.writeAsString(
      jsonEncode(folderList.map((e) => e.path).toList()),
    );
    return true;
  }

  void clear() {
    for (final folder in folderList) {
      folder.clear();
    }
  }
}

class Folder {
  int index;
  final String path;
  late Directory _dir;
  late File _songFilePathListFile;
  List<MyAudioMetadata> songList = [];
  final updateNotifier = ValueNotifier(0);

  Folder(this.index, this.path) {
    _dir = Directory(revertDirectoryPathIfNeed(path));
    _songFilePathListFile = File(_getFolderSongFilePathListPath(index));
  }

  Future<void> load() async {
    if (!_dir.existsSync()) {
      return;
    }

    currentLoadingFolderNotifier.value = path;

    List<MyAudioMetadata> additionalSongList = [];

    await for (final file in _dir.list()) {
      String path = clipFilePathIfNeed(file.path);
      MyAudioMetadata? song = filePath2LibrarySong[path];
      bool isAdditional = song == null;
      final modified = (await file.stat()).modified;

      if (song?.modified != modified) {
        final tmp = readMetadata(file.path, false);

        if (tmp != null) {
          song = MyAudioMetadata(file.path, modified, tmp);

          if (isAdditional) {
            additionalSongList.add(song);
            libraryAdditionalSongList.add(song);
          }

          filePath2LibrarySong[path] = song;
        } else {
          song = null;
        }
      }

      if (song != null) {
        filePathValidSet.add(path);
        loadedCountNotifier.value++;
      }
    }

    await setSongList(_songFilePathListFile, additionalSongList, songList);

    await update();
  }

  Future<void> update() async {
    await _songFilePathListFile.writeAsString(
      jsonEncode(songList.map((e) => clipFilePathIfNeed(e.filePath)).toList()),
    );
    if (!isMobile) {
      panelManager.updateBackground();
    }
    updateNotifier.value++;
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
  }
}
