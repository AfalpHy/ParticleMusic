import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/setting.dart';
import 'package:particle_music/utils.dart';
import 'package:permission_handler/permission_handler.dart';

List<AudioMetadata> librarySongList = [];
Map<String, AudioMetadata> filePath2LibrarySong = {};
Map<String, String?> filePath2PicturePath = {};

List<String> folderPathList = [];
Map<String, List<AudioMetadata>> folder2SongList = {};
final ValueNotifier<int> foldersChangeNotifier = ValueNotifier(0);
final ValueNotifier<int> loadedCountNotifier = ValueNotifier(0);
final ValueNotifier<String> currentLoadingFolderNotifier = ValueNotifier('');

Map<String, List<AudioMetadata>> artist2SongList = {};
Map<String, List<AudioMetadata>> album2SongList = {};
List<MapEntry<String, List<AudioMetadata>>> artistMapEntryList = [];
List<MapEntry<String, List<AudioMetadata>>> albumMapEntryList = [];

final ValueNotifier<bool> loadingLibraryNotifier = ValueNotifier(true);

class LibraryLoader {
  Map<String, DateTime> _filePath2Modified = {};
  Set<String> _filePathValidSet = {};

  late File _librarySongMetadataListFile;
  late File _librarySongFilePathListFile;
  late File _folderPathListFile;

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

    _librarySongMetadataListFile = File(
      "${appSupportDir.path}/song_metadata_list.txt",
    );
    _librarySongFilePathListFile = File(
      "${appSupportDir.path}/song_filepath_list.txt",
    );

    _folderPathListFile = File("${appSupportDir.path}/folder_paths.txt");

    if (!_folderPathListFile.existsSync()) {
      _folderPathListFile.createSync();
    }
    final folderPathListContent = await _folderPathListFile.readAsString();
    if (folderPathListContent.isNotEmpty) {
      List<dynamic> result = jsonDecode(folderPathListContent);
      folderPathList = result.cast<String>();
    }

    playlistsManager = PlaylistsManager();
    await playlistsManager.initAllPlaylists();

    setting = Setting(File("${appSupportDir.path}/setting.txt"));
    await setting.loadSetting();

