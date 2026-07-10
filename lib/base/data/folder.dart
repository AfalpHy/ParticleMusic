import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:sylvakru/base/services/bookmark_service.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/song_list_service.dart';
import 'package:sylvakru/base/utils/path.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/base/widgets/manage_music_folders.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:path/path.dart';

final Set<String> _loftySupportedExts = {
  '.mp2',
  '.mp3',
  '.flac',
  '.m4a',
  '.m4b',
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
  // DSD 容器不走 lofty，由 dsd_metadata.dart 解析（见 library._parseMetadataIfNeed）
  '.dsf',
  '.dff',
};

class Folder {
  final String id;
  final String path;
  late Directory? _dir;
  bool isWebdav;
  late File _songIdListFile;

  List<MyAudioMetadata> songList = [];

  Map<String, DateTime> pathAndModified = {};

  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);

  final changeNotifier = ValueNotifier(0);

  Folder(this.id, this.path, {this.isWebdav = false}) {
    if (!isWebdav) {
      _dir = Directory(path);
    }
    _songIdListFile = File(
      "${getFolderConfigPath(isWebdav ? .webdav : .local)}/${md5.convert(utf8.encode(id)).toString()}.json",
    );
    if (!_songIdListFile.existsSync()) {
      _songIdListFile.writeAsStringSync('[]');
    }
  }

  static Future<Folder> from(String id, bool isWebdav) async {
    String path = id;

    if (!isWebdav && Platform.isIOS) {
      if (id.startsWith('Sylvakru')) {
        path =
            '${appDocsDir.parent.path}/${id.replaceFirst('Sylvakru', 'Documents')}';
      } else {
        path = await BookmarkService.getUrlById(id) ?? '';
        library.setIOSFileProviderStorageIfNeed(path);
      }
    }

    return Folder(id, path, isWebdav: isWebdav);
  }

  static Future<Folder> create(String id, bool isWebdav) async {
    String path = id;

    if (!isWebdav && Platform.isIOS) {
      if (id.startsWith('Sylvakru')) {
        path =
            '${appDocsDir.parent.path}/${id.replaceFirst('Sylvakru', 'Documents')}';
      } else {
        path = library.iosFileProviderStorage! + id;
        if (!await BookmarkService.saveDirectoryAndActive(id, path)) {
          path = '';
        }
      }
    }

    return Folder(id, path, isWebdav: isWebdav);
  }

  Future<void> setFileAndModified() async {
    if (isWebdav) {
      await for (final file in webdavClient!.listStream(
        path,
        recursive: recursiveScanNotifier.value,
      )) {
        if (!file.isDirectory) {
          final ext = extension(file.path).toLowerCase();

          if (!_loftySupportedExts.contains(ext)) {
            continue;
          }
          pathAndModified.addEntries([MapEntry(file.path, file.modified!)]);
        }
      }
    } else {
      await for (final file in _dir!.list(
        recursive: recursiveScanNotifier.value,
      )) {
        if (file is File) {
          final ext = extension(file.path).toLowerCase();

          if (!_loftySupportedExts.contains(ext)) {
            continue;
          }
          pathAndModified.addEntries([
            MapEntry(file.path, (await file.stat()).modified),
          ]);
        }
      }
    }
  }

  void clearPathAndModified() {
    pathAndModified.clear();
  }

  Future<void> load() async {
    await loadSongList(_songIdListFile, songList);
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

  void update() {
    changeNotifier.value++;
    layersManager.updateBackground();
    _saveSongIdList();
  }

  void delete() {
    try {
      _songIdListFile.deleteSync();
    } catch (e) {
      logger.output(e.toString());
    }
  }

  Future<void> sync() async {
    final List<dynamic> songIdList = jsonDecode(
      await _songIdListFile.readAsString(),
    );

    for (final id in songIdList) {
      final song = library.id2Song[id];

      if (song != null) {
        songList.add(song);
        String path = song.path!;
        if (isWebdav) {
          path = path.substring(webdavClient!.cleanBaseUrl.length);
        }

        pathAndModified.remove(path);
      }
    }

    for (final entry in pathAndModified.entries) {
      String path = entry.key;
      String id = path;

      if (isWebdav) {
        id = webdavClient!.cleanBaseUrl + path;
      } else if (Platform.isIOS) {
        id = convertIOSPath(path);
      }

      final song = library.id2Song[id];
      if (song != null) {
        songList.add(song);
      }
    }

    update();
  }
}
