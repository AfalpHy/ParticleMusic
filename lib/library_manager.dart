import 'dart:convert';
import 'dart:io';

import 'package:audio_tags_lofty/audio_tags.dart';
import 'package:particle_music/artist_album_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/folder_manager.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/navidrome_client.dart';
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

    navidromeClient = NavidromeClient(
      username: username,
      password: password,
      baseUrl: baseUrl,
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
    await _saveLibrarySongMetadataList();

    currentLoadingFolderNotifier.value = "Navidrome";
    final songs = await navidromeClient.getSongs();
    for (var song in songs) {
      DateTime? lastPlayed;
      if (song['played'] is String) {
        lastPlayed = DateTime.parse(song['played']);
      }
      MyAudioMetadata tmp = MyAudioMetadata(
        mapNavidromeToAudioMetadata(song),
        isNavidrome: true,
        id: song['id'],
        playCount: song['playCount'] as int? ?? 0,
        lastPlayed: lastPlayed,
      );
      navidromeSongList.add(tmp);
      id2navidromeSong[tmp.id!] = tmp;
    }

    displayNavidromeSongsNotifier.value =
        librarySongList.isEmpty & navidromeSongList.isNotEmpty;

    artistAlbumManager.load();

    currentLoadingFolderNotifier.value = "Navidrome's playlist";
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

  Future<void> reload() async {
    await audioHandler.clearForReload();

    filePathValidSet = {};

    librarySongList = [];
    libraryAdditionalSongList = [];
    filePath2LibrarySong = {};

    navidromeSongList = [];
    id2navidromeSong = {};

    folderManager.clear();

    playlistsManager.clear();

    artistAlbumManager.clear();

    historyManager.clear();
    if (!isMobile) {
      panelManager.clear();
    }
    await load();
  }

  Future<void> _saveLibrarySongMetadataList() async {
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
      filePath2LibrarySong[path] = MyAudioMetadata(
        filePath: revertFilePathIfNeed(path),
        modified: DateTime.fromMillisecondsSinceEpoch(map['modified'] as int),
        AudioMetadata(
          title: map['title'] as String?,
          artist: map['artist'] as String?,
          album: map['album'] as String?,
          genre: map['genre'] as String?,
          year: map['year'] as int?,
          track: map['track'] as int?,
          disc: map['disc'] as int?,
          bitrate: map['bitrate'] as int?,
          samplerate: map['samplerate'] as int?,
          duration: Duration(milliseconds: map['duration'] as int),
          lyrics: map['lyrics'] as String?,
        ),
      );
    }
  }

  Map<String, dynamic> _myAudioMetadataToMap(MyAudioMetadata song) {
    return {
      'modified': song.modified!.millisecondsSinceEpoch,
      'path': clipFilePathIfNeed(song.filePath!),
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'genre': song.genre,
      'year': song.year,
      'track': song.track,
      'disc': song.disc,
      'bitrate': song.bitrate,
      'samplerate': song.samplerate,
      'duration': song.duration?.inMilliseconds,
      'lyrics': song.lyrics,
    };
  }

  Future<void> update() async {
    await _librarySongFilePathListFile.writeAsString(
      jsonEncode(
        librarySongList.map((e) => clipFilePathIfNeed(e.filePath!)).toList(),
      ),
    );
    if (!isMobile) {
      panelManager.updateBackground();
    }
    librarySongListUpdateNotifier.value++;
  }
}
