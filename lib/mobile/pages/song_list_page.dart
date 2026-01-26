import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/my_auto_size_text.dart';
import 'package:particle_music/mobile/pages/selectable_song_list_page.dart';
import 'package:particle_music/mobile/widgets/my_search_field.dart';
import 'package:particle_music/mobile/widgets/my_sheet.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/common_widgets/my_location.dart';
import 'package:particle_music/mobile/song_list_tile.dart';
import 'package:particle_music/base_song_list.dart';
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
  });

  @override
  State<SongListPage> createState() => _SongListPageState();
}

class _SongListPageState extends BaseSongListState<SongListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: commonColor,
      resizeToAvoidBottomInset: false,
      appBar: searchAndMore(context),
      body: contentWithStack(),
    );
  }

  PreferredSizeWidget searchAndMore(BuildContext context) {
    return AppBar(
      backgroundColor: commonColor,
      scrolledUnderElevation: 0,
      actions: [
        MySearchField(
          textController: textController,
          onSearchTextChanged: updateSongList,
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
              width: appWidth * 0.9,
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
                          : playlist?.name == 'Favorite'
                          ? l10n.favorite
                          : title,
                      maxLines: 1,
                      textStyle: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(thickness: 0.5, height: 1, color: dividerColor),
          ListTile(
            leading: const ImageIcon(selectImage, color: Colors.black),
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
                    artist: artist,
                    album: album,
                    folder: folder,
                    ranking: ranking,
                    recently: recently,
                    isLibrary: isLibrary,
                  ),
                ),
              );
            },
          ),
          if (ranking == null && recently == null)
            ListTile(
              leading: const ImageIcon(sequenceImage, color: Colors.black),
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
                    List<Widget> orderWidget = [];
                    for (int i = 0; i < orderText.length; i++) {
                      String text = orderText[i];
                      orderWidget.add(
                        ValueListenableBuilder(
                          valueListenable: sortTypeNotifier,
                          builder: (context, value, child) {
                            return ListTile(
                              title: Text(text),
                              onTap: () {
                                sortTypeNotifier.value = i;
                                playlist?.saveSetting();
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
                          Divider(
                            thickness: 0.5,
                            height: 1,
                            color: dividerColor,
                          ),

                          ...orderWidget,
                        ],
                      ),
                      height: 400,
                    );
                  },
                );
              },
            ),
          if (playlist != null && playlist!.name != 'Favorite')
            ListTile(
              leading: const ImageIcon(deleteImage, color: Colors.black),
              title: Text(
                l10n.delete,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
              onTap: () async {
                if (await showConfirmDialog(context, l10n.delete)) {
                  playlistsManager.deletePlaylist(playlist!);
                  if (context.mounted) {
                    Navigator.pop(context, true);
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

    return Column(
      children: [
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 20),
            mainCover(120),
            Expanded(
              child: ListTile(
                title: AutoSizeText(
                  isLibrary
                      ? l10n.songs
                      : playlist == playlistsManager.playlists[0]
                      ? l10n.favorite
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
                    return Text(l10n.songsCount(currentSongList.length));
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
                    source: currentSongList,
                    playlist: widget.playlist,
                    isRanking: ranking != null,
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
