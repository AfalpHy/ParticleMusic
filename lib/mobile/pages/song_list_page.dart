import 'dart:async';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/my_location.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/song_list_tile.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:searchfield/searchfield.dart';
import 'package:smooth_corner/smooth_corner.dart';

class SongListPage extends StatelessWidget {
  final List<AudioMetadata> songList;
  final Widget Function(BuildContext) moreSheet;

  final String? name;
  final Playlist? playlist;

  final int extraItems;
  final int offset;

  final listIsScrollingNotifier = ValueNotifier(false);
  final ValueNotifier<List<AudioMetadata>> currentSongListNotifer;
  final itemScrollController = ItemScrollController();
  final textController = TextEditingController();

  SongListPage({
    super.key,
    required this.songList,
    required this.moreSheet,
    this.name,
    this.playlist,
  }) : currentSongListNotifer = ValueNotifier<List<AudioMetadata>>(songList),
       extraItems = name == null ? 1 : 2,
       offset = name == null ? 0 : 1 {
    if (playlist != null) {
      playlist!.changeNotifier.addListener(() {
        final value = textController.text;
        currentSongListNotifer.value = filterSongs(songList, value);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: searchAndMore(context),
      body: normalSongList(),
    );
  }

  PreferredSizeWidget searchAndMore(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      scrolledUnderElevation: 0,
      actions: [
        searchField(),
        IconButton(
          icon: Icon(Icons.more_vert),
          onPressed: () {
            HapticFeedback.heavyImpact();
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

    return ValueListenableBuilder<bool>(
      valueListenable: isSearch,
      builder: (context, value, child) {
        return value
            ? Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(50, 0, 0, 0),
                  child: SizedBox(
                    height: 30,
                    child: SearchField(
                      autofocus: true,
                      controller: textController,
                      suggestions: const [],
                      searchInputDecoration: SearchInputDecoration(
                        hintText: 'Search songs',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          onPressed: () {
                            isSearch.value = false;
                            currentSongListNotifer.value = songList;
                            textController.clear();
                            FocusScope.of(context).unfocus();
                          },
                          icon: const Icon(Icons.clear),
                          padding: EdgeInsets.zero,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSearchTextChanged: (value) {
                        currentSongListNotifer.value = filterSongs(
                          songList,
                          value,
                        );
                        return null;
                      },
                    ),
                  ),
                ),
              )
            : IconButton(
                onPressed: () {
                  isSearch.value = true;
                },
                icon: const Icon(Icons.search),
              );
      },
    );
  }

  Widget normalSongList() {
    Timer? timer;
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
          child: ValueListenableBuilder(
            valueListenable: currentSongListNotifer,
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
                              child: CoverArtWidget(
                                size: 120,
                                borderRadius: 9,
                                source: songList.isNotEmpty
                                    ? getCoverArt(songList.first)
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
                                  style: TextStyle(fontWeight: FontWeight.bold),
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
            songListNotifer: currentSongListNotifer,
            offset: offset,
          ),
        ),
      ],
    );
  }
}

class SelectableSongListPage extends StatefulWidget {
  final List<AudioMetadata> songList;

  final Playlist? playlist;

  const SelectableSongListPage({
    super.key,
    required this.songList,
    this.playlist,
  });

  @override
  State<StatefulWidget> createState() => SelectableSongListPageState();
}

class SelectableSongListPageState extends State<SelectableSongListPage> {
  @override
  Widget build(BuildContext context) {
    final songList = widget.songList;
    final playlist = widget.playlist;
    final List<ValueNotifier<bool>> isSelectedList = List.generate(
      songList.length,
      (_) => ValueNotifier(false),
    );
    final ValueNotifier<bool> allSelected = ValueNotifier(false);
    final ValueNotifier<int> selectedNum = ValueNotifier(0);
    selectedNum.addListener(() {
      if (selectedNum.value == songList.length) {
        allSelected.value = true;
      } else {
        allSelected.value = false;
      }
    });
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, scrolledUnderElevation: 0),
      body: Column(
        children: [
          Row(
            children: [
              ValueListenableBuilder(
                valueListenable: allSelected,
                builder: (context, value, child) {
                  return Checkbox(
                    value: value,
                    activeColor: Color.fromARGB(255, 75, 200, 200),
                    onChanged: (value) {
                      for (var isSelected in isSelectedList) {
                        isSelected.value = value!;
                      }
                      selectedNum.value = value! ? songList.length : 0;
                    },
                    shape: const CircleBorder(),
                    side: BorderSide(color: Colors.grey),
                  );
                },
              ),
              Text('Select All', style: TextStyle(fontSize: 16)),
              Spacer(),

              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: Text('Complete', style: TextStyle(fontSize: 16)),
              ),
              SizedBox(width: 10),
            ],
          ),
          Expanded(
            child: playlist == null
                ? ListView.builder(
                    itemCount: songList.length,
                    itemBuilder: (_, index) {
                      return SelectableSongListTile(
                        index: index,
                        source: songList,
                        isSelected: isSelectedList[index],
                        selectedNum: selectedNum,
                      );
                    },
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final checkBoxitem = isSelectedList.removeAt(oldIndex);
                      isSelectedList.insert(newIndex, checkBoxitem);

                      final item = songList.removeAt(oldIndex);
                      songList.insert(newIndex, item);

                      playlist.update();
                    },
                    onReorderStart: (_) {
                      HapticFeedback.heavyImpact();
                    },
                    onReorderEnd: (_) {
                      HapticFeedback.heavyImpact();
                    },
                    proxyDecorator:
                        (Widget child, int index, Animation<double> animation) {
                          return Material(
                            elevation: 0.1,
                            color: Colors
                                .grey
                                .shade100, // background color while moving
                            child: child,
                          );
                        },
                    itemCount: songList.length,
                    itemBuilder: (_, index) {
                      return SelectableSongListTile(
                        key: ValueKey(songList[index]),
                        index: index,
                        source: songList,
                        isSelected: isSelectedList[index],
                        selectedNum: selectedNum,
                        reorderable: true,
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: ValueListenableBuilder(
        valueListenable: selectedNum,
        builder: (context, value, child) {
          final valid = value > 0;
          final iconColor = valid ? mainColor : Colors.black54;
          final textColor = valid
              ? Color.fromARGB(255, 75, 200, 200)
              : Colors.black54;
          return SizedBox(
            height: 80,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (valid) {
                        HapticFeedback.heavyImpact();
                        for (int i = isSelectedList.length - 1; i >= 0; i--) {
                          if (isSelectedList[i].value) {
                            audioHandler.insert2Next(i, songList);
                          }
                        }
                        showCenterMessage(
                          context,
                          'Added to Play Queue',
                          duration: 1000,
                        );
                        if (audioHandler.currentIndex == -1) {
                          await audioHandler.skipToNext();
                          audioHandler.play();
                        }
                      }
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ImageIcon(
                          AssetImage("assets/images/playnext_circle.png"),
                          color: iconColor,
                        ),

                        Text("Play Next", style: TextStyle(color: textColor)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (valid) {
                        HapticFeedback.heavyImpact();
                        List<AudioMetadata> songs = [];
                        for (int i = isSelectedList.length - 1; i >= 0; i--) {
                          if (isSelectedList[i].value) {
                            songs.add(songList[i]);
                          }
                        }
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) {
                            return PlaylistsSheet(songs: songs);
                          },
                        );
                      }
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ImageIcon(
                          AssetImage("assets/images/playlist_add.png"),
                          color: iconColor,
                        ),

                        Text(
                          "Add to Playlists",
                          style: TextStyle(color: textColor),
                        ),
                      ],
                    ),
                  ),
                ),
                playlist == null
                    ? SizedBox()
                    : Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            if (valid) {
                              HapticFeedback.heavyImpact();
                              if (await showConfirmDialog(
                                context,
                                'Delete Action',
                              )) {
                                List<AudioMetadata> songs = [];
                                for (
                                  int i = isSelectedList.length - 1;
                                  i >= 0;
                                  i--
                                ) {
                                  if (isSelectedList[i].value) {
                                    songs.add(songList[i]);
                                  }
                                }
                                playlist.remove(songs);
                                if (context.mounted) {
                                  showCenterMessage(
                                    context,
                                    'Successfully Deleted',
                                    duration: 1000,
                                  );
                                }
                                setState(() {});
                              }
                            }
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ImageIcon(
                                AssetImage("assets/images/delete.png"),
                                color: iconColor,
                              ),

                              Text(
                                "Delete",
                                style: TextStyle(color: textColor),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
