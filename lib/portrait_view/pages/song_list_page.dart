import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/my_auto_size_text.dart';
import 'package:particle_music/common_widgets/my_divider.dart';
import 'package:particle_music/common_widgets/selectable_song_list_page.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/portrait_view/custom_appbar_leading.dart';
import 'package:particle_music/portrait_view/my_search_field.dart';
import 'package:particle_music/common_widgets/my_sheet.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/common_widgets/my_location.dart';
import 'package:particle_music/portrait_view/song_list_tile.dart';
import 'package:particle_music/common_widgets/base_song_list.dart';
import 'package:particle_music/utils.dart';

class SongListPage extends BaseSongListWidget {
  const SongListPage({
    super.key,
    super.playlist,
    super.artist,
    super.album,
    super.folder,
    super.ranking,
    super.recently,
    super.isNavidrome,
    super.switchCallBack,
  });

  @override
  State<SongListPage> createState() => _SongListPageState();
}

class _SongListPageState extends BaseSongListState<SongListPage> {
  final ValueNotifier<bool> isSearchNotifier = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          customAppBar(context),
          Expanded(child: contentWithStack()),
        ],
      ),
    );
  }

  PreferredSizeWidget customAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: customAppBarLeading(context),
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      actions: [
        ValueListenableBuilder(
          valueListenable: currentSongListNotifier,
          builder: (context, value, child) {
            return MySearchField(
              key: ValueKey(getFirstSong(songList)),
              hintText: AppLocalizations.of(context).searchSongs,
              textController: textController,
              isSearchNotifier: isSearchNotifier,
              song: getFirstSong(songList),
              useCurrentSong: false,
            );
          },
        ),
        moreButton(context),
      ],
    );
  }

  Widget moreButton(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.more_vert),
      onPressed: () {
        tryVibrate();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          builder: (context) {
            return moreSheet(context);
          },
        ).then((value) {
          if (value == true && context.mounted) {
            Navigator.pop(context);
          }
        });
      },
    );
  }

  Widget moreSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return MySheet(
      Column(
        children: [
          ListTile(
            title: SizedBox(
              height: 40,
              width: MediaQuery.widthOf(context) * 0.9,
              child: Row(
                children: [
                  if (playlist != null)
                    Text("${l10n.playlists}: ", style: TextStyle(fontSize: 15)),
                  if (artist != null)
                    Text("${l10n.artists}: ", style: TextStyle(fontSize: 15)),
                  if (album != null)
                    Text("${l10n.albums}: ", style: TextStyle(fontSize: 15)),
                  if (folder != null)
                    Text("${l10n.folders}: ", style: TextStyle(fontSize: 15)),

                  Expanded(
                    child: MyAutoSizeText(
                      isLibrary
                          ? AppLocalizations.of(context).songs
                          : playlist?.isFavorite == true
                          ? l10n.favorites
                          : title,
                      maxLines: 1,
                      textStyle: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          MyDivider(thickness: 0.5, height: 1, color: dividerColor),
          ListTile(
            leading: ImageIcon(selectImage),
            title: Text(
              l10n.select,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SelectableSongListPage(
                    songList: songList,
                    playlist: playlist,
                    folder: folder,
                    ranking: ranking,
                    recently: recently,
                    isLibrary: isLibrary,
                    reorderable: reorderable,
                  ),
                ),
              );
            },
          ),
          if (ranking == null && recently == null)
            ListTile(
              leading: ImageIcon(sequenceImage),
              title: Text(
                l10n.sortSongs,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useRootNavigator: true,
                  builder: (context) {
                    List<String> orderText = [
                      l10n.defaultText,
                      l10n.titleAscending,
                      l10n.titleDescending,
                      l10n.artistAscending,
                      l10n.artistDescending,
                      l10n.albumAscending,
                      l10n.albumDescending,
                      l10n.durationAscending,
                      l10n.durationDescending,
                    ];
                    if (isLibrary && !isNavidrome || folder != null) {
                      orderText.add(l10n.modifiedTimeAscending);
                      orderText.add(l10n.modifiedTimedescending);
                      orderText.add(l10n.randomizeTemp);
                      orderText.add(l10n.randomizePermanent);
                    }
                    List<Widget> orderWidget = [];
                    for (int i = 0; i < orderText.length; i++) {
                      String text = orderText[i];
                      orderWidget.add(
                        ValueListenableBuilder(
                          valueListenable: sortTypeNotifier,
                          builder: (context, value, child) {
                            return ListTile(
                              title: Text(text),
                              onTap: () async {
                                if (i == 12) {
                                  if (!await showConfirmDialog(
                                    context,
                                    l10n.cannotBeUndone,
                                  )) {
                                    return;
                                  }
                                  sortTypeNotifier.value = 0;
                                  if (isLibrary) {
                                    library.shuffle();
                                  } else {
                                    folder!.shuffle();
                                  }
                                } else {
                                  if (i == 11 && sortTypeNotifier.value == 11) {
                                    updateSongList();
                                  }
                                  sortTypeNotifier.value = i;

                                  playlist?.saveSetting();
                                }
                              },
                              trailing: value == i ? Icon(Icons.check) : null,
                              dense: true,
                              visualDensity: VisualDensity(
                                horizontal: 0,
                                vertical: -4,
                              ),
                            );
                          },
                        ),
                      );
                    }
                    return MySheet(
                      Column(
                        children: [
                          ListTile(title: Text(l10n.selectSortingType)),
                          MyDivider(
                            thickness: 0.5,
                            height: 1,
                            color: dividerColor,
                          ),

                          Expanded(
                            child: ListView(
                              children: [...orderWidget, SizedBox(height: 50)],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

          if (widget.switchCallBack != null)
            ListTile(
              leading: ImageIcon(navidromeImage),
              title: Text(
                l10n.switch_,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
              onTap: () async {
                Navigator.of(context).pop();
                widget.switchCallBack?.call();
              },
            ),
          if (playlist != null && playlist!.isNotFavorite)
            ListTile(
              leading: ImageIcon(deleteImage),
              title: Text(
                l10n.delete,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
              onTap: () async {
                if (await showConfirmDialog(context, l10n.delete)) {
                  layersManager.removePlaylistLayer(playlist!);
                  playlistsManager.deletePlaylist(playlist!);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            ),
        ],
      ),
    );
  }

  Widget contentWithStack() {
    return Stack(
      children: [
        NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction != ScrollDirection.idle) {
              listIsScrollingNotifier.value = true;
              if (timer != null) {
                timer!.cancel();
                timer = null;
              }
            } else {
              if (listIsScrollingNotifier.value) {
                timer ??= Timer(const Duration(milliseconds: 3000), () {
                  listIsScrollingNotifier.value = false;
                  timer = null;
                });
              }
            }
            return false;
          },
          child: content(),
        ),
        Positioned(
          right: 30,
          bottom: 180,
          child: ValueListenableBuilder(
            valueListenable: listIsScrollingNotifier,
            builder: (context, value, child) {
              if (!value) {
                return SizedBox.shrink();
              }
              return IconButton(
                onPressed: () {
                  scrollController.animateTo(
                    0,
                    duration: Duration(milliseconds: 250),
                    curve: Curves.linear,
                  );
                },
                icon: ImageIcon(topArrowImage),
              );
            },
          ),
        ),

        Positioned(
          right: 30,
          bottom: 120,
          child: MyLocation(
            scrollController: scrollController,
            listIsScrollingNotifier: listIsScrollingNotifier,
            currentSongListNotifier: currentSongListNotifier,
            offset: 300 - MediaQuery.heightOf(context) / 2,
          ),
        ),
      ],
    );
  }

  Widget header() {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;
    final shortSide = size.shortestSide;

    bool isPhone = shortSide < 600;

    return Column(
      children: [
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 20),
            mainCover(isPhone ? 120 : 160),
            Expanded(
              child: ListTile(
                title: AutoSizeText(
                  isLibrary
                      ? l10n.songs
                      : playlist == playlistsManager.playlists[0]
                      ? l10n.favorites
                      : title,
                  maxLines: 1,
                  minFontSize: 20,
                  maxFontSize: 20,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: ValueListenableBuilder(
                  valueListenable: currentSongListNotifier,
                  builder: (context, currentSongList, child) {
                    String prefix = isNavidrome ? "Navidrome" : l10n.local;
                    return Text(
                      "$prefix: ${l10n.songCount(currentSongList.length)}",
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget content() {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(child: header()),
        ValueListenableBuilder(
          valueListenable: currentSongListNotifier,
          builder: (context, currentSongList, child) {
            return SliverFixedExtentList.builder(
              itemExtent: 60,
              itemCount: currentSongList.length,
              itemBuilder: (context, index) {
                return Center(
                  child: SongListTile(
                    index: index,
                    songList: currentSongList,
                    folder: folder,
                    playlist: playlist,
                    isRanking: ranking != null,
                    isLibrary: isLibrary,
                    reorderable:
                        reorderable &&
                        textController.text.isEmpty &&
                        sortTypeNotifier.value == 0,
                  ),
                );
              },
            );
          },
        ),
        SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }
}
