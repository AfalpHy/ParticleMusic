import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/database.dart';
import 'package:sylvakru/base/data/song_list_manager.dart';
import 'package:sylvakru/base/extensions/metadata_extension.dart';
import 'package:sylvakru/base/services/dsd_metadata.dart';
import 'package:sylvakru/base/services/emby_client.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/open_sonic_client.dart';
import 'package:sylvakru/base/services/replay_gain.dart';
import 'package:sylvakru/base/services/song_list_service.dart';
import 'package:sylvakru/base/services/subsonic_client.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/base/utils/path.dart';
import 'package:sylvakru/base/data/folder.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:path/path.dart';
import 'package:pool/pool.dart';

final library = Library();

class ReplayGainMetadataChangedEvent {
  final String songId;

  const ReplayGainMetadataChangedEvent(this.songId);
}

class Library {
  late File _localSongIdListFile;
  late File _webdavSongIdListFile;
  late File _subsonicSongIdListFile;
  late File _navidromeSongIdListFile;
  late File _embySongIdListFile;

  late MetadataDB _localMetadataDB;
  late MetadataDB _webdavMetadataDB;
  late MetadataDB _subsonicMetadataDB;
  late MetadataDB _navidromeMetadataDB;
  late MetadataDB _embyMetadataDB;

  ValueNotifier<double> cacheSizeNotifier = ValueNotifier(0);
  final replayGainMetadataChangedNotifier =
      ValueNotifier<ReplayGainMetadataChangedEvent?>(null);

  Map<String, MyAudioMetadata> id2Song = {};

  SongListManager songListManager = SongListManager();

  late final File _localFolderIdListFile;
  late final File _webdavFolderIdListFile;
  List<Folder> localFolderList = [];
  List<Folder> webdavFolderList = [];
  final folderListChangeNotifier = ValueNotifier(0);
  String? iosFileProviderStorage;

  late File _fontMapFile;
  Map<String, List<String>> _fontMap = {};

  Library() {
    _localSongIdListFile = File(
      "${appSupportDir.path}/local/song_id_list.json",
    );
    initFile(_localSongIdListFile, true);

    _webdavSongIdListFile = File(
      "${appSupportDir.path}/webdav/song_id_list.json",
    );
    initFile(_webdavSongIdListFile, true);

    _subsonicSongIdListFile = File(
      "${appSupportDir.path}/subsonic/song_id_list.json",
    );
    initFile(_subsonicSongIdListFile, true);

    _navidromeSongIdListFile = File(
      "${appSupportDir.path}/navidrome/song_id_list.json",
    );
    initFile(_navidromeSongIdListFile, true);

    _embySongIdListFile = File("${appSupportDir.path}/emby/song_id_list.json");
    initFile(_embySongIdListFile, true);

    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    _localMetadataDB = MetadataDB(openMetadataDB('local/metadata.db'));
    _webdavMetadataDB = MetadataDB(openMetadataDB('webdav/metadata.db'));
    _subsonicMetadataDB = MetadataDB(openMetadataDB('subsonic/metadata.db'));
    _navidromeMetadataDB = MetadataDB(openMetadataDB('navidrome/metadata.db'));
    _embyMetadataDB = MetadataDB(openMetadataDB('emby/metadata.db'));

    _localFolderIdListFile = File(
      "${getFolderConfigPath(.local)}/folder_id_list.json",
    );
    initFile(_localFolderIdListFile, true);

    _webdavFolderIdListFile = File(
      "${getFolderConfigPath(.webdav)}/folder_id_list.json",
    );
    initFile(_webdavFolderIdListFile, true);

    _fontMapFile = File("${appSupportDir.path}/fonts/font_map.json");
    initFile(_fontMapFile, false);
  }

  Future<void> _initLocalFolders() async {
    List<dynamic> folderIdList = jsonDecode(
      await _localFolderIdListFile.readAsString(),
    );

    for (final id in folderIdList) {
      localFolderList.add(await Folder.from(id, false));
    }
  }

  Future<void> _initWebdavFolders() async {
    List<dynamic> folderIdList = jsonDecode(
      await _webdavFolderIdListFile.readAsString(),
    );

    for (final id in folderIdList) {
      webdavFolderList.add(await Folder.from(id, true));
    }
  }

