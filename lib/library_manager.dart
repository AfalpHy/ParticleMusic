import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/folder_manager.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/setting_manager.dart';
import 'package:particle_music/utils.dart';
import 'package:permission_handler/permission_handler.dart';

class LibraryManager {
  late File _librarySongFilePathListFile;
  late File _librarySongMetadataListFile;

  Future<void> init() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.audio.request();
    } else if (Platform.isIOS) {
      final keepfile = File('${appDocs.path}/Particle Music.keep');
      if (!(await keepfile.exists())) {
        await keepfile.writeAsString("App initialized");
      }
    }

    settingManager = SettingManager();
    await settingManager.loadSetting();

    _librarySongFilePathListFile = File(
      "${appSupportDir.path}/song_file_path_list.txt",
    );
    _librarySongMetadataListFile = File(
      "${appSupportDir.path}/song_metadata_list.txt",
    );

    folderManager = FolderManager();
    await folderManager.initAllFolders();

    playlistsManager = PlaylistsManager();
    await playlistsManager.initAllPlaylists();

    audioHandler.initStateFiles();
  }

  Future<void> load() async {
    loadingLibraryNotifier.value = true;
    loadedCountNotifier.value = 0;
    await _prepare();

    await folderManager.load();

    await setSongList(
      _librarySongFilePathListFile,
      libraryAdditionalSongList,
      librarySongList,
    );

    await update();
    await saveLibrarySongMetadataList();

    for (final song in librarySongList) {
      _add2ArtistAndAlbum(song);
    }

    artistMapEntryList = artist2SongList.entries.toList();
    sortArtists();

    albumMapEntryList = album2SongList.entries.toList();
    sortAlbums();

    await playlistsManager.load();

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

  void _add2ArtistAndAlbum(MyAudioMetadata song) {
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

  Future<void> reload() async {
    await audioHandler.clearForReload();

    filePathValidSet = {};

    librarySongList = [];
    libraryAdditionalSongList = [];
    filePath2LibrarySong = {};

    folderManager.clear();

    playlistsManager.clear();

    artist2SongList = {};
    album2SongList = {};
    artistMapEntryList = [];
    albumMapEntryList = [];

    historyManager.clear();
    if (!isMobile) {
      panelManager.clear();
    }
    await load();
  }

  Future<void> saveLibrarySongMetadataList() async {
    await _librarySongMetadataListFile.writeAsString(
      jsonEncode(librarySongList.map((e) => _myAudioMetadataToMap(e)).toList()),
    );
  }

  Future<void> _prepare() async {
    if (!await _librarySongMetadataListFile.exists()) {
      await _librarySongMetadataListFile.create();
    }

    final jsonString = await _librarySongMetadataListFile.readAsString();
    if (jsonString.isEmpty) {
      return;
    }

    final List<dynamic> list = jsonDecode(jsonString);

    for (final map in list) {
      final path = map['path'] as String;
      String? picturePath = map['picturePath'] as String?;
      filePath2LibrarySong[path] = MyAudioMetadata(
        AudioMetadata(
          title: map['title'] as String?,
          artist: map['artist'] as String?,
          album: map['album'] as String?,
          duration: Duration(milliseconds: map['duration'] as int),
          lyrics: map['lyrics'] as String?,
          file: File(revertFilePathIfNeed(path)),
        ),
        DateTime.fromMillisecondsSinceEpoch(map['modified'] as int),
        picturePath: picturePath != null
            ? revertFilePathIfNeed(picturePath, appSupport: true)
            : null,
      );
    }
  }

  Map<String, dynamic> _myAudioMetadataToMap(MyAudioMetadata song) {
    return {
      'modified': song.modified.millisecondsSinceEpoch,
      'path': clipFilePathIfNeed(song.filePath),
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'duration': song.duration?.inMilliseconds,
      'lyrics': song.lyrics,
      'picturePath': song.picturePath != null
          ? clipFilePathIfNeed(song.picturePath!, appSupport: true)
          : null,
    };
  }

  Future<void> update() async {
    await _librarySongFilePathListFile.writeAsString(
      jsonEncode(
        librarySongList.map((e) => clipFilePathIfNeed(e.filePath)).toList(),
      ),
    );
    if (!isMobile) {
      panelManager.updateBackground();
    }
    librarySongListUpdateNotifier.value++;
  }
}

LibraryManager libraryManager = LibraryManager();
