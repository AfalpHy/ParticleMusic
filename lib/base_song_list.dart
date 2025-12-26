import 'dart:async';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/playlists.dart';

abstract class BaseSongListWidget extends StatefulWidget {
  final Playlist? playlist;
  final String? artist;
  final String? album;
  final String? folder;

  const BaseSongListWidget({
    super.key,
    this.playlist,
    this.artist,
    this.album,
    this.folder,
  });
}

abstract class BaseSongListState<T extends BaseSongListWidget>
    extends State<T> {
  late String title;
  late List<AudioMetadata> songList;
  Playlist? playlist;
  String? artist;
  String? album;
  String? folder;

  Timer? timer;

  final ValueNotifier<List<AudioMetadata>> currentSongListNotifier =
      ValueNotifier([]);

  final listIsScrollingNotifier = ValueNotifier(false);
  final scrollController = ScrollController();
  final textController = TextEditingController();

  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);

  void updateSongList() {
    final value = textController.text;
    final filteredSongs = filterSongs(songList, value);
    switch (sortTypeNotifier.value) {
      case 1: // Title Ascending
        filteredSongs.sort((a, b) {
          return compareMixed(getTitle(a), getTitle(b));
        });
        break;
      case 2: // Title Descending
        filteredSongs.sort((a, b) {
          return compareMixed(getTitle(b), getTitle(a));
        });
        break;
      case 3: // Artist Ascending
        filteredSongs.sort((a, b) {
          return compareMixed(getArtist(a), getArtist(b));
        });
        break;
      case 4: // Artist Descending
        filteredSongs.sort((a, b) {
          return compareMixed(getArtist(b), getArtist(a));
        });
        break;
      case 5: // Album Ascending
        filteredSongs.sort((a, b) {
          return compareMixed(getAlbum(a), getAlbum(b));
        });
        break;
      case 6: // Album Descending
        filteredSongs.sort((a, b) {
          return compareMixed(getAlbum(b), getAlbum(a));
        });
        break;
      case 7: // Duration Ascending
        filteredSongs.sort((a, b) {
          return a.duration!.compareTo(b.duration!);
        });
        break;
      case 8: // Duration Descending
        filteredSongs.sort((a, b) {
          return b.duration!.compareTo(a.duration!);
        });
        break;
      default:
        break;
    }
    currentSongListNotifier.value = filteredSongs;
  }

  @override
  void initState() {
    super.initState();

    playlist = widget.playlist;
    artist = widget.artist;
    album = widget.album;
    folder = widget.folder;

    if (playlist != null) {
      songList = playlist!.songs;
      title = playlist!.name;
      sortTypeNotifier = playlist!.sortTypeNotifire;
    } else if (artist != null) {
      songList = artist2SongList[artist]!;
      title = artist!;
    } else if (album != null) {
      songList = album2SongList[album]!;
      title = album!;
    } else if (folder != null) {
      songList = folder2SongList[folder]!;
      title = folder!;
    } else {
      songList = librarySongs;
      title = 'Songs';
    }
    updateSongList();

    playlist?.changeNotifier.addListener(updateSongList);
  }

  @override
  void dispose() {
    playlist?.changeNotifier.removeListener(updateSongList);
    scrollController.dispose();
    textController.dispose();
    super.dispose();
  }
}
