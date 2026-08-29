import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/base/utils/path.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';

final playlistManager = PlaylistManager();

class PlaylistManager {
  late File _playlistsFile;

  List<Playlist> playlists = [];
  Map<String, Playlist> playlistMap = {};
  ValueNotifier<int> updateNotifier = ValueNotifier(0);
  final useLargePictureNotifier = ValueNotifier(true);

  PlaylistManager() {
    addPlaylist(Playlist(name: 'Favorite'));
  }

  Future<void> _prepare() async {
    _playlistsFile = File(
      "${getPlaylistConfigPath(sourceType)}/sylvakru_playlists.json",
    );
    initFile(_playlistsFile, true);

    final playlistNames = await readJsonListFile(_playlistsFile);
    for (final name in playlistNames) {
      final playlist = Playlist(name: name);
      addPlaylist(playlist);
    }
    if (isStreamSource) {
      final playlistMapList = await getStreamClient(sourceType)?.getPlaylists();
      if (playlistMapList != null) {
        for (final playlist in playlistMapList) {
          String id = playlist['id'];
          String name = playlist['name'];
          if (playlistMap[name] == null) {
            addPlaylist(Playlist(name: name));
          }
          playlistMap[name]!.id = id;
        }
      }
      playlists.removeWhere((e) => e.isNotFavorite && e.id == null);
      playlistMap.removeWhere((k, v) => v.isNotFavorite && v.id == null);
    }

    update();
  }

  Future<void> load() async {
    await _prepare();
    for (final playlist in playlists) {
      await playlist.load();
    }
  }

  Future<void> sync() async {
    playlists.clear();
    playlistMap.clear();

    addPlaylist(Playlist(name: 'Favorite'));
    updateNotifier.value++;

    await _prepare();
    for (final playlist in playlists) {
      await playlist.load();
    }
  }

  Playlist getPlaylistByIndex(int index) {
    assert(index >= 0 && index < playlists.length);
    return playlists[index];
  }

  Playlist? getPlaylistByName(String name) {
    return playlistMap[name];
  }

  void addPlaylist(Playlist playlist) {
    playlists.add(playlist);
    playlistMap[playlist.name] = playlist;
  }

  Future<void> createPlaylist(String name) async {
    for (Playlist playlist in playlists) {
      // check whether the name exists
      if (name == playlist.name) {
        return;
      }
    }

    final playlist = Playlist(name: name);
    if (isStreamSource) {
      playlist.id = await getStreamClient(sourceType)!.createPlaylist(name);
    }
    addPlaylist(playlist);

    update();
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    playlist.songListFile?.deleteSync();

    if (playlist.id != null) {
      await getStreamClient(sourceType)!.deletePlaylist(playlist.id!);
    }

    playlists.remove(playlist);
    playlistMap.remove(playlist.name);

    update();
  }

  void update() {
    _playlistsFile.writeAsStringSync(
      jsonEncode(playlists.map((pl) => pl.name).skip(1).toList()),
    );

    updateNotifier.value++;
  }

  void clear() {
    playlists.clear();
    playlistMap.clear();
  }
}

class Playlist {
  String name;

  String? id;

  File? songListFile;

  List<MyAudioMetadata> songList = [];

  late bool isFavorite;
  late bool isNotFavorite;

  final changeNotifier = ValueNotifier(0);
  final sortTypeNotifier = ValueNotifier(0);

  bool canModify = false;

  Playlist({required this.name}) {
    if (isNotStreamSource) {
      songListFile = File("${getPlaylistConfigPath(sourceType)}/$name.json");
      initFile(songListFile!, true);
    }

    isFavorite = name == 'Favorite';
    isNotFavorite = !isFavorite;
  }

  MyAudioMetadata? getCoverSong() {
    return getFirstSong(songList);
  }

  int get totalCount => songList.length;

  Future<void> load() async {
    canModify = false;
    songList.clear();
    changeNotifier.value++;
    if (isNotStreamSource) {
      final decoded = await readJsonListFile(songListFile!);
      for (String id in decoded) {
        MyAudioMetadata? song = library.id2Song[id];
        if (song == null) {
          continue;
        }
        songList.add(song);
        if (isFavorite) {
          song.isFavoriteNotifier.value = true;
        }
      }
      await songListFile!.writeAsString(
        jsonEncode(songList.map((e) => e.id).toList()),
      );
    } else {
      final client = getStreamClient(sourceType);

      List<Map<String, dynamic>>? tmpSongs;
      if (isFavorite) {
        tmpSongs = (await client?.getStarredSongs());
      } else {
        tmpSongs = (await client?.getPlaylistSongs(id!));
      }
      if (tmpSongs != null) {
        for (final map in tmpSongs) {
          final song = MyAudioMetadata.fromMap(map, sourceType);
          songList.add(song);
          if (isFavorite) {
            song.isFavoriteNotifier.value = true;
          }
        }
      }
    }

    canModify = true;
    changeNotifier.value++;
    layersManager.updateBackground();
  }

  Future<void> add(List<MyAudioMetadata> songList) async {
    for (MyAudioMetadata song in songList) {
      final targetSongList = this.songList;
      if (targetSongList.contains(song)) {
        continue;
      }
      targetSongList.insert(0, song);

      if (isFavorite) {
        song.isFavoriteNotifier.value = true;
      }
    }
    await update();
  }

  Future<void> remove(List<MyAudioMetadata> songList) async {
    for (MyAudioMetadata song in songList) {
      final targetSongList = this.songList;
      targetSongList.remove(song);

      if (isFavorite) {
        song.isFavoriteNotifier.value = false;
      }
    }
    await update();
  }

  Future<void> update() async {
    canModify = false;
    changeNotifier.value++;
    layersManager.updateBackground();

    final songIds = songList.map((e) => e.id).toList();
    await songListFile?.writeAsString(jsonEncode(songIds));
    if (isStreamSource) {
      final client = getStreamClient(sourceType);
      late bool success;
      if (isFavorite) {
        success = await client!.updateStarredSongs(songIds);
      } else {
        success = await navidromeClient!.updatePlaylistSongs(id!, songIds);
      }
      logger.output('update playlist: $name ${success ? 'success' : 'failed'}');
    }
    canModify = true;
    changeNotifier.value++;
  }
}

void toggleFavoriteState(MyAudioMetadata song) {
  final favorite = playlistManager.playlists.first;
  if (!favorite.canModify) {
    return;
  }
  final isFavorite = song.isFavoriteNotifier;
  if (isFavorite.value) {
    favorite.remove([song]);
  } else {
    favorite.add([song]);
  }
}
