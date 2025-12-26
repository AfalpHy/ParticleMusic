import 'dart:async';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/my_location.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/mobile/song_list_tile.dart';
import 'package:particle_music/base_song_list.dart';
import 'package:searchfield/searchfield.dart';

class SongListPage extends BaseSongListWidget {
  const SongListPage({
    super.key,
    super.playlist,
    super.artist,
    super.album,
    super.folder,
  });

  @override
  State<SongListPage> createState() => _SongListPageState();
}

class _SongListPageState extends BaseSongListState<SongListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      resizeToAvoidBottomInset: false,
      appBar: searchAndMore(context),
      body: normalSongList(),
    );
  }

  PreferredSizeWidget searchAndMore(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.grey.shade50,
      scrolledUnderElevation: 0,
      actions: [searchField(), moreButton(context)],
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
                            currentSongListNotifier.value = songList;
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
                        updateSongList();
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
    return mySheet(
      Column(
        children: [
          ListTile(
            title: SizedBox(
              height: 40,
              width: appWidth * 0.9,
              child: Row(
                children: [
                  if (playlist != null)
                    Text('Playlist: ', style: TextStyle(fontSize: 15)),
                  if (artist != null)
                    Text('Artist: ', style: TextStyle(fontSize: 15)),
                  if (album != null)
                    Text('Album: ', style: TextStyle(fontSize: 15)),
                  if (folder != null)
                    Text('Folder: ', style: TextStyle(fontSize: 15)),

                  Expanded(
                    child: MyAutoSizeText(
                      title,
                      maxLines: 1,
                      textStyle: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(thickness: 0.5, height: 1, color: Colors.grey.shade300),
          ListTile(
            leading: const ImageIcon(selectImage, color: Colors.black),
            title: Text(
              'Select',
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
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const ImageIcon(sequenceImage, color: Colors.black),
            title: Text(
              'Sort songs',
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
                    'Default',
                    'Title Ascending',
                    'Title Descending',
                    'Artist Ascending',
                    'Artist Descending',
                    'Album Ascending',
                    'Album Descending',
                    'Duration Ascending',
                    'Duration Descending',
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
                  return mySheet(
                    Column(
                      children: [
                        ListTile(title: Text('Select sorting type')),
                        Divider(
                          thickness: 0.5,
                          height: 1,
                          color: Colors.grey.shade300,
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
                'Delete',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
              onTap: () async {
                if (await showConfirmDialog(context, 'Delete Action')) {
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

  Widget normalSongList() {
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
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(width: 20),
                        mainCover(120),
                        Expanded(
                          child: ListTile(
                            title: AutoSizeText(
                              title,
                              maxLines: 1,
                              minFontSize: 20,
                              maxFontSize: 20,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: ValueListenableBuilder(
                              valueListenable: currentSongListNotifier,
                              builder: (context, currentSongList, child) {
                                return Text("${currentSongList.length} songs");
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
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
                        ),
                      );
                    },
                  );
                },
              ),
              SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
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
  final textController = TextEditingController();

  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);

  final ValueNotifier<bool> isSearch = ValueNotifier(false);

  Widget searchField() {
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
                            textController.clear();
                            FocusScope.of(context).unfocus();
                            setState(() {});
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
                        setState(() {});
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
    return mySheet(
      Column(
        children: [
          ListTile(
            title: SizedBox(
              height: 40,
              width: appWidth * 0.9,
              child: Row(
                children: [
                  Expanded(
                    child: MyAutoSizeText(
                      'Select',
                      maxLines: 1,
                      textStyle: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(thickness: 0.5, height: 1, color: Colors.grey.shade300),

          ListTile(
            leading: const ImageIcon(sequenceImage, color: Colors.black),
            title: Text(
              'Sort songs',
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
                    'Default',
                    'Title Ascending',
                    'Title Descending',
                    'Artist Ascending',
                    'Artist Descending',
                    'Album Ascending',
                    'Album Descending',
                    'Duration Ascending',
                    'Duration Descending',
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
                              setState(() {});
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
                  return mySheet(
                    Column(
                      children: [
                        ListTile(title: Text('Select sorting type')),
                        Divider(
                          thickness: 0.5,
                          height: 1,
                          color: Colors.grey.shade300,
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<AudioMetadata> songList = filterSongs(
      widget.songList,
      textController.text,
    );
    sortSongs(sortTypeNotifier.value, songList);
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        scrolledUnderElevation: 0,
        actions: [searchField(), moreButton(context)],
      ),
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
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                final checkBoxitem = isSelectedList.removeAt(oldIndex);
                isSelectedList.insert(newIndex, checkBoxitem);

                final item = widget.songList.removeAt(oldIndex);
                widget.songList.insert(newIndex, item);
                songList = widget.songList;

                playlist!.update();
              },
              onReorderStart: (_) {
                tryVibrate();
              },
              onReorderEnd: (_) {
                tryVibrate();
              },
              proxyDecorator:
                  (Widget child, int index, Animation<double> animation) {
                    return Material(
                      elevation: 0.1,
                      color:
                          Colors.grey.shade100, // background color while moving
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
                  reorderable:
                      playlist != null &&
                      textController.text.isEmpty &&
                      sortTypeNotifier.value == 0,
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
                        tryVibrate();
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
                        ImageIcon(playnextCircleImage, color: iconColor),

                        Text("Play Next", style: TextStyle(color: textColor)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (valid) {
                        tryVibrate();
                        List<AudioMetadata> songs = [];
                        for (int i = isSelectedList.length - 1; i >= 0; i--) {
                          if (isSelectedList[i].value) {
                            songs.add(songList[i]);
                          }
                        }
                        showAddPlaylistSheet(context, songs);
                      }
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ImageIcon(playlistAddImage, color: iconColor),

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
                              tryVibrate();
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
                              ImageIcon(deleteImage, color: iconColor),

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
