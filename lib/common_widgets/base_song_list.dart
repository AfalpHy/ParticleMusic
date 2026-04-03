import 'dart:async';

import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/folder.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

abstract class BaseSongListWidget extends StatefulWidget {
  final Playlist? playlist;
  final Artist? artist;
  final Album? album;
  final Folder? folder;
  final String? ranking;
  final String? recently;

  final TextEditingController? textController;

  final bool isNavidrome;

  const BaseSongListWidget({
    super.key,
    this.playlist,
    this.artist,
    this.album,
    this.folder,
    this.ranking,
    this.recently,
    this.textController,
    this.isNavidrome = false,
  });
}

abstract class BaseSongListState<T extends BaseSongListWidget>
    extends State<T> {
  late String title;
  late List<MyAudioMetadata> songList;
  Playlist? playlist;
  Artist? artist;
  Album? album;
  Folder? folder;
  String? ranking;
  String? recently;

  bool isLibrary = false;

  bool reorderable = false;

  late bool isNavidrome;

  Timer? timer;

  final ValueNotifier<List<MyAudioMetadata>> currentSongListNotifier =
      ValueNotifier([]);

  final listIsScrollingNotifier = ValueNotifier(false);
  final scrollController = ScrollController();
  late final TextEditingController textController;

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

    textController = widget.textController ?? TextEditingController();

    isNavidrome = widget.isNavidrome;

    if (playlist != null) {
      songList = isNavidrome ? playlist!.navidromeSongList : playlist!.songList;
      title = playlist!.name;
      sortTypeNotifier = isNavidrome
          ? playlist!.navidromeSortTypeNotifier
          : playlist!.sortTypeNotifier;
      playlist!.updateNotifier.addListener(updateSongList);
      reorderable = true;
    } else if (artist != null) {
      songList = artist!.getSongList(isNavidrome);
      title = artist!.name;
    } else if (album != null) {
      songList = album!.getSongList(isNavidrome);
      title = album!.name;
    } else if (folder != null) {
      songList = folder!.songList;
      title = folder!.path;
      folder!.updateNotifier.addListener(updateSongList);
      reorderable = true;
    } else if (ranking != null) {
      songList = history.getRankingSongList(isNavidrome);
      title = ranking!;
      rankingChangeNotifier.addListener(updateSongList);
    } else if (recently != null) {
      songList = history.getRecentlySongList(isNavidrome);
      title = recently!;
      recentlyChangeNotifier.addListener(updateSongList);
    } else {
      if (isNavidrome) {
        songList = library.navidromeSongList;
      } else {
        songList = library.songList;
        library.changeNotifier.addListener(updateSongList);
        reorderable = true;
      }
      isLibrary = true;
    }
    updateSongList();
    sortTypeNotifier.addListener(updateSongList);
    textController.addListener(updateSongList);
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
      library.changeNotifier.removeListener(updateSongList);
    }
    sortTypeNotifier.removeListener(updateSongList);
    textController.removeListener(updateSongList);
    scrollController.dispose();
    timer?.cancel();
    super.dispose();
  }

  Widget mainCover(double size) {
    return ValueListenableBuilder(
      valueListenable: updateColorNotifier,
      builder: (context, value, child) {
        return Material(
          color: mainPageThemeNotifier.value != 0
              ? isMobile
                    ? pageBackgroundColor
                    : panelColor
              : Colors.grey,
          elevation: 5,
          shape: SmoothRectangleBorder(
            smoothness: 1,
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: .antiAlias,
          child: child,
        );
      },
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
