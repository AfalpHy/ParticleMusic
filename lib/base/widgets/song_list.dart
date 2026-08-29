import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:rive_animated_icon/rive_animated_icon.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/keyboard.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/utils/common_utils.dart';
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
import 'package:sylvakru/layer/ranking_layer.dart';
import 'package:sylvakru/layer/recently_layer.dart';
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

  final String? albumRootLabel;

  const SongList({
    super.key,
    this.playlist,
    this.artist,
    this.album,
    this.folder,
    this.isRanking = false,
    this.isRecently = false,
    this.isRoot = true,

    this.albumRootLabel,
  });

  @override
  State<StatefulWidget> createState() => _SongListState();
}

class _SongListState extends State<SongList> {
  String title = '';
  List<MyAudioMetadata> songList = [];
  List<MyAudioMetadata> tmpSongList = [];

  Playlist? playlist;
  Artist? artist;
  Album? album;
  Folder? folder;

  bool isLibrary = false;
  bool isRanking = false;
  bool isRecently = false;

  bool reorderable = false;
  bool canModify = false;

  Timer? timer;

  bool waitForSecondClick = false;
  Timer? doubleClicktimer;

  Timer? searchTimer;

  final currentSongListNotifier = ValueNotifier<List<MyAudioMetadata>>([]);

  final listIsScrollingNotifier = ValueNotifier(false);
  final scrollController = ScrollController();
  final textController = TextEditingController();

