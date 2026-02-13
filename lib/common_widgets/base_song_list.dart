import 'dart:async';

import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/folder_manager.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

abstract class BaseSongListWidget extends StatefulWidget {
  final Playlist? playlist;
  final String? artist;
  final String? album;
  final Folder? folder;
  final String? ranking;
  final String? recently;

  const BaseSongListWidget({
    super.key,
    this.playlist,
    this.artist,
    this.album,
    this.folder,
    this.ranking,
    this.recently,
  });
}

abstract class BaseSongListState<T extends BaseSongListWidget>
    extends State<T> {
  late String title;
  late List<MyAudioMetadata> songList;
  Playlist? playlist;
  String? artist;
  String? album;
  Folder? folder;
  String? ranking;
  String? recently;

  bool isLibrary = false;

  Timer? timer;

  final ValueNotifier<List<MyAudioMetadata>> currentSongListNotifier =
      ValueNotifier([]);

  final listIsScrollingNotifier = ValueNotifier(false);
  final scrollController = ScrollController();
  final textController = TextEditingController();

  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);

  void updateSongList() {
    final value = textController.text;
    final filteredSongList = filterSongList(songList, value);
    sortSongList(sortTypeNotifier.value, filteredSongList);
    currentSongListNotifier.value = filteredSongList;
  }

  @override
  void initState() {
    super.initState();

    playlist = widget.playlist;
    artist = widget.artist;
    album = widget.album;
    folder = widget.folder;
    ranking = widget.ranking;
    recently = widget.recently;

    if (playlist != null) {
      songList = playlist!.songList;
      title = playlist!.name;
      sortTypeNotifier = playlist!.sortTypeNotifier;
      playlist!.updateNotifier.addListener(updateSongList);
    } else if (artist != null) {
      songList = artist2SongList[artist]!;
      title = artist!;
    } else if (album != null) {
      songList = album2SongList[album]!;
      title = album!;
    } else if (folder != null) {
      songList = folder!.songList;
      title = folder!.path;
      folder!.updateNotifier.addListener(updateSongList);
    } else if (ranking != null) {
      songList = historyManager.rankingSongList;
      title = ranking!;
      rankingChangeNotifier.addListener(updateSongList);
    } else if (recently != null) {
      songList = historyManager.recentlySongList;
      title = recently!;
      recentlyChangeNotifier.addListener(updateSongList);
    } else {
      songList = librarySongList;
      librarySongListUpdateNotifier.addListener(updateSongList);
      isLibrary = true;
    }
    updateSongList();
    sortTypeNotifier.addListener(updateSongList);
  }

  @override
  void dispose() {
    if (playlist != null) {
      playlist!.updateNotifier.removeListener(updateSongList);
    } else if (folder != null) {
      folder!.updateNotifier.removeListener(updateSongList);
    } else if (ranking != null) {
      rankingChangeNotifier.removeListener(updateSongList);
    } else if (recently != null) {
      recentlyChangeNotifier.removeListener(updateSongList);
    } else if (isLibrary) {
      librarySongListUpdateNotifier.removeListener(updateSongList);
    }
    sortTypeNotifier.removeListener(updateSongList);
    scrollController.dispose();
    textController.dispose();
    super.dispose();
  }

  Widget mainCover(double size) {
    return Material(
      color: Colors.transparent,
      elevation: 5,
      shape: SmoothRectangleBorder(
        smoothness: 1,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ValueListenableBuilder(
        valueListenable: currentSongListNotifier,
        builder: (_, _, _) {
          if (songList.isEmpty) {
            return CoverArtWidget(size: size, borderRadius: 10, song: null);
          }
          return ValueListenableBuilder(
            valueListenable: songList.first.updateNotifier,
            builder: (_, _, _) {
              return CoverArtWidget(
                size: size,
                borderRadius: 10,
                song: songList.first,
              );
            },
          );
        },
      ),
    );
  }
}
