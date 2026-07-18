import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/song_list_manager.dart';
import 'package:sylvakru/base/services/emby_client.dart';
import 'package:sylvakru/base/services/subsonic_client.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/base/utils/path.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/utils/source_type.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';

final playlistManager = PlaylistManager();

class PlaylistManager {
  late File _localFile;
  late File _webdavFile;
  late File _subsonicFile;
  late File _navidromeFile;
  late File _embyFile;

  List<Playlist> playlists = [];
  Map<String, Playlist> playlistsMap = {};
  ValueNotifier<int> updateNotifier = ValueNotifier(0);
  final useLargePictureNotifier = ValueNotifier(true);

  Future<void> initAllPlaylists() async {
    _localFile = File(
      "${getPlaylistConfigPath(.local)}/sylvakru_playlists.json",
    );
    if (!(_localFile.existsSync())) {
      _localFile.createSync(recursive: true);
      _localFile.writeAsStringSync(jsonEncode(['Favorite']));
    }

    _webdavFile = File(
      "${getPlaylistConfigPath(.webdav)}/sylvakru_playlists.json",
    );
    initFile(_webdavFile, true);

    _subsonicFile = File(
      "${getPlaylistConfigPath(.subsonic)}/sylvakru_playlists.json",
    );
    initFile(_subsonicFile, true);

    _navidromeFile = File(
      "${getPlaylistConfigPath(.navidrome)}/sylvakru_playlists.json",
    );
    initFile(_navidromeFile, true);

    _embyFile = File("${getPlaylistConfigPath(.emby)}/sylvakru_playlists.json");
    initFile(_embyFile, true);
  }

  Future<void> load() async {
    final localPlaylists = await readJsonListFile(_localFile);
    for (String name in localPlaylists) {
      addPlaylist(Playlist(name: name));
    }

    final webdavPlaylists = await readJsonListFile(_webdavFile);
    for (String name in webdavPlaylists) {
      playlistsMap[name]!.setWebdavFile();
    }

    final subsonicPlaylists = await readJsonListFile(_subsonicFile);
    for (final map in subsonicPlaylists) {
      String? id = map['id'];
      String name = map['name'];
      playlistsMap[name]!.subsonicId = id;
      playlistsMap[name]!.setSubsonicFile();
    }

    final navidromePlaylists = await readJsonListFile(_navidromeFile);
    for (final map in navidromePlaylists) {
      String? id = map['id'];
      String name = map['name'];
      playlistsMap[name]!.navidromeId = id;
      playlistsMap[name]!.setNavidromeFile();
    }

    final embyPlaylists = await readJsonListFile(_embyFile);
    for (final map in embyPlaylists) {
      String? id = map['id'];
      String name = map['name'];
      playlistsMap[name]!.embyId = id;
      playlistsMap[name]!.setEmbyFile();
    }

    for (final playlist in playlists) {
      await playlist.load();
    }
  }

  Future<void> prepareForSync(SourceType sourceType) async {
    if (sourceType == .webdav) {
      if (webdavClient == null) {
        for (final playlist in playlists) {
          await playlist.webdavFile?.delete();
          playlist.webdavFile = null;
        }
      }
    } else if (sourceType == .subsonic) {
      for (final playlist in playlists) {
        playlist.subsonicId = null;
        await playlist.subsonicFile?.delete();
        playlist.subsonicFile = null;
      }
      if (subsonicClient != null) {
        final subsonicPlaylists = await subsonicClient!.getPlaylists();
        for (final playlist in subsonicPlaylists) {
          String id = playlist['id'];
          String name = playlist['name'];
          if (playlistsMap[name] == null) {
            addPlaylist(Playlist(name: name));
          }
          playlistsMap[name]!.subsonicId = id;
          playlistsMap[name]!.setSubsonicFile();
        }
      }
    } else if (sourceType == .navidrome) {
      for (final playlist in playlists) {
        playlist.navidromeId = null;
        await playlist.navidromeFile?.delete();
        playlist.navidromeFile = null;
      }
      if (navidromeClient != null) {
        final navidromePlaylists = await navidromeClient!.getPlaylists();
        for (final playlist in navidromePlaylists) {
          String id = playlist['id'];
          String name = playlist['name'];
          if (playlistsMap[name] == null) {
            addPlaylist(Playlist(name: name));
          }
          playlistsMap[name]!.navidromeId = id;
          playlistsMap[name]!.setNavidromeFile();
        }
      }
    } else if (sourceType == .emby) {
      for (final playlist in playlists) {
        playlist.embyId = null;
        await playlist.embyFile?.delete();
        playlist.embyFile = null;
      }
      if (embyClient != null) {
        final embyPlaylists = await embyClient!.getPlaylists();
        for (final playlist in embyPlaylists) {
          String id = playlist['Id'];
          String name = playlist['Name'];
          if (playlistsMap[name] == null) {
            addPlaylist(Playlist(name: name));
          }
          playlistsMap[name]!.embyId = id;
          playlistsMap[name]!.setEmbyFile();
        }
      }
    }

    for (final playlist in playlists) {
      playlist.songListManager.prepareForSync(sourceType);
    }
  }

