import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/panels/panel_manager.dart';
import 'package:particle_music/history.dart';
import 'package:particle_music/metadata.dart';
import 'package:particle_music/mobile/pages/main_page.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/setting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

List<AudioMetadata> librarySongs = [];
Map<String, AudioMetadata> filePath2LibrarySong = {};

List<String> folderPaths = [];
Map<String, List<AudioMetadata>> folder2SongList = {};
final ValueNotifier<int> foldersChangeNotifier = ValueNotifier(0);
final ValueNotifier<int> loadedCountNotifier = ValueNotifier(0);
final ValueNotifier<String> currentLoadingFolderNotifier = ValueNotifier('');

Map<String, List<AudioMetadata>> artist2SongList = {};
Map<String, List<AudioMetadata>> album2SongList = {};
List<MapEntry<String, List<AudioMetadata>>> artistMapEntryList = [];
List<MapEntry<String, List<AudioMetadata>>> albumMapEntryList = [];

late Directory appDocs;

final ValueNotifier<bool> loadingLibraryNotifier = ValueNotifier(true);

class LibraryLoader {
  late File _folderPathsFile;

  Future<void> initial() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.audio.request();
    } else if (Platform.isIOS) {
      appDocs = await getApplicationDocumentsDirectory();
      final keepfile = File('${appDocs.path}/Particle Music.keep');
      if (!(await keepfile.exists())) {
        await keepfile.writeAsString("App initialized");
      }
    }

    Directory appSupportDir = await getApplicationSupportDirectory();
    playlistsManager = PlaylistsManager(
      File("${appSupportDir.path}/playlists.txt"),
    );

    List<dynamic> allPlaylists = await playlistsManager.getAllPlaylists();

    for (String name in allPlaylists) {
      final playlist = Playlist(
        name: name,
        file: File("${appSupportDir.path}/$name.json"),
        settingFile: File("${appSupportDir.path}/${name}_setting.json"),
      );
      playlistsManager.addPlaylist(playlist);
    }

    _folderPathsFile = File("${appSupportDir.path}/folder_paths.txt");
    if (!_folderPathsFile.existsSync()) {
      _folderPathsFile.createSync();
    }
    final folderPathsContent = await _folderPathsFile.readAsString();
    if (folderPathsContent.isNotEmpty) {
      List<dynamic> result = jsonDecode(folderPathsContent);
      folderPaths = result.cast<String>();
    }

    setting = Setting(File("${appSupportDir.path}/setting.txt"));
    await setting.loadSetting();

    audioHandler.initStateFiles(appSupportDir.path);
  }

  Future<void> load() async {
    loadingLibraryNotifier.value = true;
    loadedCountNotifier.value = 0;
    for (String folderPath in folderPaths) {
      late Directory folder;
      if (Platform.isIOS) {
        folder = Directory(
          "${appDocs.parent.path}/${folderPath.replaceFirst('Particle Music', 'Documents')}",
        );
      } else {
        folder = Directory(folderPath);
      }
      if (!folder.existsSync()) {
        folder2SongList[folderPath] = [];
        continue;
      }
      currentLoadingFolderNotifier.value = folderPath;

      List<AudioMetadata> songList = [];

      await for (final file in folder.list()) {
        if (!(file.path.endsWith('.mp3') ||
            file.path.endsWith('.flac') ||
            file.path.endsWith('.ogg') ||
            file.path.endsWith('.wav'))) {
          continue;
        }

        try {
          final song = await Isolate.run(
            () => readMetadata(File(file.path), getImage: true),
          );
          librarySongs.add(song);
          if (Platform.isIOS) {
            filePath2LibrarySong[file.path.substring(appDocs.path.length)] =
                song;
          } else {
            filePath2LibrarySong[file.path] = song;
          }
          songList.add(song);
          songIsFavorite[song] = ValueNotifier(false);
          songIsUpdated[song] = ValueNotifier(0);

          _add2ArtistAndAlbum(song);
          loadedCountNotifier.value++;
        } catch (error) {
          continue; // skip unreadable files
        }
      }
      folder2SongList[folderPath] = songList;
    }

    artistMapEntryList = artist2SongList.entries.toList();
    setting.sortArtists();

    albumMapEntryList = album2SongList.entries.toList();
    setting.sortAlbums();

    await _loadPlaylists();

    if (isMobile) {
      swipeObserver.resetDeep();
    }

    await audioHandler.loadPlayQueueState();
    await audioHandler.loadPlayState();

    await historyManager.load();

    if (!isMobile) {
      panelManager.pushPanel('songs');
    }
    loadingLibraryNotifier.value = false;
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
    for (final playlist in playlistsManager.playlists) {
      final contents = await playlist.file.readAsString();
      if (contents != "") {
        List<dynamic> decoded = jsonDecode(contents);
        for (String filePath in decoded) {
          AudioMetadata? song = filePath2LibrarySong[filePath];
          if (song != null) {
            playlist.songs.add(song);
            if (playlist.name == 'Favorite') {
              songIsFavorite[song]!.value = true;
            }
          }
        }
      }
    }
    playlistsManager.changeNotifier.value++;
  }

  Future<void> reload() async {
    await audioHandler.clearForReload();

    librarySongs = [];
    filePath2LibrarySong = {};
    folder2SongList = {};
    songIsFavorite = {};
    songIsUpdated = {};

    artist2SongList = {};
    album2SongList = {};
    artistMapEntryList = [];
    albumMapEntryList = [];

    for (final playlist in playlistsManager.playlists) {
      playlist.songs = [];
    }

    if (!isMobile) {
      panelManager.reload();
    }
    await load();
  }

  void addFolder(String path) {
    folderPaths.add(path);
    _folderPathsFile.writeAsStringSync(jsonEncode(folderPaths));
    foldersChangeNotifier.value++;
  }

  void removeFolder(String path) {
    folderPaths.remove(path);
    _folderPathsFile.writeAsStringSync(jsonEncode(folderPaths));
    foldersChangeNotifier.value++;
  }
}

LibraryLoader libraryLoader = LibraryLoader();
