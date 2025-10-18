import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/pages/artist_album_page.dart';
import 'package:particle_music/playlists.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

List<AudioMetadata> librarySongs = [];
Map<String, AudioMetadata> basename2LibrarySong = {};

class LibraryLoader {
  late Directory _docs;
  late Directory _appSupportDir;

  Future<void> initial() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.audio.request();
      final dir = await getExternalStorageDirectory();
      _docs = Directory("${dir!.parent.parent.parent.parent.path}/Music");
    } else if (Platform.isIOS) {
      _docs = await getApplicationDocumentsDirectory();
      final keepfile = File('${_docs.path}/Particle Music.keep');
      if (!(await keepfile.exists())) {
        await keepfile.writeAsString("App initialized");
      }
    } else {
      final dir = await getDownloadsDirectory();
      _docs = Directory("${dir!.parent.path}/Music");
    }

    _appSupportDir = await getApplicationSupportDirectory();
    playlistsManager = PlaylistsManager(
      File("${_appSupportDir.path}/allPlaylists.txt"),
    );
  }

  Future<void> load() async {
    for (var file in _docs.listSync()) {
      if (!(file.path.endsWith('.mp3') ||
          file.path.endsWith('.flac') ||
          file.path.endsWith('.ogg') ||
          file.path.endsWith('.wav'))) {
        continue;
      }

      try {
        final song = readMetadata(File(file.path), getImage: true);
        librarySongs.add(song);
        basename2LibrarySong[p.basename(file.path)] = song;
        songIsFavorite[song] = ValueNotifier(false);

        _add2ArtistAndAlbum(song);
      } catch (error) {
        continue; // skip unreadable files
      }
    }

    await _loadPlaylists();
  }

  void _add2ArtistAndAlbum(AudioMetadata song) {
    for (String artist in getArtist(song).split(RegExp(r'[/&,]'))) {
      if (artist2SongList[artist] == null) {
        artist2SongList[artist] = [];
      }
      artist2SongList[artist]!.add(song);
    }

    final songAlbum = getAlbum(song);
    if (album2SongList[songAlbum] == null) {
      album2SongList[songAlbum] = [];
    }
    album2SongList[songAlbum]!.add(song);
  }

  Future<void> _loadPlaylists() async {
    List<dynamic> allPlaylists = await playlistsManager.getAllPlaylists();

    for (String name in allPlaylists) {
      final playlist = Playlist(
        name: name,
        file: File("${_appSupportDir.path}/$name.json"),
      );
      playlistsManager.addPlaylist(playlist);

      final contents = await playlist.file.readAsString();
      if (contents != "") {
        List<dynamic> decoded = jsonDecode(contents);
        for (String basename in decoded) {
          AudioMetadata? song = basename2LibrarySong[basename];
          if (song != null) {
            playlist.songs.add(song);
            if (name == 'Favorite') {
              songIsFavorite[song]!.value = true;
            }
          }
        }
      }
    }
  }

  Future<void> reload() async {
    audioHandler.clear();

    librarySongs = [];
    basename2LibrarySong = {};
    songIsFavorite = {};

    artist2SongList = {};
    album2SongList = {};

    playlistsManager.clear();

    await load();
  }
}

LibraryLoader libraryLoader = LibraryLoader();