  Future<void> initAllFolders() async {
    await _initLocalFolders();
    await _initWebdavFolders();
  }

  Future<void> loadFonts() async {
    _fontMap =
        (jsonDecode(_fontMapFile.readAsStringSync()) as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, List<String>.from(value)));
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

  Future<bool> updateFolders(List<String> idList, bool isLocal) async {
    bool needUpdate = false;
    final folderList = isLocal ? localFolderList : webdavFolderList;
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
        newFolderList.add(await Folder.create(id, !isLocal));
      }
    }

    for (final folder in folderList) {
      if (newFolderList.contains(folder)) {
        continue;
      }
      folder.delete();
      layersManager.removeLayerIfNeed(folder);
    }

    if (isLocal) {
      localFolderList = newFolderList;
      await _localFolderIdListFile.writeAsString(
        jsonEncode(localFolderList.map((e) => e.id).toList()),
      );
    } else {
      webdavFolderList = newFolderList;
      await _webdavFolderIdListFile.writeAsString(
        jsonEncode(webdavFolderList.map((e) => e.id).toList()),
      );
    }

    folderListChangeNotifier.value++;
    return true;
  }

  Folder? getFolderById(String id) {
    for (final folder in localFolderList) {
      if (folder.id == id) {
        return folder;
      }
    }

    for (final folder in webdavFolderList) {
      if (folder.id == id) {
        return folder;
      }
    }
    return null;
  }

  Future<void> _prepare() async {
    for (final sourceType in SourceType.values) {
      final db = _getMetadataDB(sourceType);
      final rows = await db.select(db.metadataItems).get();
      for (final row in rows) {
        id2Song.putIfAbsent(row.id, () => row.toMetadata());
      }
    }
  }

  Future<void> _loadLocal() async {
    for (final folder in localFolderList) {
      await folder.load();
    }
    await loadSongList(_localSongIdListFile, songListManager.localSongList);
  }

  Future<void> _loadWebdav() async {
    for (final folder in webdavFolderList) {
      await folder.load();
    }
    await loadSongList(_webdavSongIdListFile, songListManager.webdavSongList);
  }

  Future<void> _loadSubsonic() async {
    await loadSongList(
      _subsonicSongIdListFile,
      songListManager.subsonicSongList,
    );
  }

  Future<void> _loadNavidrome() async {
    await loadSongList(
      _navidromeSongIdListFile,
      songListManager.navidromeSongList,
    );
  }

  Future<void> _loadEmby() async {
    await loadSongList(_embySongIdListFile, songListManager.embySongList);
  }

  Future<void> load() async {
    await _prepare();
    await _loadLocal();
    await _loadWebdav();
    await _loadSubsonic();
    await _loadNavidrome();
    await _loadEmby();

    songListManager.resetSourceType();

    for (final sourceType in SourceType.values) {
      await _accumulateCache(sourceType);
    }
  }

  Future<void> _accumulateCache(SourceType sourceType) async {
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

  final Map<String, Future<void>> _cacheDownloads = {};
  final Map<String, CancelToken> _cacheDownloadCancelTokens = {};
  final Set<String> _replayGainApiChecked = {};
  final Map<String, Future<void>> _replayGainApiRefreshes = {};
  final Set<String> _replayGainCacheChecked = {};

  Future<void> supplementReplayGainForPlayback(MyAudioMetadata song) async {
    final client = switch (song.sourceType) {
      .subsonic => subsonicClient,
      .navidrome => navidromeClient,
      _ => null,
    };
    final apiKey = '${song.sourceType.name}:${song.id}';
    final metadataComplete =
        song.replayGainTrackGainDb != null &&
        song.replayGainTrackPeak != null &&
        song.replayGainAlbumGainDb != null &&
        song.replayGainAlbumPeak != null;
    if (client != null && !metadataComplete) {
      final inFlight = _replayGainApiRefreshes[apiKey];
      if (inFlight != null) {
        await inFlight;
      } else if (!_replayGainApiChecked.contains(apiKey)) {
        final refresh = _supplementReplayGainFromApi(
          song,
          client,
          apiKey,
        ).whenComplete(() => _replayGainApiRefreshes.remove(apiKey));
        _replayGainApiRefreshes[apiKey] = refresh;
        await refresh;
      }
    }
    if (song.cacheExist && song.cachePath != null) {
      await _supplementCachedReplayGain(song, song.cachePath!);
    }
  }

  Future<void> _supplementReplayGainFromApi(
    MyAudioMetadata song,
    OpenSubsonicClient client,
    String apiKey,
  ) async {
    try {
      final songMap = await client
          .getSong(song.id)
          .timeout(const Duration(milliseconds: 1500));
      if (songMap == null) {
        return;
      }
      _replayGainApiChecked.add(apiKey);
      final apiSong = MyAudioMetadata.fromOpenSonicMap(
        songMap,
        song.sourceType,
      );
      if (!supplementReplayGainValues(
        song,
        trackGain: apiSong.replayGainTrackGainDb,
        trackPeak: apiSong.replayGainTrackPeak,
        albumGain: apiSong.replayGainAlbumGainDb,
        albumPeak: apiSong.replayGainAlbumPeak,
      )) {
        return;
      }
      await updateMetadata(song);
      replayGainMetadataChangedNotifier.value = ReplayGainMetadataChangedEvent(
        song.id,
      );
    } on TimeoutException {
      logger.output('OpenSubsonic ReplayGain request timed out: ${song.id}');
    } catch (e) {
      logger.output('OpenSubsonic ReplayGain refresh failed: $e');
    }
  }

  Future<void> tryAddCache(MyAudioMetadata song) {
    if (song.sourceType == .local) {
      return Future.value();
    }
    if (song.cacheExist) {
      final savePath = song.cachePath;
      return savePath == null
          ? Future.value()
          : _supplementCachedReplayGain(song, savePath);
    }
    final savePath = song.cachePath!;
    final inFlight = _cacheDownloads[savePath];
    if (inFlight != null) {
      if (_cacheDownloadCancelTokens[savePath]?.isCancelled == true) {
        return inFlight.whenComplete(() => tryAddCache(song));
      }
      return inFlight;
    }
    final cancelToken = CancelToken();
    final download = _downloadCache(song, savePath, cancelToken).whenComplete(
      () {
        _cacheDownloads.remove(savePath);
        _cacheDownloadCancelTokens.remove(savePath);
      },
    );
    _cacheDownloads[savePath] = download;
    _cacheDownloadCancelTokens[savePath] = cancelToken;
    return download;
  }

  void cancelCacheDownload(MyAudioMetadata song) {
    final savePath = song.cachePath;
    if (savePath != null) {
      _cacheDownloadCancelTokens[savePath]?.cancel();
    }
  }

  Future<void> _downloadCache(
    MyAudioMetadata song,
    String savePath,
    CancelToken cancelToken,
  ) async {
    final partPath = '$savePath.part';
    final stale = File(partPath);
    if (await stale.exists()) {
      await stale.delete();
    }
    while (!cancelToken.isCancelled) {
      final completed = switch (song.sourceType) {
        .webdav => await webdavClient!.download(
          remotePath: song.path!,
          localPath: partPath,
          cancelToken: cancelToken,
        ),
        .subsonic => await _downloadOpenSubsonic(
          subsonicClient!,
          song.id,
          partPath,
          cancelToken,
        ),
        .navidrome => await _downloadOpenSubsonic(
          navidromeClient!,
          song.id,
          partPath,
          cancelToken,
        ),
        .emby => await embyClient!.downloadSong(
          itemId: song.id,
          savePath: partPath,
          cancelToken: cancelToken,
        ),
        .local => false,
      };
      final part = File(partPath);
      if (completed && await part.exists()) {
        await part.rename(savePath);
        song.cacheExist = true;
        cacheSizeNotifier.value +=
            await File(savePath).length() / (1024 * 1024);
        await _supplementCachedReplayGain(song, savePath);
        return;
      }
      if (!cancelToken.isCancelled) {
        logger.output('cache download retry:${song.title}');
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _supplementCachedReplayGain(
    MyAudioMetadata song,
    String savePath,
  ) async {
    if (!_replayGainCacheChecked.add(savePath)) {
      return;
    }
    if (song.replayGainTrackGainDb != null &&
        song.replayGainTrackPeak != null &&
        song.replayGainAlbumGainDb != null &&
        song.replayGainAlbumPeak != null) {
      return;
    }
    try {
      final metadata = song.isDsd
          ? await readDsdMetadata(savePath)
          : await readMetadataAsync(savePath, false);
      if (metadata == null) {
        return;
      }
      if (!supplementReplayGainMetadata(song, metadata)) {
        return;
      }
      await updateMetadata(song);
      replayGainMetadataChangedNotifier.value = ReplayGainMetadataChangedEvent(
        song.id,
      );
    } catch (e) {
      try {
        logger.output('cache ReplayGain metadata read failed: $e');
      } catch (_) {}
    }
  }

  Future<bool> _downloadOpenSubsonic(
    OpenSubsonicClient client,
    String songId,
    String savePath,
    CancelToken cancelToken,
  ) async {
    return client.downloadSong(
      songId: songId,
      savePath: savePath,
      cancelToken: cancelToken,
    );
  }

  Future<void> clearCache(SourceType sourceType) async {
    for (final song in songListManager.getSongList2(sourceType)) {
      cancelCacheDownload(song);
      song.cacheExist = false;
    }

    Directory cacheDir = Directory(getCachesPath(sourceType));
    int totalSize = 0;
    if (await cacheDir.exists()) {
      await for (final file in cacheDir.list()) {
        if (file is File) {
          totalSize += file.lengthSync();
          await file.delete();
        }
      }
    }

    cacheSizeNotifier.value -= totalSize / (1024 * 1024);
    _replayGainCacheChecked.clear();
  }

  Future<void> clearPicture(SourceType sourceType) async {
    for (final song in songListManager.getSongList2(sourceType)) {
      song.pictureLoaded = false;
      song.pictureExist = false;
    }

    Directory pictureDir = Directory(getPicturesPath(sourceType));
    if (await pictureDir.exists()) {
      await for (final file in pictureDir.list()) {
        await file.delete();
      }
    }
  }

  File _getSongIdListFile(SourceType sourceType) {
    switch (sourceType) {
      case .local:
        return _localSongIdListFile;
      case .webdav:
        return _webdavSongIdListFile;
      case .subsonic:
        return _subsonicSongIdListFile;
      case .navidrome:
        return _navidromeSongIdListFile;
      default:
        return _embySongIdListFile;
    }
  }

  MetadataDB _getMetadataDB(SourceType sourceType) {
    switch (sourceType) {
      case .local:
        return _localMetadataDB;
      case .webdav:
        return _webdavMetadataDB;
      case .subsonic:
        return _subsonicMetadataDB;
      case .navidrome:
        return _navidromeMetadataDB;
      default:
        return _embyMetadataDB;
    }
  }

  Future<void> _saveSongIdList(SourceType sourceType) async {
    await _getSongIdListFile(sourceType).writeAsString(
      jsonEncode(
        songListManager.getSongList2(sourceType).map((e) => e.id).toList(),
      ),
    );
  }

  Future<void> _saveMetadata(SourceType sourceType) async {
    final metadataDB = _getMetadataDB(sourceType);

    await metadataDB.transaction(() async {
      await metadataDB.delete(metadataDB.metadataItems).go();

      await metadataDB.batch((batch) {
        batch.insertAll(
          metadataDB.metadataItems,
          songListManager
              .getSongList2(sourceType)
              .map((e) => e.toCompanion())
              .toList(),
        );
      });
    });
  }

  Future<void> updatePlayCount(MyAudioMetadata song) async {
    final metadataDB = _getMetadataDB(song.sourceType);

    await (metadataDB.update(
      metadataDB.metadataItems,
    )..where((t) => t.id.equals(song.id))).write(
      MetadataItemsCompanion(
        playCount: Value(song.playCount),
        lastPlayed: Value(song.lastPlayed!.millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> updateMetadata(MyAudioMetadata song) async {
    final metadataDB = _getMetadataDB(song.sourceType);

    await (metadataDB.update(
      metadataDB.metadataItems,
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
        replayGainTrackGainDb: Value(song.replayGainTrackGainDb),
        replayGainTrackPeak: Value(song.replayGainTrackPeak),
        replayGainAlbumGainDb: Value(song.replayGainAlbumGainDb),
        replayGainAlbumPeak: Value(song.replayGainAlbumPeak),
      ),
    );
  }

  void shuffle(SourceType sourceType) {
    songListManager.getSongList2(sourceType).shuffle();
    update(sourceType);
  }

  void update(SourceType sourceType) {
    songListManager.getChangeNotifier2(sourceType).value++;
    layersManager.updateBackground();
    _saveSongIdList(sourceType);
  }

  void _syncNotify(SourceType sourceType) {
    songListManager.getChangeNotifier2(sourceType).value++;
    songListManager.resetSourceType();
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
        final ext = extension(realPath).toLowerCase();
        if (ext == '.dsf' || ext == '.dff') {
          tmp = isWebdav && realPath == path
              ? await readRemoteDsdMetadata(path, headers: headers)
              : await readDsdMetadata(realPath);
        } else {
          tmp = await readMetadataAsync(realPath, false, headers: headers);
        }
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

  Future<void> prepareForSync(SourceType sourceType) async {
    await library.clearCache(sourceType);
    await library.clearPicture(sourceType);

    songListManager.prepareForSync(sourceType);
    if (sourceType == .local || sourceType == .webdav) {
      final folderList = sourceType == .local
          ? localFolderList
          : webdavFolderList;

      for (final folder in folderList) {
        folder.songList.clear();
        folder.changeNotifier.value++;
      }
    }
  }

  Future<void> sync(SourceType sourceType) async {
    switch (sourceType) {
      case .local:
      case .webdav:
        Map<String, DateTime> pathAndModified = {};
        final folderList = sourceType == .local
            ? localFolderList
            : webdavFolderList;

        for (final folder in folderList) {
          await folder.setFileAndModified();
          pathAndModified.addAll(folder.pathAndModified);
        }

        final List<dynamic> songIdList = jsonDecode(
          await _getSongIdListFile(sourceType).readAsString(),
        );

        final pool = Pool(6);

        final tasks = <Future>[];

        Set<String> validId = {};

        Future<void> syncOne(String id, String path, DateTime modified) async {
          final song = await _parseMetadataIfNeed(id, path, modified);
          if (song != null) {
            validId.add(id);
            songListManager.getSongList2(sourceType).add(song);
            if (validId.length % 50 == 0) {
              _syncNotify(sourceType);
            }
          }
        }

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

        id2Song.removeWhere(
          (id, song) => song.sourceType == sourceType && !validId.contains(id),
        );

        for (final folder in folderList) {
          await folder.sync();
          folder.clearPathAndModified();
        }

        await pool.close();
        break;
      case .subsonic:
        id2Song.removeWhere((id, song) => song.sourceType == sourceType);
        if (subsonicClient != null) {
          await for (final batch in subsonicClient!.getSongs()) {
            for (final map in batch) {
              MyAudioMetadata song = MyAudioMetadata.fromOpenSonicMap(
                map,
                .subsonic,
              );
              songListManager.subsonicSongList.add(song);
              id2Song[song.id] = song;
            }
            _syncNotify(sourceType);
          }
        }
        break;
      case .navidrome:
        id2Song.removeWhere((id, song) => song.sourceType == sourceType);
        if (navidromeClient != null) {
          await for (final batch in navidromeClient!.getSongs()) {
            for (final map in batch) {
              MyAudioMetadata song = MyAudioMetadata.fromOpenSonicMap(
                map,
                .navidrome,
              );
              songListManager.navidromeSongList.add(song);
              id2Song[song.id] = song;
            }
            _syncNotify(sourceType);
          }
        }
        break;
      default:
        id2Song.removeWhere((id, song) => song.sourceType == sourceType);
        if (embyClient != null) {
          await for (final batch in embyClient!.getAllSongs()) {
            for (final map in batch) {
              final song = MyAudioMetadata.fromEmbyMap(map);
              songListManager.embySongList.add(song);
              id2Song[song.id] = song;
            }
            _syncNotify(sourceType);
          }
        }
        break;
    }

    _syncNotify(sourceType);

    await _saveSongIdList(sourceType);
    await _saveMetadata(sourceType);
  }
}
