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
  final String path;
  final String? iosPath;
  late Directory? _dir;
  bool isWebdav;
  late File _songFilePathListFile;
  late File _songMetadataListFile;

  List<MyAudioMetadata> songList = [];
  List<MyAudioMetadata> additionalSongList = [];
  Map<String, MyAudioMetadata> filePath2Song = {};
  Set<String> validFilePath = {};

  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);

  final updateNotifier = ValueNotifier(0);

  Folder(
    this.path,
    String songFilePathListPath,
    String songMetadataListPath, {
    this.iosPath,
    this.isWebdav = false,
  }) {
    if (Platform.isIOS) {
      _dir = Directory(iosPath ?? '');
    } else if (!isWebdav) {
      _dir = Directory(path);
    }
    _songFilePathListFile = File(songFilePathListPath);
    if (!_songFilePathListFile.existsSync()) {
      _songFilePathListFile.writeAsStringSync('[]');
    }
    _songMetadataListFile = File(songMetadataListPath);
    if (!_songMetadataListFile.existsSync()) {
      _songMetadataListFile.writeAsStringSync('[]');
    }
  }

  static Future<Folder> from(Map<String, dynamic> map) async {
    String path = map['path'] as String;
    String songFilePathListPath = map['songFilePathListPath'] as String;
    String songMetadataListPath = map['songMetadataListPath'] as String;
    if (Platform.isIOS) {
      songFilePathListPath = appSupportDir.path + songFilePathListPath;
      songMetadataListPath = appSupportDir.path + songMetadataListPath;
    }
    bool isWebdav = path.startsWith('WebDAV:');
    if (isWebdav || !Platform.isIOS) {
      return Folder(
        path,
        songFilePathListPath,
        songMetadataListPath,
        isWebdav: isWebdav,
      );
    }
    String? iosPath;

    if (path.contains('Particle Music')) {
      iosPath = revertIOSPath(path);
    } else {
      iosPath = await BookmarkService.getUrlById(path);
      library.setIOSFileProviderStorageIfNeed(iosPath);
    }

    return Folder(
      path,
      iosPath: iosPath,
      songFilePathListPath,
      songMetadataListPath,
      isWebdav: false,
    );
  }

  static Future<Folder> create(String path) async {
    bool isWebdav = path.startsWith('WebDAV:');
    final uuid = Uuid();
    final songFilePathListPath = '${appSupportDir.path}/${uuid.v4()}.txt';
    final songMetadataListPath = '${appSupportDir.path}/${uuid.v4()}.txt';

    if (isWebdav || !Platform.isIOS) {
      return Folder(
        path,
        songFilePathListPath,
        songMetadataListPath,
        isWebdav: isWebdav,
      );
    }

    String iosPath = revertIOSPath(path);
    if (!path.startsWith('Particle Music')) {
      await BookmarkService.saveDirectoryAndActive(path, iosPath);
    }
    return Folder(
      path,
      iosPath: iosPath,
      songFilePathListPath,
      songMetadataListPath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'songFilePathListPath': Platform.isIOS
          ? _songFilePathListFile.path.split('Application Support').last
          : _songFilePathListFile.path,
      'songMetadataListPath': Platform.isIOS
          ? _songMetadataListFile.path.split('Application Support').last
          : _songMetadataListFile.path,
    };
  }

  Future<void> _prepare() async {
    final jsonString = await _songMetadataListFile.readAsString();
    final List<dynamic> list = jsonDecode(jsonString);
    for (final map in list) {
      final song = MyAudioMetadata.fromMap(map);
      filePath2Song[song.filePath!] = song;
    }
  }

  Future<void> _processSong(
    String filePath,
    String? iosPath,
    DateTime modified,
  ) async {
    MyAudioMetadata? song = filePath2Song[filePath];
    bool isAdditional = song == null;

    if (recursiveScanNotifier.value) {
      MyAudioMetadata? song = library.filePath2Song[filePath];
      if (song != null) {
        if (isAdditional) {
          additionalSongList.add(song);
        }

        filePath2Song[filePath] = song;
        validFilePath.add(filePath);
        return;
      }
    }

    if (song?.modified != modified) {
      final tmp = isWebdav
          ? await readMetadataAsync(filePath, false)
          : readMetadata(iosPath ?? filePath, false);

      if (tmp != null) {
        song = MyAudioMetadata(
          tmp,
          filePath: filePath,
          iosPath: iosPath,
          modified: modified,
          isWebdav: isWebdav,
        );

        if (isAdditional) {
          additionalSongList.add(song);
        }

        filePath2Song[filePath] = song;
      } else {
        song = null;
      }
    }
    if (song != null) {
      validFilePath.add(filePath);
      loadedCountNotifier.value++;
    }
  }

  Future<void> load() async {
    currentLoadingFolderNotifier.value = path;
    await _prepare();
    if (isWebdav) {
      if (webdavClient == null) {
        await setSongList(_songFilePathListFile, songList, filePath2Song);
        logger.output('There are no WebDAV client.');
        return;
      }

      try {
        final List<String> dirList = [path.substring(7)];
        if (recursiveScanNotifier.value) {
          dirList.addAll(await getWebdavSubDirectoriesFrom(path.substring(7)));
        }

        for (final dir in dirList) {
          final filelist = await webdavClient!.readDir(dir);
          for (final f in filelist) {
            if (f.isDir!) {
              continue;
            }
            final ext = extension(f.path!).toLowerCase();
            if (!_loftySupportedExts.contains(ext)) {
              continue;
            }
            final filePath = webdavBaseUrl + f.path!;

            await _processSong(filePath, null, f.mTime!);
          }
        }
      } catch (e) {
        // If it fails, keep the original data.
        await setSongList(_songFilePathListFile, songList, filePath2Song);
        additionalSongList.clear();
        logger.output(e.toString());
        return;
      }
    } else {
      if (!_dir!.existsSync()) {
        await setSongList(_songFilePathListFile, songList, filePath2Song);
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

        String filePath = file.path;
        final modified = (await file.stat()).modified;
        if (Platform.isIOS) {
          filePath = convertIOSPath(filePath);
          await _processSong(filePath, file.path, modified);
        } else {
          await _processSong(filePath, null, modified);
        }
      }
    }

    final Map<String, MyAudioMetadata> newFilePath2Song = {};

    for (final filePath in validFilePath) {
      newFilePath2Song[filePath] = filePath2Song[filePath]!;
    }
    filePath2Song = newFilePath2Song;

    await setSongList(_songFilePathListFile, songList, filePath2Song);
    songList.addAll(additionalSongList);

    await _saveSongFilePathList();
    await _saveSongMetadataList();
  }

  Future<void> _saveSongFilePathList() async {
    await _songFilePathListFile.writeAsString(
      jsonEncode(songList.map((e) => e.filePath!).toList()),
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
    await _saveSongFilePathList();
  }

  void delete() {
    try {
      _songFilePathListFile.deleteSync();
      _songMetadataListFile.deleteSync();
    } catch (e) {
      logger.output(e.toString());
    }
  }

  void clear() {
    songList = [];
    additionalSongList = [];
    validFilePath = {};
    filePath2Song = {};
  }
}