  Future<void> sync(SourceType sourceType) async {
    for (final playlist in playlists) {
      await playlist.sync(sourceType);
      playlist.songListManager.resetSourceType();
    }
    update();
  }

  Playlist getPlaylistByIndex(int index) {
    assert(index >= 0 && index < playlists.length);
    return playlists[index];
  }

  Playlist? getPlaylistByName(String name) {
    return playlistsMap[name];
  }

  void addPlaylist(Playlist playlist) {
    playlists.add(playlist);
    playlistsMap[playlist.name] = playlist;
  }

  Future<void> createPlaylist(String name) async {
    for (Playlist playlist in playlists) {
      // check whether the name exists
      if (name == playlist.name) {
        return;
      }
    }

    addPlaylist(Playlist(name: name));

    update();
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    playlist.localFile.deleteSync();
    playlist.webdavFile?.deleteSync();
    playlist.subsonicFile?.deleteSync();
    playlist.navidromeFile?.deleteSync();
    playlist.embyFile?.deleteSync();
    playlist._settingFile.deleteSync();
    if (playlist.subsonicId != null) {
      await subsonicClient!.deletePlaylist(playlist.subsonicId!);
    }
    if (playlist.navidromeId != null) {
      await navidromeClient!.deletePlaylist(playlist.navidromeId!);
    }
    if (playlist.embyId != null) {
      await embyClient!.deletePlaylist(playlist.embyId!);
    }
    playlists.remove(playlist);
    playlistsMap.remove(playlist.name);

    update();
  }

  void update() {
    _localFile.writeAsStringSync(
      jsonEncode(playlists.map((pl) => pl.name).toList()),
    );
    _webdavFile.writeAsStringSync(
      jsonEncode(
        playlists
            .where((pl) => pl.webdavFile != null)
            .map((pl) => pl.name)
            .toList(),
      ),
    );
    _subsonicFile.writeAsStringSync(
      jsonEncode(
        playlists
            .where((pl) => pl.subsonicFile != null)
            .map((pl) => {'id': pl.subsonicId, 'name': pl.name})
            .toList(),
      ),
    );

    _navidromeFile.writeAsStringSync(
      jsonEncode(
        playlists
            .where((pl) => pl.navidromeFile != null)
            .map((pl) => {'id': pl.navidromeId, 'name': pl.name})
            .toList(),
      ),
    );
    _embyFile.writeAsStringSync(
      jsonEncode(
        playlists
            .where((pl) => pl.embyFile != null)
            .map((pl) => {'id': pl.embyId, 'name': pl.name})
            .toList(),
      ),
    );
    updateNotifier.value++;
  }

  void clear() {
    playlists.clear();
    playlistsMap.clear();
  }
}

class Playlist {
  String name;

  String? subsonicId;
  String? navidromeId;
  String? embyId;

  late File localFile;
  File? webdavFile;
  File? subsonicFile;
  File? navidromeFile;
  File? embyFile;

  late File _settingFile;

  SongListManager songListManager = SongListManager();

  late bool isFavorite;
  late bool isNotFavorite;

  Playlist({required this.name}) {
    localFile = File("${getPlaylistConfigPath(.local)}/$name.json");
    initFile(localFile, true);

    _settingFile = File(
      "${getPlaylistConfigPath(.local)}/${name}_setting.json",
    );

    if (!_settingFile.existsSync()) {
      saveSetting();
    } else {
      loadSetting();
    }

    isFavorite = name == 'Favorite';
    isNotFavorite = !isFavorite;
  }

  void setWebdavFile() {
    webdavFile = File("${getPlaylistConfigPath(.webdav)}/$name.json");
    initFile(webdavFile!, true);
  }

  void setSubsonicFile() {
    subsonicFile = File("${getPlaylistConfigPath(.subsonic)}/$name.json");
    initFile(subsonicFile!, true);
  }