    audioHandler.initStateFiles();
  }

  Future<void> load() async {
    loadingLibraryNotifier.value = true;
    loadedCountNotifier.value = 0;
    await _prepare();
    List<AudioMetadata> libraryAdditionalSongList = [];
    for (int i = 0; i < folderPathList.length; i++) {
      final folderPath = folderPathList[i];
      Directory folder = Directory(revertDirectoryPathIfNeed(folderPath));
      if (!folder.existsSync()) {
        folder2SongList[folderPath] = [];
        continue;
      }
      currentLoadingFolderNotifier.value = folderPath;

      List<AudioMetadata> folderAdditionalSongList = [];

      await for (final file in folder.list()) {
        if (!(file.path.endsWith('.mp3') ||
            file.path.endsWith('.flac') ||
            file.path.endsWith('.ogg') ||
            file.path.endsWith('.wav') ||
            file.path.endsWith('.opus'))) {
          continue;
        }

        String path = clipFilePathIfNeed(file.path);
        AudioMetadata? song = filePath2LibrarySong[path];

        bool isAdditional = song == null;
        final modified = (await file.stat()).modified;
        if (song == null || modified != _filePath2Modified[path]) {
          song = await _tryReadMetadata(File(file.path));

          final picturePath = filePath2PicturePath[path];
          if (picturePath != null) {
            final pictureFile = File(picturePath);
            if (await pictureFile.exists()) {
              await pictureFile.delete();
            }
          }

          if (song != null) {
            _filePath2Modified[path] = modified;

            File picture = File(
              "${appSupportDir.path}/picture/picture_${DateTime.now().microsecondsSinceEpoch}",
            );
            if (song.pictures.isNotEmpty) {
              await picture.create(recursive: true);
              await picture.writeAsBytes(song.pictures.first.bytes);
            }
            filePath2PicturePath[path] = picture.path;
            if (isAdditional) {
              folderAdditionalSongList.add(song);
              libraryAdditionalSongList.add(song);
            }

            filePath2LibrarySong[path] = song;
          } else {
            _filePath2Modified.remove(path);
            filePath2PicturePath.remove(path);
            filePath2LibrarySong.remove(path);
          }
        }

        if (song != null) {
          songIsFavorite[song] = ValueNotifier(false);
          songIsUpdated[song] = ValueNotifier(0);

          _filePathValidSet.add(path);
          _add2ArtistAndAlbum(song);
          loadedCountNotifier.value++;
        }
      }
      File folderSongFilePathListFile = File(_getFolderSongFilePathListPath(i));

      final songList = await _getSongList(
        folderSongFilePathListFile,
        folderAdditionalSongList,
      );
      folder2SongList[folderPath] = songList;

      await _saveSongFilePathList(folderSongFilePathListFile, songList);
    }

    librarySongList = await _getSongList(
      _librarySongFilePathListFile,
      libraryAdditionalSongList,
    );

    await saveLibrarySongFilePathList();
    await saveLibrarySongMetadataList();

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
          if (_filePathValidSet.contains(filePath)) {
            AudioMetadata song = filePath2LibrarySong[filePath]!;
            playlist.songList.add(song);
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

    _filePath2Modified = {};
    _filePathValidSet = {};

    librarySongList = [];
    filePath2LibrarySong = {};
    filePath2PicturePath = {};
    folder2SongList = {};
    songIsFavorite = {};
    songIsUpdated = {};

    artist2SongList = {};
    album2SongList = {};
    artistMapEntryList = [];
    albumMapEntryList = [];

    for (final playlist in playlistsManager.playlists) {
      playlist.songList = [];
    }

    if (!isMobile) {
      panelManager.reload();
    }
    await load();
  }

  String _getFolderSongFilePathListPath(int index) {
    return "${appSupportDir.path}/folder_song_file_path_list_$index.txt";
  }

  void addFolder(String path) {
    folderPathList.add(path);
    _folderPathListFile.writeAsStringSync(jsonEncode(folderPathList));
    foldersChangeNotifier.value++;
  }

  Future<void> removeFolder(String path) async {
    int index = folderPathList.indexOf(path);
    final needRemoveFile = File(_getFolderSongFilePathListPath(index));
    if (await needRemoveFile.exists()) {
      await needRemoveFile.delete();
    }
    for (int i = index + 1; i < folderPathList.length; i++) {
      final file = File(_getFolderSongFilePathListPath(i));
      if (await file.exists()) {
        await file.rename(_getFolderSongFilePathListPath(i - 1));
      }
    }
    folderPathList.removeAt(index);
    _folderPathListFile.writeAsStringSync(jsonEncode(folderPathList));
    foldersChangeNotifier.value++;
  }

  Future<List<AudioMetadata>> _getSongList(
    File songFilePathListFile,
    List<AudioMetadata> additionalSongList,
  ) async {
    if (!await songFilePathListFile.exists()) {
      await songFilePathListFile.create();
    }

    final jsonString = await songFilePathListFile.readAsString();

    final List<dynamic> songFilePathList = jsonString.isNotEmpty
        ? jsonDecode(jsonString)
        : [];
    List<AudioMetadata> result = [];
    for (final path in songFilePathList) {
      final song = filePath2LibrarySong[path]!;
      if (_filePathValidSet.contains(path)) {
        result.add(song);
      } else {
        final picturePath = filePath2PicturePath[path];
        if (picturePath != null) {
          final pictureFile = File(picturePath);
          if (await pictureFile.exists()) {
            await pictureFile.delete();
          }
        }
      }
    }
    result.addAll(additionalSongList);
    return result;
  }

  Future<void> _saveSongFilePathList(
    File songFilePathListFile,
    List<AudioMetadata> songList,
  ) async {
    await songFilePathListFile.writeAsString(
      jsonEncode(songList.map((e) => clipFilePathIfNeed(e.file.path)).toList()),
    );
  }

  Future<void> saveLibrarySongFilePathList() async {
    await _saveSongFilePathList(_librarySongFilePathListFile, librarySongList);
  }

  Future<void> saveLibrarySongMetadataList() async {
    await _librarySongMetadataListFile.writeAsString(
      jsonEncode(librarySongList.map((e) => _audioMetadataToMap(e)).toList()),
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
      _filePath2Modified[path] = DateTime.fromMillisecondsSinceEpoch(
        map['modified'] as int,
      );
      filePath2PicturePath[path] = map['picturePath'] as String?;
      filePath2LibrarySong[path] = AudioMetadata(
        title: map['title'] as String?,
        artist: map['artist'] as String?,
        album: map['album'] as String?,
        duration: Duration(milliseconds: map['duration'] as int),
        lyrics: map['lyrics'] as String?,
        file: File(revertFilePathIfNeed(path)),
      );
    }
  }

  Map<String, dynamic> _audioMetadataToMap(AudioMetadata song) {
    final path = clipFilePathIfNeed(song.file.path);
    return {
      'modified': _filePath2Modified[path]!.millisecondsSinceEpoch,
      'path': path,
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'duration': song.duration?.inMilliseconds,
      'lyrics': song.lyrics,
      'picturePath': filePath2PicturePath[path],
    };
  }

  Future<AudioMetadata?> _tryReadMetadata(File file) async {
    try {
      return await Isolate.run(
        () => readMetadata(File(file.path), getImage: true),
      );
    } catch (e) {
      logger.output(e.toString());
      return null;
    }
  }
}

LibraryLoader libraryLoader = LibraryLoader();
