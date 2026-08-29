import 'dart:convert';
import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/database.dart';
import 'package:sylvakru/base/extensions/metadata_extension.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/base/utils/path.dart';
import 'package:sylvakru/base/data/folder.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:path/path.dart';
import 'package:pool/pool.dart';

final library = Library();

class Library {
  MetadataDB? _metadataDB;

  final ValueNotifier<double> cacheSizeNotifier = ValueNotifier(0);

  final Map<String, MyAudioMetadata> id2Song = {};
  final List<MyAudioMetadata> songList = [];

  final changeNotifier = ValueNotifier(0);

  File? _folderIdListFile;
  List<Folder> folderList = [];
  final folderListChangeNotifier = ValueNotifier(0);
  String? iosFileProviderStorage;

  late File _fontMapFile;
  Map<String, List<String>> _fontMap = {};

  SourceType? last;

  bool canModify = false;

  Future<void> prepare() async {
    if (last == sourceType) {
      return;
    }
    last = sourceType;
    _metadataDB = null;
    _folderIdListFile = null;
    if (isNotStreamSource) {
      _metadataDB = MetadataDB(
        openMetadataDB('${sourceType.name}/metadata.db'),
      );
      _folderIdListFile = File(
        "${getFolderConfigPath(sourceType)}/folder_id_list.json",
      );
      initFile(_folderIdListFile!, true);

      final folderIdList = await readJsonListFile(_folderIdListFile!);

      for (final id in folderIdList) {
        folderList.add(await Folder.from(id, sourceType == .webdav));
      }
    }
  }

  Future<void> loadFonts() async {
    _fontMapFile = File("${appSupportDir.path}/fonts/font_map.json");
    initFile(_fontMapFile, false);

    _fontMap = readJsonMapFileSync(
      _fontMapFile,
    ).map((key, value) => MapEntry(key, List<String>.from(value)));
    for (final entry in _fontMap.entries) {
      final name = entry.key;
      final fontPathList = entry.value;
      final loader = FontLoader(name);

      for (final fontPath in fontPathList) {
        final fontFile = File("${appSupportDir.path}/fonts/$fontPath");
        if (!fontFile.existsSync()) {
          continue;
        }
        final bytes = fontFile.readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
      await loader.load();
      importedFonts.add(name);
    }
  }

  Future<void> addFonts(String name, List<String> paths) async {
    for (String path in paths) {
      File originFile = File(path);
      path = basename(path);
      originFile.copySync("${appSupportDir.path}/fonts/$path");
      _fontMap
          .putIfAbsent(name, () {
            return [];
          })
          .add(path);
    }

    await _fontMapFile.writeAsString(json.encode(_fontMap));
  }

  Future<void> deleteFonts(String name) async {
    if (_fontMap[name] == null) {
      return;
    }
    for (final path in _fontMap[name]!) {
      final tmp = File("${appSupportDir.path}/fonts/$path");
      if (await tmp.exists()) {
        await tmp.delete();
      }
    }
    _fontMap.remove(name);
    importedFonts.remove(name);
    await _fontMapFile.writeAsString(json.encode(_fontMap));
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
        newFolderList.add(await Folder.create(id, sourceType == .webdav));
      }
    }

    for (final folder in folderList) {
      if (newFolderList.contains(folder)) {
        continue;
      }
      folder.delete();
      layersManager.removeLayerIfNeed(folder);
    }

    folderList = newFolderList;
    await _folderIdListFile!.writeAsString(
      jsonEncode(folderList.map((e) => e.id).toList()),
    );

