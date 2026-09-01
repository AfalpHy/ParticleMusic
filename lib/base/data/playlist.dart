import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/interaction.dart';
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

  Playlist playQueueForStream = Playlist(name: '_sylvakru_play_queue_');

  PlaylistManager() {
    addPlaylist(Playlist(name: 'Favorite'));
  }

  Future<void> prepare() async {
    playlists.clear();
    playlistMap.clear();

    addPlaylist(Playlist(name: 'Favorite'));
    updateNotifier.value++;

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
      final tmpPlaylist = await streamClient?.getPlaylists();
      for (final playlist in tmpPlaylist ?? <Playlist>[]) {
        if (playlist.name == playQueueForStream.name) {
          playQueueForStream.id = playlist.id;
          continue;
        }
        if (playlistMap[playlist.name] == null) {
          addPlaylist(playlist);
        }
        playlistMap[playlist.name]!.id = playlist.id;
      }
      playlists.removeWhere((e) => e.isNotFavorite && e.id == null);
      playlistMap.removeWhere((k, v) => v.isNotFavorite && v.id == null);
    }

    update();
  }

  Future<void> load() async {
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
        showCenterMessage('Playlist exists');
        return;
      }
    }

    final playlist = Playlist(name: name);
    if (isStreamSource) {
      playlist.id = await streamClient?.createPlaylist(name);

      // failed
      if (playlist.id == null) {
        showCenterMessage('Create playlist failed');
        return;
      }
    }
    addPlaylist(playlist);

    update();
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    playlist.songListFile?.deleteSync();

    if (playlist.id != null && streamClient != null) {
      if (!await streamClient!.deletePlaylist(playlist.id!)) {
        showCenterMessage('Delete playlist failed');
        return;
      }
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

  Playlist({required this.name, this.id}) {
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
      List<MyAudioMetadata>? tmpSongs;
      if (isFavorite) {
        tmpSongs = (await streamClient?.getStarredSongs());
      } else {
        tmpSongs = (await streamClient?.getPlaylistSongs(id!));
      }
      for (final song in tmpSongs ?? []) {
        songList.add(song);
        if (isFavorite) {
          song.isFavoriteNotifier.value = true;
        }
      }
    }

    canModify = true;
    changeNotifier.value++;
    layersManager.updateBackground();
  }

  Future<void> reload() async {
    songList.clear();
    await load();
  }

  Future<void> add(List<MyAudioMetadata> songList) async {
    if (!canModify) {
      showCenterMessage('Playlist is updating');
      return;
    }
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
    if (!canModify) {
      showCenterMessage('Playlist is updating');
      return;
    }
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
      late bool success;
      if (isFavorite) {
        success = await streamClient?.updateStarredSongs(songIds) ?? false;
      } else {
        success =
            await streamClient?.updatePlaylistSongs(id!, songIds) ?? false;
      }
      showCenterMessage('Update playlist ${success ? 'success' : 'failed'}');
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