  void setNavidromeFile() {
    navidromeFile = File("${getPlaylistConfigPath(.navidrome)}/$name.json");
    initFile(navidromeFile!, true);
  }

  void setEmbyFile() {
    embyFile = File("${getPlaylistConfigPath(.emby)}/$name.json");
    initFile(embyFile!, true);
  }

  MyAudioMetadata? getCoverSong() {
    return getFirstSong(songListManager.getSongList());
  }

  int get totalCount => songListManager.totalCount;

  File? _getFile(SourceType sourceType) {
    switch (sourceType) {
      case .local:
        return localFile;
      case .webdav:
        return webdavFile;
      case .subsonic:
        return subsonicFile;
      case .navidrome:
        return navidromeFile;
      default:
        return embyFile;
    }
  }

  Future<void> _load(SourceType sourceType) async {
    final file = _getFile(sourceType);
    if (file == null) {
      return;
    }
    final decoded = await readJsonListFile(file);
    for (String id in decoded) {
      MyAudioMetadata? song = library.id2Song[id];
      if (song == null) {
        continue;
      }
      songListManager.getSongList2(sourceType).add(song);
      if (isFavorite) {
        song.isFavoriteNotifier.value = true;
      }
    }
    songListManager.getChangeNotifier2(sourceType).value++;
  }

  Future<void> load() async {
    for (final souceType in SourceType.values) {
      await _load(souceType);
    }

    songListManager.resetSourceType();
  }

  Future<void> sync(SourceType sourceType) async {
    switch (sourceType) {
      case .local:
        await _load(sourceType);
        break;
      case .webdav:
        if (webdavFile == null) {
          return;
        }
        await _load(sourceType);
        break;
      case .subsonic:
        if (subsonicClient == null || (isNotFavorite && subsonicId == null)) {
          return;
        }
        List<String> songIds = [];
        if (isFavorite) {
          songIds = await subsonicClient!.getFavoriteSongIds();
        } else {
          songIds = await subsonicClient!.getPlaylistSongIds(subsonicId!);
        }

        for (final songId in songIds) {
          final song = library.id2Song[songId];
          if (song == null) {
            continue;
          }
          songListManager.subsonicSongList.add(song);
          if (isFavorite) {
            song.isFavoriteNotifier.value = true;
          }
        }
        break;
      case .navidrome:
        if (navidromeClient == null || (isNotFavorite && navidromeId == null)) {
          return;
        }
        List<String> songIds = [];
        if (isFavorite) {
          songIds = await navidromeClient!.getFavoriteSongIds();
        } else {
          songIds = await navidromeClient!.getPlaylistSongIds(navidromeId!);
        }

        for (final songId in songIds) {
          final song = library.id2Song[songId];
          if (song == null) {
            continue;
          }
          songListManager.navidromeSongList.add(song);
          if (isFavorite) {
            song.isFavoriteNotifier.value = true;
          }
        }
        break;
      default:
        if (embyClient == null || (isNotFavorite && embyId == null)) {
          return;
        }
        List<String> songIds = [];
        if (embyClient != null) {
          if (isFavorite) {
            songIds = await embyClient!.getFavoriteSongIds();
          } else if (embyId != null) {
            songIds = await embyClient!.getPlaylistItems(embyId!);
          }
        }
        for (final songId in songIds) {
          final song = library.id2Song[songId];
          if (song == null) {
            continue;
          }
          songListManager.embySongList.add(song);
          if (isFavorite) {
            song.isFavoriteNotifier.value = true;
          }
        }
        break;
    }

    await update(getSourceTypeBitMask(sourceType));
  }

  Future<void> add(List<MyAudioMetadata> songList) async {
    int sourceTypeBitMask = 0;

    for (MyAudioMetadata song in songList) {
      final targetSongList = songListManager.getSongList2(song.sourceType);
      if (targetSongList.contains(song)) {
        continue;
      }
      targetSongList.insert(0, song);

      if (isFavorite) {
        song.isFavoriteNotifier.value = true;
      }

      sourceTypeBitMask |= getSourceTypeBitMask(song.sourceType);
    }
    await update(sourceTypeBitMask);
  }

  Future<void> remove(List<MyAudioMetadata> songList) async {
    int sourceTypeBitMask = 0;
    for (MyAudioMetadata song in songList) {
      final targetSongList = songListManager.getSongList2(song.sourceType);
      targetSongList.remove(song);

      if (isFavorite) {
        song.isFavoriteNotifier.value = false;
      }

      sourceTypeBitMask |= getSourceTypeBitMask(song.sourceType);
    }
    await update(sourceTypeBitMask);
  }

