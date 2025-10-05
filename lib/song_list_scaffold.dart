import 'dart:async';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:particle_music/art_widget.dart';
import 'package:particle_music/my_location.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/song_list_tile.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:searchfield/searchfield.dart';
import 'package:smooth_corner/smooth_corner.dart';

class SongListScaffold extends StatelessWidget {
  final List<AudioMetadata> songList;
  final Widget Function(BuildContext) moreSheet;

  final String? name;
  final Playlist? playlist;

  final listIsScrollingNotifier = ValueNotifier(false);
  final ValueNotifier<List<AudioMetadata>> songListNotifer;
  final itemScrollController = ItemScrollController();
  final textController = TextEditingController();

  SongListScaffold({
    super.key,
    required this.songList,
    required this.moreSheet,
    this.name,
    this.playlist,
  }) : songListNotifer = ValueNotifier<List<AudioMetadata>>(songList) {
    if (playlist != null) {
      playlist!.changeNotifier.addListener(() {
        final value = textController.text;
        songListNotifer.value = songList
            .where(
              (song) =>
                  (value.isEmpty) ||
                  (song.title?.toLowerCase().contains(value.toLowerCase()) ??
                      false) ||
                  (song.artist?.toLowerCase().contains(value.toLowerCase()) ??
                      false) ||
                  (song.album?.toLowerCase().contains(value.toLowerCase()) ??
                      false),
            )
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Timer? timer;
    final extraItems = name == null ? 1 : 2;
    final offset = name == null ? 0 : 1;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: searchAndMore(context),
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
                  itemCount: currentSongList.length + extraItems,
                  itemBuilder: (context, index) {
                    if (name != null && index == 0) {
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
                                  source:
                                      songList.isNotEmpty &&
                                          songList.first.pictures.isNotEmpty
                                      ? songList.first.pictures.first
                                      : null,
                                ),
                              ),

                              Expanded(
                                child: ListTile(
                                  title: AutoSizeText(
                                    name!,
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

                    if (index < currentSongList.length + offset) {
                      return SongListTile(
                        index: index - offset,
                        source: currentSongList,
                        playlist: playlist,
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
              offset: offset,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget searchAndMore(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      scrolledUnderElevation: 0,
      title: name != null ? null : Text('Songs'),
      centerTitle: true,
      actions: [
        SizedBox(width: 50),
        searchField(),
        IconButton(
          icon: Icon(Icons.more_vert),
          onPressed: () {
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
        ),
      ],
    );
  }

  Widget searchField() {
    final ValueNotifier<bool> isSearch = ValueNotifier(false);
    return ValueListenableBuilder(
      valueListenable: isSearch,
      builder: (context, value, child) {
        if (value) {
          return Expanded(
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
    );
  }
}
