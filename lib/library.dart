import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:particle_music/common.dart';
import 'package:particle_music/folder.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/navidrome_client.dart';
import 'package:particle_music/utils.dart';
import 'package:uuid/uuid.dart';

class Library {
  late File _songFilePathListFile;

  late File _webdavCacheMapFile;
  late File _navidromeCacheMapFile;
  Map<String, String> _filePath2WebdavCache = {};
  Map<String, String> _id2navidromeCache = {};
  ValueNotifier<double> cacheSizeNotifier = ValueNotifier(0);

  List<MyAudioMetadata> songList = [];
  Map<String, MyAudioMetadata> filePath2Song = {};

  List<MyAudioMetadata> navidromeSongList = [];
  Map<String, MyAudioMetadata> id2navidromeSong = {};

  ValueNotifier<int> changeNotifier = ValueNotifier(0);
  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);
  ValueNotifier<int> navidromeSortTypeNotifier = ValueNotifier(0);

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

    _webdavCacheMapFile = File("${appSupportDir.path}/webdav_cache_map.txt");
    if (!_webdavCacheMapFile.existsSync()) {
      _webdavCacheMapFile.writeAsStringSync('{}');
    }

    _navidromeCacheMapFile = File(
      "${appSupportDir.path}/navidrome_cache_map.txt",
    );
    if (!_navidromeCacheMapFile.existsSync()) {
      _navidromeCacheMapFile.writeAsStringSync('{}');
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
    final Set<MyAudioMetadata> additionalSongSet = {};

    for (final folder in folderList) {
      await folder.load();
      additionalSongSet.addAll(folder.additionalSongList);
      filePath2Song.addAll(folder.filePath2Song);
    }

    await setSongList(_songFilePathListFile, songList, filePath2Song);
    final songSet = songList.toSet();
    for (final song in additionalSongSet) {
      if (songSet.contains(song)) {
        continue;
      }
      songList.add(song);
    }

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

    await _processCache(true);
    await _saveWebdavCache();

    await _processCache(false);
    await _saveNavidromeCache();
  }

  Future<void> _processCache(bool isWebdav) async {
    final cacheMapFile = isWebdav
        ? _webdavCacheMapFile
        : _navidromeCacheMapFile;
    final cacheMap = isWebdav ? _filePath2WebdavCache : _id2navidromeCache;

    cacheMap.addAll(
      (jsonDecode(await cacheMapFile.readAsString()) as Map<String, dynamic>)
          .cast(),
    );

    for (final key in cacheMap.keys) {
      final song = isWebdav ? filePath2Song[key] : id2navidromeSong[key];
      String cachePath = cacheMap[key]!;

      if (Platform.isIOS) {
        cachePath = revertIOSSupportPath(cachePath);
      }
      File cacheFile = File(cachePath);
      if (song != null && await cacheFile.exists()) {
        if (isWebdav) {
          song.webdavCachePath = cachePath;
        } else {
          song.navidromeCachePath = cachePath;
        }
        cacheSizeNotifier.value += await cacheFile.length() / (1024 * 1024);
      } else {
        if (await cacheFile.exists()) {
          await cacheFile.delete();
        }
        cacheMap[key] = '';
      }
    }

    cacheMap.removeWhere((key, value) => value == '');
  }

  Future<void> _downloadFile(
    String url,
    String savePath, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);
      } else {
        logger.output('download failed');
      }
    } catch (e) {
      logger.output(e.toString());
    }
  }

  Future<void> tryAddCache(MyAudioMetadata song) async {
    try {
      if (song.isWebdav) {
        if (song.webdavCachePath != null) {
          return;
        }
        final uuid = Uuid();
        final savePath = "${appSupportDir.path}/webdavCache/${uuid.v4()}";

        await _downloadFile(
          song.filePath!,
          savePath,
          headers: {'Authorization': getWebdavAuth()},
        );

        final tmp = File(savePath);
        if (await tmp.exists()) {
          _filePath2WebdavCache[song.filePath!] = savePath;
          song.webdavCachePath = savePath;
          cacheSizeNotifier.value += await tmp.length() / (1024 * 1024);
          await _saveWebdavCache();
        }
      } else if (song.isNavidrome) {
        if (song.navidromeCachePath != null) {
          return;
        }

        final uuid = Uuid();
        final savePath = "${appSupportDir.path}/navidromeCache/${uuid.v4()}";

        await _downloadFile(song.navidromeUrl!, savePath);

        final tmp = File(savePath);
        if (await tmp.exists()) {
          _id2navidromeCache[song.id!] = savePath;
          song.navidromeCachePath = savePath;
          cacheSizeNotifier.value += await tmp.length() / (1024 * 1024);
          await _saveNavidromeCache();
        }
      }
    } catch (e) {
      logger.output(e.toString());
    }
  }

  Future<void> _saveWebdavCache() async {
    await _webdavCacheMapFile.writeAsString(jsonEncode(_filePath2WebdavCache));
  }

  Future<void> _saveNavidromeCache() async {
    await _navidromeCacheMapFile.writeAsString(jsonEncode(_id2navidromeCache));
  }

  Future<void> clearCache() async {
    for (final filePath in _filePath2WebdavCache.keys) {
      final song = filePath2Song[filePath];
      song!.webdavCachePath = null;
    }

    for (final id in _id2navidromeCache.keys) {
      final song = id2navidromeSong[id];
      song!.navidromeCachePath = null;
    }

    Directory webdavCacheDir = Directory("${appSupportDir.path}/webdavCache");
    if (await webdavCacheDir.exists()) {
      await webdavCacheDir.delete(recursive: true);
    }
    Directory navidromeCacheDir = Directory(
      "${appSupportDir.path}/navidromeCache",
    );
    if (await navidromeCacheDir.exists()) {
      await navidromeCacheDir.delete(recursive: true);
    }

    cacheSizeNotifier.value = 0;

    _filePath2WebdavCache = {};
    await _saveWebdavCache();
    _id2navidromeCache = {};
    await _saveNavidromeCache();
  }

  Future<void> _saveSongFilePathList() async {
    await _songFilePathListFile.writeAsString(
      jsonEncode(songList.map((e) => e.filePath!).toList()),
    );
  }

  void shuffle() {
    songList.shuffle();
    update();
  }

  Future<void> update() async {
    await layersManager.updateBackground();
    changeNotifier.value++;
    await _saveSongFilePathList();
  }

  void clear() {
    _filePath2WebdavCache = {};
    _id2navidromeCache = {};
    cacheSizeNotifier.value = 0;

    songList = [];
    filePath2Song = {};

    navidromeSongList = [];
    id2navidromeSong = {};

    for (final folder in folderList) {
      folder.clear();
    }
  }
}
