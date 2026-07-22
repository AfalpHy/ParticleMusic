import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/song_list_manager.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/keyboard.dart';
import 'package:sylvakru/base/utils/format_duration.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/utils/source_type.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/data/folder.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/widgets/edit_metadata.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/base/widgets/my_location.dart';
import 'package:sylvakru/base/widgets/my_sheet.dart';
import 'package:sylvakru/base/widgets/playlist_widgets.dart';
import 'package:sylvakru/base/widgets/selectable_song_list_page.dart';
import 'package:sylvakru/base/widgets/song_info.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/layer/albums_layer.dart';
import 'package:sylvakru/layer/artists_layer.dart';
import 'package:sylvakru/layer/folders_layer.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/playlists_layer.dart';
import 'package:sylvakru/portrait_view/custom_appbar_leading.dart';
import 'package:sylvakru/portrait_view/my_search_field.dart';
import 'package:sylvakru/portrait_view/song_list_tile.dart';
import 'package:text_scroll/text_scroll.dart';

part '../../landscape_view/panels/song_list_panel.dart';
part '../../portrait_view/pages/song_list_page.dart';

class SongList extends StatefulWidget {
  final Playlist? playlist;
  final Artist? artist;
  final Album? album;
  final Folder? folder;
  final bool isRanking;
  final bool isRecently;

  final bool isRoot;

  final SourceType sourceType;

  const SongList({
    super.key,
    this.playlist,
    this.artist,
    this.album,
    this.folder,
    this.isRanking = false,
    this.isRecently = false,
    this.isRoot = true,
    this.sourceType = .local,
  });

  @override
  State<StatefulWidget> createState() => _SongListState();
}

class _SongListState extends State<SongList> {
  String title = '';
  late SongListManager songListManager;
  late List<MyAudioMetadata> songList;
  Playlist? playlist;
  Artist? artist;
  Album? album;
  Folder? folder;

  bool isLibrary = false;
  bool isRanking = false;
  bool isRecently = false;

  bool reorderable = false;

  late SourceType sourceType;

  Timer? timer;

  bool waitForSecondClick = false;
  Timer? doubleClicktimer;

  final currentSongListNotifier = ValueNotifier<List<MyAudioMetadata>>([]);

