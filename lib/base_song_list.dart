import 'dart:async';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:smooth_corner/smooth_corner.dart';

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

  bool isLibrary = false;

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
    sortSongs(sortTypeNotifier.value, filteredSongs);
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
      playlist!.changeNotifier.addListener(updateSongList);
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
      isLibrary = true;
    }
    updateSongList();
    sortTypeNotifier.addListener(updateSongList);
  }

  @override
  void dispose() {
    if (playlist != null) {
      playlist!.changeNotifier.removeListener(updateSongList);
    }
    sortTypeNotifier.removeListener(updateSongList);
    scrollController.dispose();
    textController.dispose();
    super.dispose();
  }

  Widget mainCover(double size) {
    return Material(
      elevation: 5,
      shape: SmoothRectangleBorder(
        smoothness: 1,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ValueListenableBuilder(
        valueListenable: currentSongListNotifier,
        builder: (_, _, _) {
          if (songList.isEmpty) {
            return CoverArtWidget(size: size, borderRadius: 10, source: null);
          }
          return ValueListenableBuilder(
            valueListenable: songIsUpdated[songList.first]!,
            builder: (_, _, _) {
              return CoverArtWidget(
                size: size,
                borderRadius: 10,
                source: getCoverArt(songList.first),
              );
            },
          );
        },
      ),
    );
  }
}
