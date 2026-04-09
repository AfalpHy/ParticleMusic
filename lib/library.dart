import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/bookmark_service.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/folder.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/navidrome_client.dart';
import 'package:particle_music/utils.dart';

class Library {
  late File _songFilePathListFile;
  late File _songMetadataListFile;

  Set<String> filePathValidSet = {};

  List<MyAudioMetadata> songList = [];
  List<MyAudioMetadata> additionalSongList = [];
  ValueNotifier<int> changeNotifier = ValueNotifier(0);
  Map<String, MyAudioMetadata> filePath2Song = {};

  List<MyAudioMetadata> navidromeSongList = [];
  Map<String, MyAudioMetadata> id2navidromeSong = {};

  final displayNavidromeNotifier = ValueNotifier(false);

  late final File _folderPathListFile;
  List<Folder> folderList = [];
  String? iosFileProviderStorage;

  Library() {
    _songFilePathListFile = File(
      "${appSupportDir.path}/song_file_path_list.txt",
    );
    _songMetadataListFile = File(
      "${appSupportDir.path}/song_metadata_list.txt",
    );
    if (!_songMetadataListFile.existsSync()) {
      _songMetadataListFile.createSync();
    }
    _folderPathListFile = File("${appSupportDir.path}/folder_paths.txt");
    if (!_folderPathListFile.existsSync()) {
      _folderPathListFile.createSync();
    }
  }

  Future<void> initAllFolders() async {
    final folderPathListContent = await _folderPathListFile.readAsString();
    if (folderPathListContent.isEmpty) {
      return;
    }
    List<dynamic> result = jsonDecode(folderPathListContent);
    final folderPathList = result.cast<String>();

    for (int i = 0; i < folderPathList.length; i++) {
      String path = folderPathList[i];
      if (path.startsWith('WebDAV:')) {
        folderList.add(Folder(i, path, isWebdav: true));
        continue;
      }
      String? iosPath;
      if (Platform.isIOS) {
        if (path.contains('Particle Music')) {
          iosPath = revertIOSPath(path);
        } else {
          iosPath = await BookmarkService.getUrlById(path);
          if (iosFileProviderStorage == null && iosPath != null) {
            iosFileProviderStorage = iosPath.substring(
              0,
              iosPath.indexOf('File Provider Storage/'),
            );
            iosFileProviderStorage =
                "${iosFileProviderStorage}File Provider Storage/";
          }
        }
      }
      folderList.add(Folder(i, path, iosPath: iosPath));
    }
  }

  Future<bool> updateFolders(List<String> pathList) async {
    bool needUpdate = false;
    if (pathList.length == folderList.length) {
      for (int i = 0; i < pathList.length; i++) {
        final path = Platform.isIOS
            ? folderList[i].iosPath
            : folderList[i].path;
        if (pathList[i] != path) {
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
      bool isWebdav = pathList[i].startsWith('WebDAV:');
      if (isWebdav || !Platform.isIOS) {
        String path = pathList[i];
        bool exist = false;
        for (final folder in folderList) {
          final folderPath = folder.path;
          if (folderPath == path) {
            await folder.updateIndex(i);
            newFolderList.add(folder);
            exist = true;
            break;
          }
        }
        if (!exist) {
          newFolderList.add(Folder(i, path, isWebdav: isWebdav));
        }
      } else {
        String iosPath = pathList[i];
        String path = convertIOSPath(iosPath);
        bool exist = false;
        for (final folder in folderList) {
          final folderPath = folder.iosPath;

          if (folderPath == iosPath) {
            await folder.updateIndex(i);
            newFolderList.add(folder);
            exist = true;
            break;
          }
        }
        if (!exist) {
          newFolderList.add(Folder(i, path, iosPath: iosPath));
        }
      }
    }

    for (final folder in folderList) {
      if (newFolderList.contains(folder)) {
        continue;
      }
      await folder.delete();
    }

    folderList = newFolderList;

    if (Platform.isIOS) {
      await BookmarkService.clear();
      for (final folder in folderList) {
        if (folder.path.startsWith('WebDAV') ||
            !folder.iosPath!.contains('File Provider Storage/')) {
          continue;
        }
        if (await BookmarkService.saveDirectoryAndActive(
          folder.path,
          folder.iosPath!,
        )) {
          library.iosFileProviderStorage ??= folder.iosPath!.substring(
            0,
            folder.iosPath!.indexOf(folder.path),
          );
        }
      }
    }
    await _folderPathListFile.writeAsString(
      jsonEncode(folderList.map((e) => e.path).toList()),
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

  Future<void> _prepare() async {
    final jsonString = await _songMetadataListFile.readAsString();
    if (jsonString.isEmpty) {
      return;
    }

    final List<dynamic> list = jsonDecode(jsonString);

    for (final map in list) {
      final song = MyAudioMetadata.fromMap(map);
      filePath2Song[song.filePath!] = song;
    }
  }

  Future<void> load() async {
    await _prepare();
    for (final folder in folderList) {
      await folder.load();
      additionalSongList.addAll(folder.additionalSongList);
    }

    await setSongList(_songFilePathListFile, additionalSongList, songList);
    await _saveSongFilePathList();
    await _saveSongMetadataList();

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

  Future<void> _saveSongMetadataList() async {
    await _songMetadataListFile.writeAsString(
      jsonEncode(songList.map((e) => e.toMap()).toList()),
    );
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
    filePathValidSet = {};

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
