import 'dart:async';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:particle_music/art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/my_location.dart';
import 'package:particle_music/song_list_tile.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:searchfield/searchfield.dart';
import 'package:smooth_corner/smooth_corner.dart';

Map<String, List<AudioMetadata>> artist2SongList = {};
Map<String, List<AudioMetadata>> album2SongList = {};

class ArtistAlbumScaffold extends StatelessWidget {
  final bool isArtist;
  const ArtistAlbumScaffold({super.key, required this.isArtist});

  @override
  Widget build(BuildContext context) {
    final songListMap = isArtist ? artist2SongList : album2SongList;
    final songListMapNotifer = ValueNotifier(songListMap);
    final textController = TextEditingController();
    final ValueNotifier<bool> isSearch = ValueNotifier(false);
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(isArtist ? "Artists" : "Albums"),
        centerTitle: true,
        actions: [
          ValueListenableBuilder(
            valueListenable: isSearch,
            builder: (context, value, child) {
              if (value) {
                return Expanded(
                  child: Row(
                    children: [
                      SizedBox(width: 20),
                      Expanded(
                        child: SizedBox(
                          height: 35,
                          child: SearchField(
                            autofocus: true,
                            controller: textController,
                            suggestions: [],
                            searchInputDecoration: SearchInputDecoration(
                              hintText: 'Search songs',
                              prefixIcon: Icon(Icons.search),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  isSearch.value = false;
                                  songListMapNotifer.value = songListMap;
                                  textController.clear();
                                  FocusScope.of(context).unfocus();
                                },
                                icon: Icon(Icons.clear),
                                padding: EdgeInsets.zero,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSearchTextChanged: (value) {
                              songListMapNotifer.value = Map.fromEntries(
                                songListMap.entries.where(
                                  (e) => (e.key.toLowerCase().contains(
                                    value.toLowerCase(),
                                  )),
                                ),
                              );

                              return null;
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: 20),
                    ],
                  ),
                );
              }
              return IconButton(
                onPressed: () {
                  isSearch.value = true;
                },
                icon: Icon(Icons.search),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: songListMapNotifer,
        builder: (context, currentSongListMap, child) {
          return GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.88,
            ),
            itemCount: currentSongListMap.length,
            itemBuilder: (context, index) {
              final key = currentSongListMap.keys.elementAt(index);
              final songList = currentSongListMap[key];
              return Column(
                children: [
                  Material(
                    elevation: 1,
                    shape: SmoothRectangleBorder(
                      smoothness: 1,
                      borderRadius: BorderRadius.circular(
                        MediaQuery.widthOf(context) * 0.4 / 15,
                      ),
                    ),
                    child: InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: ArtWidget(
                        size: MediaQuery.widthOf(context) * 0.4,
                        borderRadius: MediaQuery.widthOf(context) * 0.4 / 15,
                        source: songList!.first.pictures.isNotEmpty
                            ? songList.first.pictures.first
                            : null,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SingleArtistAlbumScaffold(
                              songList: songList,
                              title: key,
                              isArtist: isArtist,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          key,
                          style: TextStyle(overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      SizedBox(width: 10),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class SingleArtistAlbumScaffold extends StatelessWidget {
  final listIsScrollingNotifier = ValueNotifier(false);
  final songListNotifer = ValueNotifier<List<AudioMetadata>>([]);
  final List<AudioMetadata> songList;
  final itemScrollController = ItemScrollController();
  final String title;
  final bool isArtist;
  SingleArtistAlbumScaffold({
    super.key,
    required this.songList,
    required this.title,
    required this.isArtist,
  }) {
    songListNotifer.value = songList;
  }

  @override
  Widget build(BuildContext context) {
    Timer? timer;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: appBar(context),
      body: Stack(
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
            child: ValueListenableBuilder(
              valueListenable: songListNotifer,
              builder: (context, currentSongList, child) {
                return ScrollablePositionedList.builder(
                  itemScrollController: itemScrollController,
                  itemCount: currentSongList.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        children: [
                          SizedBox(height: 10),
                          Row(
                            children: [
                              SizedBox(width: 20),

                              Material(
                                elevation: 5,
                                shape: SmoothRectangleBorder(
                                  smoothness: 1,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: ArtWidget(
                                  size: 120,
                                  borderRadius: 9,
                                  source: songList.first.pictures.isNotEmpty
                                      ? songList.first.pictures.first
                                      : null,
                                ),
                              ),

                              Expanded(
                                child: ListTile(
                                  title: AutoSizeText(
                                    title,
                                    maxLines: 1,
                                    minFontSize: 20,
                                    maxFontSize: 20,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text("${songList.length} songs"),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                        ],
                      );
                    }

                    if (index < currentSongList.length + 1) {
                      return SongListTile(
                        index: index - 1,
                        source: currentSongList,
                      );
                    } else {
                      return SizedBox(height: 90);
                    }
                  },
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 120,
            child: MyLocation(
              itemScrollController: itemScrollController,
              listIsScrollingNotifier: listIsScrollingNotifier,
              songListNotifer: songListNotifer,
              offset: 1,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget appBar(BuildContext context) {
    final textController = TextEditingController();
    final ValueNotifier<bool> isSearch = ValueNotifier(false);
    return AppBar(
      backgroundColor: Colors.white,
      scrolledUnderElevation: 0,
      actions: [
        SizedBox(width: 50),
        ValueListenableBuilder(
          valueListenable: isSearch,
          builder: (context, value, child) {
            if (value) {
              return Expanded(
                child: SizedBox(
                  height: 40,
                  child: SearchField(
                    autofocus: true,
                    controller: textController,
                    suggestions: [],
                    searchInputDecoration: SearchInputDecoration(
                      hintText: 'Search songs',
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: () {
                          isSearch.value = false;
                          songListNotifer.value = songList;
                          textController.clear();
                          FocusScope.of(context).unfocus();
                        },
                        icon: Icon(Icons.clear),
                        padding: EdgeInsets.zero,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSearchTextChanged: (value) {
                      songListNotifer.value = songList
                          .where(
                            (song) =>
                                (value.isEmpty) ||
                                (song.title?.toLowerCase().contains(
                                      value.toLowerCase(),
                                    ) ??
                                    false) ||
                                (song.artist?.toLowerCase().contains(
                                      value.toLowerCase(),
                                    ) ??
                                    false) ||
                                (song.album?.toLowerCase().contains(
                                      value.toLowerCase(),
                                    ) ??
                                    false),
                          )
                          .toList();
                      return null;
                    },
                  ),
                ),
              );
            }
            return IconButton(
              onPressed: () {
                isSearch.value = true;
              },
              icon: Icon(Icons.search),
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.more_vert),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useRootNavigator: true,
              builder: (context) {
                return SmoothClipRRect(
                  smoothness: 1,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                  child: Container(
                    height: 500,
                    color: Colors.white,
                    child: Column(
                      children: [
                        ListTile(
                          title: SizedBox(
                            height: 40,
                            width: MediaQuery.of(context).size.width * 0.9,
                            child: Row(
                              children: [
                                Text(
                                  (isArtist ? 'Artist: ' : 'Album: '),
                                  style: TextStyle(fontSize: 15),
                                ),
                                Expanded(
                                  child: MyAutoSizeText(
                                    title,
                                    maxLines: 1,
                                    fontsize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
