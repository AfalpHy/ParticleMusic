import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/folder.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/navidrome_client.dart';
import 'package:particle_music/utils.dart';
import 'package:uuid/uuid.dart';

class Library {
  late File _songIdListFile;

  late File _webdavCacheMapFile;
  late File _navidromeCacheMapFile;
  Map<String, String> _id2WebdavCache = {};
  Map<String, String> _id2navidromeCache = {};
  ValueNotifier<double> cacheSizeNotifier = ValueNotifier(0);

  List<MyAudioMetadata> songList = [];
  List<MyAudioMetadata> navidromeSongList = [];
  Map<String, MyAudioMetadata> id2Song = {};

  ValueNotifier<int> changeNotifier = ValueNotifier(0);
  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);
  ValueNotifier<int> navidromeSortTypeNotifier = ValueNotifier(0);

  final displayNavidromeNotifier = ValueNotifier(false);

  late final File _folderMapListFile;
  List<Folder> folderList = [];
  String? iosFileProviderStorage;

  Library() {
    _songIdListFile = File("${appSupportDir.path}/song_id_list.json");
    if (!_songIdListFile.existsSync()) {
      _songIdListFile.writeAsStringSync('[]');
    }

    _webdavCacheMapFile = File("${cacheConfigDir.path}/webdav_cache_map.json");
    if (!_webdavCacheMapFile.existsSync()) {
      _webdavCacheMapFile.writeAsStringSync('{}');
    }

    _navidromeCacheMapFile = File(
      "${cacheConfigDir.path}/navidrome_cache_map.json",
    );
    if (!_navidromeCacheMapFile.existsSync()) {
      _navidromeCacheMapFile.writeAsStringSync('{}');
    }

    _folderMapListFile = File("${folderConfigDir.path}/folder_map_list.json");
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

  Future<bool> updateFolders(List<String> idList) async {
    bool needUpdate = false;
    if (idList.length == folderList.length) {
      for (int i = 0; i < idList.length; i++) {
        if (idList[i] != folderList[i].id) {
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
    for (int i = 0; i < idList.length; i++) {
      String id = idList[i];
      bool exist = false;
      for (final folder in folderList) {
        if (id == folder.id) {
          newFolderList.add(folder);
          exist = true;
          break;
        }
      }
      if (!exist) {
        newFolderList.add(await Folder.create(id));
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

  Folder getFolderById(String id) {
    late Folder result;
    for (final folder in folderList) {
      if (folder.id == id) {
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
      id2Song.addAll(folder.id2Song);
    }

    await setSongList(_songIdListFile, songList, id2Song);
    final songSet = songList.toSet();
    for (final song in additionalSongSet) {
      if (songSet.contains(song)) {
        continue;
      }
      songList.add(song);
    }

    await _saveSongIdList();

    if (navidromeClient.valid) {
      loadingNavidromeNotifier.value = true;
      final list = await navidromeClient.getSongs();
      for (final map in list) {
        MyAudioMetadata song = MyAudioMetadata.fromNavidromeMap(map);
        navidromeSongList.add(song);
        id2Song[song.id] = song;
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
    final cacheMap = isWebdav ? _id2WebdavCache : _id2navidromeCache;

    cacheMap.addAll(
      (jsonDecode(await cacheMapFile.readAsString()) as Map<String, dynamic>)
          .cast(),
    );

    for (final id in cacheMap.keys) {
      final song = id2Song[id];
      String cachePath = cacheMap[id]!;

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
        cacheMap[id] = '';
      }
    }

    cacheMap.removeWhere((key, value) => value == '');
  }

  Future<void> tryAddCache(MyAudioMetadata song) async {
    try {
      if (song.isWebdav) {
        if (song.webdavCachePath != null) {
          return;
        }
        final uuid = Uuid();
        final savePath = "${cacheConfigDir.path}/webdavCache/${uuid.v4()}";

        await downloadFile(
          song.path!,
          savePath,
          headers: {'Authorization': getWebdavAuth()},
        );

        final tmp = File(savePath);
        if (await tmp.exists()) {
          _id2WebdavCache[song.id] = savePath;
          song.webdavCachePath = savePath;
          cacheSizeNotifier.value += await tmp.length() / (1024 * 1024);
          await _saveWebdavCache();
        }
      } else if (song.isNavidrome) {
        if (song.navidromeCachePath != null) {
          return;
        }

        final uuid = Uuid();
        final savePath = "${cacheConfigDir.path}/navidromeCache/${uuid.v4()}";

        await downloadFile(song.navidromeUrl!, savePath);

        final tmp = File(savePath);
        if (await tmp.exists()) {
          _id2navidromeCache[song.id] = savePath;
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
    if (Platform.isIOS) {
      await _webdavCacheMapFile.writeAsString(
        jsonEncode(
          _id2WebdavCache.map(
            (key, value) => MapEntry(key, convertIOSSupportPath(value)),
          ),
        ),
      );
    } else {
      await _webdavCacheMapFile.writeAsString(jsonEncode(_id2WebdavCache));
    }
  }

  Future<void> _saveNavidromeCache() async {
    if (Platform.isIOS) {
      await _navidromeCacheMapFile.writeAsString(
        jsonEncode(
          _id2navidromeCache.map(
            (key, value) => MapEntry(key, convertIOSSupportPath(value)),
          ),
        ),
      );
    } else {
      await _navidromeCacheMapFile.writeAsString(
        jsonEncode(_id2navidromeCache),
      );
    }
  }

  Future<void> clearCache() async {
    for (final id in _id2WebdavCache.keys) {
      final song = id2Song[id];
      song!.webdavCachePath = null;
    }

    for (final id in _id2navidromeCache.keys) {
      final song = id2Song[id];
      song!.navidromeCachePath = null;
    }

    Directory webdavCacheDir = Directory("${cacheConfigDir.path}/webdavCache");
    if (await webdavCacheDir.exists()) {
      await webdavCacheDir.delete(recursive: true);
    }
    Directory navidromeCacheDir = Directory(
      "${cacheConfigDir.path}/navidromeCache",
    );
    if (await navidromeCacheDir.exists()) {
      await navidromeCacheDir.delete(recursive: true);
    }

    cacheSizeNotifier.value = 0;

    _id2WebdavCache = {};
    await _saveWebdavCache();
    _id2navidromeCache = {};
    await _saveNavidromeCache();
  }

  Future<void> _saveSongIdList() async {
    await _songIdListFile.writeAsString(
      jsonEncode(songList.map((e) => e.id).toList()),
    );
  }

  void shuffle() {
    songList.shuffle();
    update();
  }

  Future<void> update() async {
    await layersManager.updateBackground();
    changeNotifier.value++;
    await _saveSongIdList();
  }

  void clear() {
    _id2WebdavCache = {};
    _id2navidromeCache = {};
    cacheSizeNotifier.value = 0;

    songList = [];
    id2Song = {};

    navidromeSongList = [];

    for (final folder in folderList) {
      folder.clear();
    }
  }
}