  final listIsScrollingNotifier = ValueNotifier(false);
  final scrollController = ScrollController();
  final textController = TextEditingController();

  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);

  List<ValueNotifier<bool>> isSelectedList = [];
  bool isFixed = false;
  int continuousSelectBeginIndex = 0;

  final showPlayButtonNotifierMap = <MyAudioMetadata, ValueNotifier<bool>>{};

  final padding = const EdgeInsets.symmetric(horizontal: 30);

  final isSearchNotifier = ValueNotifier(false);

  ValueNotifier<bool>? rootVisibleNotifier;
  Function()? backToRoot;

  bool hideOthers = false;

  String rootLabel = '';

  void updateHideOthers() {
    setState(() {
      hideOthers = rootVisibleNotifier!.value;
    });
  }

  String getTitleText(AppLocalizations l10n) {
    return isLibrary
        ? l10n.songs
        : playlist?.isFavorite == true
        ? l10n.favorites
        : isRanking
        ? l10n.ranking
        : isRecently
        ? l10n.recently
        : title;
  }

  void updateSongList() {
    final value = textController.text;
    final filteredSongList = filterSongList(songList, value);
    sortSongList(sortTypeNotifier.value, filteredSongList);
    currentSongListNotifier.value = filteredSongList;

    isSelectedList = List.generate(
      filteredSongList.length,
      (_) => ValueNotifier(false),
    );
    isFixed =
        isMobile ||
        !reorderable ||
        textController.text.isNotEmpty ||
        sortTypeNotifier.value > 0;

    continuousSelectBeginIndex = 0;

    showPlayButtonNotifierMap.clear();
    for (var e in filteredSongList) {
      showPlayButtonNotifierMap[e] = ValueNotifier(false);
    }
  }

  @override
  void initState() {
    super.initState();

    playlist = widget.playlist;
    artist = widget.artist;
    album = widget.album;
    folder = widget.folder;
    isRanking = widget.isRanking;
    isRecently = widget.isRecently;

    sourceType = widget.sourceType;

    if (playlist != null) {
      title = playlist!.name;
      songListManager = playlist!.songListManager;
      reorderable = true;
      if (!widget.isRoot) {
        rootVisibleNotifier = playlistsVisibleNotifier;
        backToRoot = () {
          layersManager.popDetail('playlists');
        };
        rootLabel = 'playlists';
      }
    } else if (artist != null) {
      title = artist!.name;
      songListManager = artist!.songListManager;
      rootVisibleNotifier = artistsVisibleNotifier;
      backToRoot = () {
        layersManager.popDetail('artists');
      };
      rootLabel = 'artists';
    } else if (album != null) {
      title = album!.name;
      songListManager = album!.songListManager;
      rootVisibleNotifier = albumsVisibleNotifier;
      backToRoot = () {
        layersManager.popDetail('albums');
      };
      rootLabel = 'albums';
    } else if (folder != null) {
      title = folder!.id;
      reorderable = true;
      rootVisibleNotifier = foldersVisibleNotifier;
      backToRoot = () {
        layersManager.popDetail('folders');
      };
      rootLabel = 'folders';
    } else if (isRanking) {
      songListManager = history.rankingSongListManager;
    } else if (isRecently) {
      songListManager = history.recentlySongListManager;
    } else {
      isLibrary = true;
      songListManager = library.songListManager;
      reorderable = sourceType == .local || sourceType == .webdav;
    }
    if (folder == null) {
      songList = songListManager.getSongList2(sourceType);
      sortTypeNotifier = songListManager.getSortTypeNotifier2(sourceType);
      songListManager
          .getChangeNotifier2(sourceType)
          .addListener(updateSongList);
    } else {
      songList = folder!.songList;
      sortTypeNotifier = folder!.sortTypeNotifier;
      folder!.changeNotifier.addListener(updateSongList);
    }
    rootVisibleNotifier?.addListener(updateHideOthers);

    updateSongList();
    sortTypeNotifier.addListener(updateSongList);
    textController.addListener(updateSongList);
  }

  @override
  void dispose() {
    if (folder == null) {
      songListManager
          .getChangeNotifier2(sourceType)
          .removeListener(updateSongList);
    } else {
      folder!.changeNotifier.removeListener(updateSongList);
    }

    rootVisibleNotifier?.removeListener(updateHideOthers);

    sortTypeNotifier.removeListener(updateSongList);
    textController.removeListener(updateSongList);
    scrollController.dispose();
    timer?.cancel();
    doubleClicktimer?.cancel();
    super.dispose();
  }

  Widget mainCover(double size) {
    return ValueListenableBuilder(
      valueListenable: currentSongListNotifier,
      builder: (_, _, _) {
        final song = getFirstSong(songList);
        return ListenableBuilder(
          listenable: Listenable.merge([song?.updateNotifier]),
          builder: (_, _) {
            return ValueListenableBuilder(
              valueListenable: mainPageThemeNotifier,
              builder: (_, _, _) {
                final coverArt = CoverArtWidget(
                  size: size,
                  borderRadius: size / 10,
                  song: song,
                  elevation: 5,
                  color: colorManager.getSpecificMainPageCoverArtBaseColorForm(
                    song,
                  ), // keep stable color
                );
                return widget.isRoot
                    ? coverArt
                    : Hero(
                        tag: (song == null ? sourceType.name : song.id) + title,
                        transitionOnUserGestures: true,
                        flightShuttleBuilder:
                            (
                              flightContext,
                              animation,
                              flightDirection,
                              fromHeroContext,
                              toHeroContext,
                            ) => FittedBox(child: toHeroContext.widget),
                        child: coverArt,
                      );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isTooNarrow(context)) {
      return pageView(context);
    }
    return panelView(context);
  }
}
