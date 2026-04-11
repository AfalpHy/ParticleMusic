import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/folder.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/navidrome_client.dart';
import 'package:particle_music/utils.dart';

class Library {
  late File _songFilePathListFile;

  List<MyAudioMetadata> songList = [];
  List<MyAudioMetadata> additionalSongList = [];
  ValueNotifier<int> changeNotifier = ValueNotifier(0);
  Map<String, MyAudioMetadata> filePath2Song = {};

  List<MyAudioMetadata> navidromeSongList = [];
  Map<String, MyAudioMetadata> id2navidromeSong = {};

  final displayNavidromeNotifier = ValueNotifier(false);

  late final File _folderMapListFile;
  List<Folder> folderList = [];
  String? iosFileProviderStorage;

  Library() {
    _songFilePathListFile = File(
      "${appSupportDir.path}/song_file_path_list.txt",
    );
    if (!_songFilePathListFile.existsSync()) {
      _songFilePathListFile.writeAsStringSync('[]');
    }

    _folderMapListFile = File("${appSupportDir.path}/folder_map_list.txt");

    if (!_folderMapListFile.existsSync()) {
      _folderMapListFile.writeAsStringSync('[]');
    }
  }

  Future<void> initAllFolders() async {
    final jsonString = await _folderMapListFile.readAsString();
    List<dynamic> result = jsonDecode(jsonString);
    final folderMapList = result.cast<Map<String, dynamic>>();

    for (final map in folderMapList) {
      folderList.add(await Folder.from(map));
    }
  }

  void setIOSFileProviderStorageIfNeed(String? iosPath) {
    if (iosFileProviderStorage == null && iosPath != null) {
      final tmp = iosPath.split('File Provider Storage/').first;
      iosFileProviderStorage = "${tmp}File Provider Storage/";
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

    List<Folder> newFolderList = [];
    for (int i = 0; i < pathList.length; i++) {
      String path = pathList[i];
      bool exist = false;
      for (final folder in folderList) {
        if (path == folder.path) {
          newFolderList.add(folder);
          exist = true;
          break;
        }
      }
      if (!exist) {
        newFolderList.add(await Folder.create(path));
      }
    }

    for (final folder in folderList) {
      if (newFolderList.contains(folder)) {
        continue;
      }
      folder.delete();
    }

    folderList = newFolderList;

    await _folderMapListFile.writeAsString(
      jsonEncode(folderList.map((e) => e.toMap()).toList()),
    );
    return true;
  }

  Folder getFolderByPath(String path) {
    late Folder result;
    for (final folder in folderList) {
      if (folder.path == path) {
        result = folder;
      }
    }
    return result;
  }

  Future<void> load() async {
    for (final folder in folderList) {
      await folder.load();
      additionalSongList.addAll(folder.additionalSongList);
      filePath2Song.addAll(folder.filePath2Song);
    }

    await setSongList(
      _songFilePathListFile,
      additionalSongList,
      songList,
      filePath2Song,
    );

    await _saveSongFilePathList();

    if (navidromeClient.valid) {
      loadingNavidromeNotifier.value = true;
      final list = await navidromeClient.getSongs();
      for (final map in list) {
        MyAudioMetadata song = MyAudioMetadata.fromNavidromeMap(map);
        navidromeSongList.add(song);
        id2navidromeSong[song.id!] = song;
      }
    }

    displayNavidromeNotifier.value =
        songList.isEmpty & navidromeSongList.isNotEmpty;
  }

  Future<void> _saveSongFilePathList() async {
    await _songFilePathListFile.writeAsString(
      jsonEncode(songList.map((e) => e.filePath!).toList()),
    );
  }

  Future<void> update() async {
    layersManager.updateBackground();
    changeNotifier.value++;
    await _saveSongFilePathList();
  }

  void clear() {
    songList = [];
    additionalSongList = [];
    filePath2Song = {};

    navidromeSongList = [];
    id2navidromeSong = {};

    for (final folder in folderList) {
      folder.clear();
    }
  }
}
