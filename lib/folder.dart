import 'dart:convert';
import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/bookmark_service.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:pool/pool.dart';

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
  final String id;
  final String path;
  late Directory? _dir;
  bool isWebdav;
  late File _songIdListFile;
  late File _songMetadataListFile;

  List<MyAudioMetadata> songList = [];
  List<MyAudioMetadata> additionalSongList = [];
  Map<String, MyAudioMetadata> id2Song = {};
  Set<String> validId = {};

  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);

  final updateNotifier = ValueNotifier(0);

  Folder(
    this.id,
    this.path,
    String songIdListPath,
    String songMetadataListPath, {
    this.isWebdav = false,
  }) {
    if (!isWebdav) {
      _dir = Directory(path);
    }
    _songIdListFile = File(songIdListPath);
    if (!_songIdListFile.existsSync()) {
      _songIdListFile.writeAsStringSync('[]');
    }
    _songMetadataListFile = File(songMetadataListPath);
    if (!_songMetadataListFile.existsSync()) {
      _songMetadataListFile.writeAsStringSync('[]');
    }
  }

  static Future<Folder> from(Map<String, dynamic> map) async {
    String id = map['id'] as String;
    String songIdListPath = map['songIdListPath'] as String;
    String songMetadataListPath = map['songMetadataListPath'] as String;

    String path = id;
    bool isWebdav = id.startsWith('WebDAV:');
    if (isWebdav) {
      path = id.substring(7);
    } else if (Platform.isIOS) {
      if (id.startsWith('Particle Music')) {
        path =
            '${appDocs.parent.path}/${id.replaceFirst('Particle Music', 'Documents')}';
      } else {
        path = await BookmarkService.getUrlById(id) ?? '';
        library.setIOSFileProviderStorageIfNeed(path);
      }

      songIdListPath = "${folderConfigDir.path}/$songIdListPath";
      songMetadataListPath = "${folderConfigDir.path}/$songMetadataListPath";
    }

    return Folder(
      id,
      path,
      songIdListPath,
      songMetadataListPath,
      isWebdav: isWebdav,
    );
  }

  static Future<Folder> create(String id) async {
    final uuid = Uuid();
    final songIdListPath = '${folderConfigDir.path}/${uuid.v4()}.json';
    final songMetadataListPath = '${folderConfigDir.path}/${uuid.v4()}.json';

    String path = id;
    bool isWebdav = id.startsWith('WebDAV:');
    if (isWebdav) {
      path = id.substring(7);
    } else if (Platform.isIOS) {
      if (id.startsWith('Particle Music')) {
        path =
            '${appDocs.parent.path}/${id.replaceFirst('Particle Music', 'Documents')}';
      } else {
        path = library.iosFileProviderStorage! + id;
        if (!await BookmarkService.saveDirectoryAndActive(id, path)) {
          path = '';
        }
      }
    }

    return Folder(
      id,
      path,
      songIdListPath,
      songMetadataListPath,
      isWebdav: isWebdav,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'songIdListPath': Platform.isIOS
          ? _songIdListFile.path.split('folder_config/').last
          : _songIdListFile.path,
      'songMetadataListPath': Platform.isIOS
          ? _songMetadataListFile.path.split('folder_config/').last
          : _songMetadataListFile.path,
    };
  }

  Future<void> _prepare() async {
    final jsonString = await _songMetadataListFile.readAsString();
    final List<dynamic> list = jsonDecode(jsonString);
    for (final map in list) {
      final song = MyAudioMetadata.fromMap(map);
      id2Song[song.id] = song;
    }
  }

  Future<void> _processSong(String id, String path, DateTime modified) async {
    MyAudioMetadata? song = id2Song[id];
    bool isAdditional = song == null;

    if (recursiveScanNotifier.value) {
      MyAudioMetadata? song = library.id2Song[id];
      if (song != null) {
        if (isAdditional) {
          additionalSongList.add(song);
        }

        id2Song[id] = song;
        validId.add(id);
        return;
      }
    }

    if (song?.modified != modified) {
      try {
        final tmp = isWebdav
            ? await readMetadataAsync(
                path,
                false,
                username: webdavUsername,
                password: webdavPassword,
              )
            : readMetadata(path, false);

        if (tmp != null) {
          song = MyAudioMetadata(
            tmp,
            id: id,
            path: path,
            modified: modified,
            isWebdav: isWebdav,
          );

          if (isAdditional) {
            additionalSongList.add(song);
          }

          id2Song[id] = song;
        } else {
          song = null;
        }
      } catch (e) {
        song = null;
        logger.output(e.toString());
      }
    }
    if (song != null) {
      validId.add(id);
      loadedCountNotifier.value++;
    }
  }

  Future<void> load() async {
    currentLoadingFolderNotifier.value = id;
    await _prepare();
    if (isWebdav) {
      if (webdavClient == null) {
        await setSongList(_songIdListFile, songList, id2Song);
        logger.output('There are no WebDAV client');
        return;
      }

      try {
        final List<String> dirList = [path];
        if (recursiveScanNotifier.value) {
          dirList.addAll(await getWebdavSubDirectoriesFrom(path));
        }

        for (final dir in dirList) {
          final filelist = await webdavClient!.readDir(dir);
          final pool = Pool(4);

          final tasks = filelist
              .where((f) {
                if (f.isDir!) return false;
                final ext = extension(f.path!).toLowerCase();
                return _loftySupportedExts.contains(ext);
              })
              .map((f) {
                final id = webdavBaseUrl + f.path!;
                return pool.withResource(() => _processSong(id, id, f.mTime!));
              });
          await Future.wait(tasks);
        }
      } catch (e) {
        // If it fails, keep the original data.
        await setSongList(_songIdListFile, songList, id2Song);
        additionalSongList.clear();
        logger.output(e.toString());
        return;
      }
    } else {
      if (!_dir!.existsSync()) {
        await setSongList(_songIdListFile, songList, id2Song);
        logger.output('$path is not exist');
        return;
      }
      await for (final file in _dir!.list(
        recursive: recursiveScanNotifier.value,
      )) {
        if (file is! File) continue;

        final ext = extension(file.path).toLowerCase();
        if (!_loftySupportedExts.contains(ext)) {
          continue;
        }

        String path = file.path;
        final modified = (await file.stat()).modified;
        if (Platform.isIOS) {
          await _processSong(convertIOSPath(path), path, modified);
        } else {
          await _processSong(path, path, modified);
        }
      }
    }

    final Map<String, MyAudioMetadata> newId2Song = {};

    for (final path in validId) {
      newId2Song[path] = id2Song[path]!;
    }
    id2Song = newId2Song;

    await setSongList(_songIdListFile, songList, id2Song);
    songList.addAll(additionalSongList);

    await _saveSongIdList();
    await _saveSongMetadataList();
  }

  Future<void> _saveSongIdList() async {
    await _songIdListFile.writeAsString(
      jsonEncode(songList.map((e) => e.id).toList()),
    );
  }

  Future<void> _saveSongMetadataList() async {
    await _songMetadataListFile.writeAsString(
      jsonEncode(songList.map((e) => e.toMap()).toList()),
    );
  }

  void shuffle() {
    songList.shuffle();
    update();
  }

  Future<void> update() async {
    await layersManager.updateBackground();
    updateNotifier.value++;
    await _saveSongIdList();
  }

  void delete() {
    try {
      _songIdListFile.deleteSync();
      _songMetadataListFile.deleteSync();
    } catch (e) {
      logger.output(e.toString());
    }
  }

  void clear() {
    songList = [];
    additionalSongList = [];
    validId = {};
    id2Song = {};
  }
}
