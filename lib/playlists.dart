import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/navidrome_client.dart';
import 'package:particle_music/utils.dart';

class PlaylistsManager {
  late File file;
  List<Playlist> playlists = [];
  Map<String, Playlist> playlistsMap = {};
  ValueNotifier<int> updateNotifier = ValueNotifier(0);

  PlaylistsManager() {
    file = File("${playlistConfigDir.path}/particle_music_playlists.json");
    if (!(file.existsSync())) {
      file.writeAsStringSync(jsonEncode(['Favorite']));
    }
  }

  Future<void> initAllPlaylists() async {
    List<dynamic> allPlaylists = jsonDecode(await file.readAsString());
    for (String name in allPlaylists) {
      final playlist = Playlist(name: name);
      playlistsManager.addPlaylist(playlist);
    }
  }

  Future<void> load() async {
    if (navidromeClient.valid) {
      final navidromePlaylists = await navidromeClient.getPlaylists();
      for (final playlist in navidromePlaylists) {
        String id = playlist['id'];
        String name = playlist['name'];
        if (playlistsMap[name] == null) {
          addPlaylist(Playlist(name: name));
        }
        playlistsMap[name]!.id = id;
      }
      // navidrome may add some playlists
      update();
    }
    for (final playlist in playlists) {
      await playlist.load();
    }
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

    final playlist = Playlist(name: name);
    playlist.id = await navidromeClient.createPlaylistAndGetId(name);
    addPlaylist(playlist);

    update();
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    playlist.file.deleteSync();
    playlist.settingFile.deleteSync();
    if (playlist.id != null) {
      await navidromeClient.deletePlaylist(playlist.id!);
    }
    playlists.remove(playlist);
    playlistsMap.remove(playlist.name);

    update();
  }

  void update() {
    file.writeAsString(jsonEncode(playlists.map((pl) => pl.name).toList()));
    updateNotifier.value++;
  }

  void clear() {
    for (final playlist in playlists) {
      playlist.clear();
    }
  }
}

class Playlist {
  String name;
  // for navidrome
  String? id;
  List<MyAudioMetadata> songList = [];
  List<MyAudioMetadata> navidromeSongList = [];
  late File file;
  late File settingFile;
  ValueNotifier<int> updateNotifier = ValueNotifier(0);
  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);
  ValueNotifier<int> navidromeSortTypeNotifier = ValueNotifier(0);

  final displayNavidromeNotifier = ValueNotifier(false);

  late bool isFavorite;
  late bool isNotFavorite;

  Playlist({required this.name}) {
    file = File("${playlistConfigDir.path}/$name.json");
    settingFile = File("${playlistConfigDir.path}/${name}_setting.json");
    if (!file.existsSync()) {
      file.createSync();
    }
    if (!settingFile.existsSync()) {
      saveSetting();
    } else {
      loadSetting();
    }

    isFavorite = name == 'Favorite';
    isNotFavorite = !isFavorite;
  }

  MyAudioMetadata? getDisplaySong() {
    bool displayNavidrome = displayNavidromeNotifier.value;
    return getFirstSong(displayNavidrome ? navidromeSongList : songList);
  }

  int getTotalCount() {
    return songList.length + navidromeSongList.length;
  }

  Future<void> load() async {
    final contents = await file.readAsString();
    if (contents != "") {
      List<dynamic> decoded = jsonDecode(contents);
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
    }
    if (navidromeClient.valid) {
      List<String> songIds = [];
      if (isFavorite) {
        songIds = await navidromeClient.getFavoriteSongIds();
      } else if (id != null) {
        songIds = await navidromeClient.getPlaylistSongIds(id!);
      }
      for (final songId in songIds) {
        final song = library.id2Song[songId];
        if (song == null) {
          continue;
        }
        navidromeSongList.add(song);
        if (isFavorite) {
          song.isFavoriteNotifier.value = true;
        }
      }
    }
    displayNavidromeNotifier.value =
        songList.isEmpty & navidromeSongList.isNotEmpty;
  }

  Future<void> add(List<MyAudioMetadata> songList) async {
    for (MyAudioMetadata song in songList) {
      if (song.isNavidrome) {
        if (navidromeSongList.contains(song)) {
          continue;
        }
        navidromeSongList.insert(0, song);
      } else {
        if (this.songList.contains(song)) {
          continue;
        }
        this.songList.insert(0, song);
      }
      if (isFavorite) {
        song.isFavoriteNotifier.value = true;
      }
    }
    await update();
  }

  Future<void> remove(List<MyAudioMetadata> songList) async {
    for (MyAudioMetadata song in songList) {
      if (song.isNavidrome) {
        navidromeSongList.remove(song);
      } else {
        this.songList.remove(song);
      }
      if (isFavorite) {
        song.isFavoriteNotifier.value = false;
      }
    }
    await update();
  }

  Future<void> update() async {
    await file.writeAsString(jsonEncode(songList.map((e) => e.id).toList()));
    if (isFavorite) {
      await navidromeClient.unstarAllSongs();
      await navidromeClient.starSongs(
        navidromeSongList.map((e) => e.id).toList().reversed.toList(),
      );
    } else if (id != null || navidromeSongList.isNotEmpty) {
      if (id != null) {
        await navidromeClient.deletePlaylist(id!);
      }
      id = await navidromeClient.createPlaylistAndGetId(name);
      if (id != null) {
        await navidromeClient.addSongsToPlaylist(
          id!,
          navidromeSongList.map((e) => e.id).toList(),
        );
      }
    }

    if (displayNavidromeNotifier.value &&
        navidromeSongList.isEmpty &&
        songList.isNotEmpty) {
      displayNavidromeNotifier.value = false;
    } else if (!displayNavidromeNotifier.value &&
        songList.isEmpty &&
        navidromeSongList.isNotEmpty) {
      displayNavidromeNotifier.value = true;
    }

    layersManager.updateBackground();
    updateNotifier.value++;
  }

  void loadSetting() {
    final content = settingFile.readAsStringSync();
    final Map<String, dynamic> json =
        jsonDecode(content) as Map<String, dynamic>;

    sortTypeNotifier.value = json['sortType'] as int? ?? 0;
    navidromeSortTypeNotifier.value = json['navidromeSortType'] as int? ?? 0;
  }

  void saveSetting() {
    settingFile.writeAsStringSync(
      jsonEncode({
        'sortType': sortTypeNotifier.value,
        'navidromeSortType': navidromeSortTypeNotifier.value,
      }),
    );
  }

  void clear() {
    id = null;
    songList = [];
    navidromeSongList = [];
  }
}

void toggleFavoriteState(MyAudioMetadata song) {
  final favorite = playlistsManager.playlists.first;
  final isFavorite = song.isFavoriteNotifier;
  if (isFavorite.value) {
    favorite.remove([song]);
  } else {
    favorite.add([song]);
  }
}