  String get searchValue => textController.text;

  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);
  ValueNotifier<int> changeNotifier = ValueNotifier(0);

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

  bool firstLoading = false;

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

  int currentRequestId = 0;
  Future<List<MyAudioMetadata>?> _fetchSongList(int offset) async {
    currentRequestId++;
    int tmp = currentRequestId;
    final result = (await navidromeClient?.search(
      searchValue,
      100,
      offset,
    ))?.map((e) => MyAudioMetadata.fromMap(e, sourceType)).toList();
    if (!mounted) {
      return null;
    }
    if (tmp == currentRequestId) {
      return result;
    }
    return null;
  }

  void updateSongList() {
    final currentSongList = List<MyAudioMetadata>.from(
      searchValue.isEmpty ? songList : tmpSongList,
    );

    isSelectedList = List.generate(
      currentSongList.length,
      (_) => ValueNotifier(false),
    );
    isFixed =
        isMobile ||
        !reorderable ||
        searchValue.isNotEmpty ||
        sortTypeNotifier.value > 0;

    continuousSelectBeginIndex = 0;

    showPlayButtonNotifierMap.clear();
    for (var e in currentSongList) {
      showPlayButtonNotifierMap[e] = ValueNotifier(false);
    }

    if (playlist != null) {
      canModify = playlist!.canModify;
    } else if (folder != null) {
      canModify = folder!.canModify;
    } else if (isLibrary) {
      canModify = library.canModify;
    }
    sortSongList(sortTypeNotifier.value, currentSongList);
    currentSongListNotifier.value = currentSongList;
  }

  void startNewSearchIfNeed() {
    searchTimer?.cancel();
    searchTimer = Timer(Duration(milliseconds: 300), () async {
      if (searchValue.isNotEmpty) {
        tmpSongList.clear();
        if (isLibrary) {
          tmpSongList = await _fetchSongList(0) ?? [];
          if (!mounted) {
            return;
          }
        } else {
          tmpSongList = filterSongList(songList, searchValue);
        }
      }
      updateSongList();
    });
  }

  bool _isLoadingMoreData = false;
  bool _reachEnd = false;
  void _onScroll() async {
    if (_isLoadingMoreData | _reachEnd) {
      return;
    }
    _isLoadingMoreData = true;

    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent) {
      if (searchValue.isEmpty) {
        final fetchedSongList = await _fetchSongList(songList.length);
        if (!mounted) {
          return;
        }
        if (fetchedSongList == null) {
          _isLoadingMoreData = false;
          return;
        }
        _reachEnd = fetchedSongList.isEmpty;
        songList.addAll(fetchedSongList);
      } else {
        final fetchedSongList = await _fetchSongList(tmpSongList.length);
        if (!mounted) {
          return;
        }
        if (fetchedSongList == null) {
          _isLoadingMoreData = false;
          return;
        }
        _reachEnd = fetchedSongList.isEmpty;
        tmpSongList.addAll(fetchedSongList);
      }
      updateSongList();
    }
    _isLoadingMoreData = false;
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

    if (playlist != null) {
      title = playlist!.name;
      songList = playlist!.songList;
      sortTypeNotifier = playlist!.sortTypeNotifier;
      changeNotifier = playlist!.changeNotifier;
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
      songList = artist!.songList;
      rootVisibleNotifier = artistsVisibleNotifier;
      backToRoot = () {
        layersManager.popDetail('artists');
      };
      rootLabel = 'artists';
    } else if (album != null) {
      title = album!.name;
      songList = album!.songList;
      rootLabel = widget.albumRootLabel!;
      if (rootLabel == 'albums') {
        rootVisibleNotifier = albumsVisibleNotifier;
      } else if (rootLabel == 'ranking') {
        rootVisibleNotifier = rankingVisibleNotifier;
      } else {
        rootVisibleNotifier = recentlyVisibleNotifier;
      }
      backToRoot = () {
        layersManager.popDetail(widget.albumRootLabel!);
      };
    } else if (folder != null) {
      title = folder!.id;
      songList = folder!.songList;
      sortTypeNotifier = folder!.sortTypeNotifier;
      changeNotifier = folder!.changeNotifier;
      reorderable = true;
      rootVisibleNotifier = foldersVisibleNotifier;
      backToRoot = () {
        layersManager.popDetail('folders');
      };
      rootLabel = 'folders';
    } else if (isRanking) {
      songList = history.rankingSongList;
      history.rankingChangeNotifier.addListener(updateSongList);
    } else if (isRecently) {
      songList = history.recentlySongList;
      history.recentlyChangeNotifier.addListener(updateSongList);
    } else {
      isLibrary = true;
      songList = library.songList;
      library.changeNotifier.addListener(updateSongList);
      reorderable = isNotStreamSource;
      if (isStreamSource) {
        scrollController.addListener(_onScroll);
      }
    }

    rootVisibleNotifier?.addListener(updateHideOthers);

    firstLoading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (isStreamSource) {
        if (songList.isEmpty) {
          currentSongListNotifier.value = [];
          if (isLibrary) {
            songList.addAll(await _fetchSongList(0) ?? []);
            layersManager.updateBackground();
          } else if (album != null) {
            songList.addAll(
              (await navidromeClient!.getAlbumSongs(
                    album!.id!,
                  ))?.map((e) => MyAudioMetadata.fromMap(e, sourceType)) ??
                  [],
            );
          } else if (artist != null) {
            songList.addAll(
              (await navidromeClient!.getArtistSongs(
                    artist!.id!,
                  ))?.map((e) => MyAudioMetadata.fromMap(e, sourceType)) ??
                  [],
            );
          }
        }
      }
      firstLoading = false;
      updateSongList();
    });

    sortTypeNotifier.addListener(updateSongList);
    changeNotifier.addListener(updateSongList);
    textController.addListener(startNewSearchIfNeed);
  }

  @override
  void dispose() {
    rootVisibleNotifier?.removeListener(updateHideOthers);

    sortTypeNotifier.removeListener(updateSongList);
    changeNotifier.removeListener(updateSongList);
    textController.removeListener(startNewSearchIfNeed);
    scrollController.dispose();
    timer?.cancel();
    doubleClicktimer?.cancel();
    searchTimer?.cancel();
    super.dispose();
  }

  Widget mainCover(double size) {
    return ValueListenableBuilder(
      valueListenable: currentSongListNotifier,
      builder: (_, _, _) {
        final song = getFirstSong(songList);
        MyPicture? picture = song?.picture;
        if (isStreamSource) {
          if (artist != null) {
            picture = artist!.picture;
          } else if (album != null) {
            picture = album!.picture;
          }
        }
        return ListenableBuilder(
          listenable: Listenable.merge([song?.updateNotifier]),
          builder: (_, _) {
            return ValueListenableBuilder(
              valueListenable: mainPageThemeNotifier,
              builder: (_, _, _) {
                final coverArt = CoverArtWidget(
                  size: size,
                  borderRadius: size / 10,
                  picture: picture,
                  elevation: 5,
                  color: colorManager.getSpecificMainPageCoverArtBaseColorForm(
                    song,
                  ), // keep stable color
                );

                return widget.isRoot
                    ? coverArt
                    : Hero(
                        tag:
                            (picture?.id ?? '') +
                            (album != null ? rootLabel : '') +
                            getTitleText(AppLocalizations.of(context)),
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