  Future<void> update(int sourceTypeBitMask) async {
    if ((sourceTypeBitMask & 1) == 1) {
      songListManager.localChangeNotifier.value++;
      await localFile.writeAsString(
        jsonEncode(songListManager.localSongList.map((e) => e.id).toList()),
      );
    }

    if ((sourceTypeBitMask & 2) == 2) {
      songListManager.webdavChangeNotifier.value++;
      if (webdavFile == null) {
        setWebdavFile();
      }
      await webdavFile!.writeAsString(
        jsonEncode(songListManager.webdavSongList.map((e) => e.id).toList()),
      );
    }

    if ((sourceTypeBitMask & 4) == 4) {
      songListManager.subsonicChangeNotifier.value++;
      if (subsonicClient != null) {
        if (isFavorite) {
          await subsonicClient!.unstarAllSongs();
          await subsonicClient!.starSongs(
            songListManager.subsonicSongList
                .map((e) => e.id)
                .toList()
                .reversed
                .toList(),
          );
        } else {
          if (subsonicId != null) {
            await subsonicClient!.deletePlaylist(subsonicId!);
          }
          subsonicId = await subsonicClient!.createPlaylistAndGetId(name);
          if (subsonicId != null) {
            await subsonicClient!.addSongsToPlaylist(
              subsonicId!,
              songListManager.subsonicSongList.map((e) => e.id).toList(),
            );
          }
        }
        if (subsonicFile == null) {
          setSubsonicFile();
        }
        await subsonicFile!.writeAsString(
          jsonEncode(
            songListManager.subsonicSongList.map((e) => e.id).toList(),
          ),
        );
      }
    }

    if ((sourceTypeBitMask & 8) == 8) {
      songListManager.navidromeChangeNotifier.value++;
      if (navidromeClient != null) {
        if (isFavorite) {
          await navidromeClient!.unstarAllSongs();
          await navidromeClient!.starSongs(
            songListManager.navidromeSongList
                .map((e) => e.id)
                .toList()
                .reversed
                .toList(),
          );
        } else {
          if (navidromeId != null) {
            await navidromeClient!.deletePlaylist(navidromeId!);
          }
          navidromeId = await navidromeClient!.createPlaylistAndGetId(name);
          if (navidromeId != null) {
            await navidromeClient!.addSongsToPlaylist(
              navidromeId!,
              songListManager.navidromeSongList.map((e) => e.id).toList(),
            );
          }
        }
        if (navidromeFile == null) {
          setNavidromeFile();
        }
        await navidromeFile!.writeAsString(
          jsonEncode(
            songListManager.navidromeSongList.map((e) => e.id).toList(),
          ),
        );
      }
    }

    if ((sourceTypeBitMask & 16) == 16) {
      songListManager.embyChangeNotifier.value++;
      if (embyClient != null) {
        if (isFavorite) {
          await embyClient!.rebuildFavorites(
            songListManager.embySongList
                .map((e) => e.id)
                .toList()
                .reversed
                .toList(),
          );
        } else {
          if (embyId != null) {
            await embyClient!.deletePlaylist(embyId!);
          }
          embyId = await embyClient?.createPlaylist(
            name: name,
            songIds: songListManager.embySongList.map((e) => e.id).toList(),
          );
        }
        if (embyFile == null) {
          setEmbyFile();
        }
        await embyFile!.writeAsString(
          jsonEncode(songListManager.embySongList.map((e) => e.id).toList()),
        );
      }
    }

    songListManager.resetSourceType();

    layersManager.updateBackground();
  }

  void loadSetting() {
    final json = readJsonMapFileSync(_settingFile);

    for (final sourceType in SourceType.values) {
      songListManager.getSortTypeNotifier2(sourceType).value =
          json[sourceType.name] ?? 0;
    }
  }

  void saveSetting() {
    _settingFile.writeAsStringSync(
      jsonEncode({
        for (final sourceType in SourceType.values)
          sourceType.name: songListManager
              .getSortTypeNotifier2(sourceType)
              .value,
      }),
    );
  }
}

void toggleFavoriteState(MyAudioMetadata song) {
  final favorite = playlistManager.playlists.first;
  final isFavorite = song.isFavoriteNotifier;
  if (isFavorite.value) {
    favorite.remove([song]);
  } else {
    favorite.add([song]);
  }
}