    folderListChangeNotifier.value++;
    return true;
  }

  Folder? getFolderById(String id) {
    for (final folder in folderList) {
      if (folder.id == id) {
        return folder;
      }
    }

    return null;
  }

  Future<void> load() async {
    await prepare();
    if (isNotStreamSource) {
      List<MetadataItem> rows = [];
      int offset = 0;

      do {
        rows = await (_metadataDB!.select(
          _metadataDB!.metadataItems,
        )..limit(10000, offset: offset)).get();

        if (rows.isEmpty) {
          break;
        }

        for (final row in rows) {
          final song = row.toMetadata();
          id2Song.putIfAbsent(row.id, () => song);
          songList.add(song);
          artistAlbumManager.processSong(song);
        }

        changeNotifier.value++;
        layersManager.updateBackground();
        offset += rows.length;
      } while (true);

      canModify = true;
      changeNotifier.value++;

      for (final folder in folderList) {
        await folder.load();
      }
    }

    await _accumulateCache();
  }

  Future<void> _accumulateCache() async {
    Directory cacheDir = Directory(getCachesPath(sourceType));
    if (!await cacheDir.exists()) {
      return;
    }
    int total = 0;
    await for (final file in cacheDir.list()) {
      if (file is File) {
        total += await file.length();
      }
    }
    cacheSizeNotifier.value += total / (1024 * 1024);
  }

  Future<void> tryAddCache(MyAudioMetadata song) async {
    if (song.sourceType == .local || song.cacheExist) {
      return;
    }
    final savePath = song.cachePath!;
    if (song.sourceType == .webdav) {
      await webdavClient!.download(remotePath: song.path!, localPath: savePath);
    } else {
      await getStreamClient(song.sourceType)!.downloadSong(song.id, savePath);
    }
    final tmp = File(savePath);
    if (await tmp.exists()) {
      song.cacheExist = true;
      cacheSizeNotifier.value += await tmp.length() / (1024 * 1024);
    }
  }

  Future<void> clearCache() async {
    Directory cacheDir = Directory(getCachesPath(sourceType));
    if (await cacheDir.exists()) {
      await for (final file in cacheDir.list()) {
        if (file is File) {
          await file.delete();
        }
      }
    }

    cacheSizeNotifier.value = 0;
  }

  Future<void> clearPicture() async {
    for (final song in songList) {
      song.picture.reset();
    }
    Directory pictureDir = Directory(getPicturesPath(sourceType));
    if (await pictureDir.exists()) {
      await for (final file in pictureDir.list()) {
        await file.delete();
      }
    }
  }

  Future<void> _saveMetadata() async {
    final db = _metadataDB!;
    await db.transaction(() async {
      await db.delete(db.metadataItems).go();

      await db.batch((batch) {
        batch.insertAll(
          db.metadataItems,
          songList.map((e) => e.toCompanion()).toList(),
        );
      });
    });
  }

  Future<void> updatePlayCount(MyAudioMetadata song) async {
    final db = _metadataDB!;
    await (db.update(
      db.metadataItems,
    )..where((t) => t.id.equals(song.id))).write(
      MetadataItemsCompanion(
        playCount: Value(song.playCount),
        lastPlayed: Value(song.lastPlayed!.millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> updateDuration(MyAudioMetadata song, Duration duration) async {
    final db = _metadataDB!;
    await (db.update(
      db.metadataItems,
    )..where((t) => t.id.equals(song.id))).write(
      MetadataItemsCompanion(duration: Value(duration.inMilliseconds)),
    );
    song.duration = duration;
    song.updateNotifier.value++;
  }

  Future<void> updateMetadata(MyAudioMetadata song) async {
    final db = _metadataDB!;
    await (db.update(
      db.metadataItems,
    )..where((t) => t.id.equals(song.id))).write(
      MetadataItemsCompanion(
        title: Value(song.title),
        artist: Value(song.artist),
        album: Value(song.album),
        genre: Value(song.genre),
        lyrics: Value(song.lyrics),
        year: Value(song.year),
        track: Value(song.track),
        disc: Value(song.disc),
      ),
    );
  }

  void shuffle() {
    songList.shuffle();
    update();
  }

  void update() {
    changeNotifier.value++;
    layersManager.updateBackground();
    if (isNotStreamSource) {
      _saveMetadata();
    }
  }

  void _syncNotify() {
    changeNotifier.value++;
    layersManager.updateBackground();
  }

  Future<MyAudioMetadata?> _parseMetadataIfNeed(
    String id,
    String path,
    DateTime modified,
  ) async {
    MyAudioMetadata? song = library.id2Song[id];

    if (song?.modified != modified) {
      String realPath = path;
      Map<String, String>? headers;
      bool isWebdav = path.startsWith('http://') || path.startsWith('https://');
      if (isWebdav) {
        final tmpPath = await convertToRealPathIfNeed(path);
        if (tmpPath == null) {
          headers = webdavClient?.headers;
        } else {
          realPath = tmpPath;
        }
      }
      AudioMetadata? tmp;
      try {
        tmp = await readMetadataAsync(realPath, false, headers: headers);
      } catch (e) {
        logger.output("$path: $e");
      }

      if (tmp != null) {
        song = MyAudioMetadata(
          tmp,
          id: id,
          path: path,
          modified: modified,
          sourceType: isWebdav ? .webdav : .local,
        );
      } else {
        song = null;
      }
    }
    if (song != null) {
      library.id2Song[id] = song;
    } else {
      library.id2Song.remove(id);
    }
    return song;
  }

  Future<void> sync() async {
    canModify = false;
    await library.clearCache();
    await library.clearPicture();

    await prepare();

    switch (sourceType) {
      case .local:
      case .webdav:
        Map<String, DateTime> pathAndModified = {};

        final updateCount = sourceType == .local ? 1000 : 25;

        for (final folder in folderList) {
          folder.songList.clear();
          folder.changeNotifier.value++;
          await folder.setFileAndModified();
          pathAndModified.addAll(folder.pathAndModified);
        }

        final pool = Pool(6);

        final tasks = <Future>[];

        Set<String> validId = {};

        Future<void> syncOne(String id, String path, DateTime modified) async {
          final song = await _parseMetadataIfNeed(id, path, modified);
          if (song != null) {
            validId.add(id);
            songList.add(song);
            artistAlbumManager.processSong(song);
            if (validId.length % updateCount == 0) {
              _syncNotify();
            }
          }
        }

        final songIdList = songList.map((e) => e.id).toList();
        songList.clear();

        changeNotifier.value++;

        for (final id in songIdList) {
          String path = id;

          DateTime? modified;
          if (sourceType == .local) {
            if (Platform.isIOS) {
              path = revertIOSPath(path);
            }
            modified = pathAndModified.remove(path);
          } else {
            if (webdavClient != null) {
              modified = pathAndModified.remove(
                path.substring(webdavClient!.cleanBaseUrl.length),
              );
            }
          }

          if (modified != null) {
            tasks.add(
              pool.withResource(() async {
                await syncOne(id, path, modified!);
              }),
            );
          }
        }

        await Future.wait(tasks);

        for (final entry in pathAndModified.entries) {
          String path = entry.key;
          String id = path;
          if (sourceType == .webdav) {
            path = webdavClient!.cleanBaseUrl + path;
            id = path;
          } else if (Platform.isIOS) {
            id = convertIOSPath(path);
          }
          tasks.add(pool.withResource(() => syncOne(id, path, entry.value)));
        }

        await Future.wait(tasks);

        id2Song.removeWhere((id, song) => !validId.contains(id));

        for (final folder in folderList) {
          await folder.sync();
          folder.clearPathAndModified();
        }

        await pool.close();
        await _saveMetadata();
      default:
        id2Song.clear();
        songList.clear();
    }

    canModify = true;
    _syncNotify();
  }
}
