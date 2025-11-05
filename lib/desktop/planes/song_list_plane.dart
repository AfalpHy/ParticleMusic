import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/desktop/keyboard.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:super_context_menu/super_context_menu.dart';

class SongListPlane extends StatefulWidget {
  final Playlist? playlist;
  final String? artist;
  final String? album;

  const SongListPlane({super.key, this.playlist, this.artist, this.album});

  @override
  State<StatefulWidget> createState() => _SongListPlane();
}

class _SongListPlane extends State<SongListPlane> {
  final ValueNotifier<List<AudioMetadata>> currentSongListNotifier =
      ValueNotifier([]);
  final textController = TextEditingController();
  Playlist? playlist;
  String? title;
  final scrollController = ScrollController();

  int continuousSelectBeginIndex = 0;

  late Function(String) onChanged;

  void updateSongList() {
    final value = textController.text;
    currentSongListNotifier.value = filterSongs(playlist!.songs, value);
  }

  @override
  void initState() {
    super.initState();
    playlist = widget.playlist;

    if (playlist != null) {
      currentSongListNotifier.value = playlist!.songs;
      title = playlist!.name;
      onChanged = (value) {
        currentSongListNotifier.value = filterSongs(playlist!.songs, value);
      };
    } else if (widget.artist != null) {
      currentSongListNotifier.value = artist2SongList[widget.artist]!;
      title = widget.artist;
      onChanged = (value) {
        currentSongListNotifier.value = filterSongs(
          artist2SongList[widget.artist]!,
          value,
        );
      };
    } else if (widget.album != null) {
      currentSongListNotifier.value = album2SongList[widget.album]!;
      title = widget.album;
      onChanged = (value) {
        currentSongListNotifier.value = filterSongs(
          album2SongList[widget.album]!,
          value,
        );
      };
    } else {
      currentSongListNotifier.value = librarySongs;
      onChanged = (value) {
        currentSongListNotifier.value = filterSongs(librarySongs, value);
      };
    }

    playlist?.changeNotifier.addListener(updateSongList);
  }

  @override
  void dispose() {
    playlist?.changeNotifier.removeListener(updateSongList);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Color.fromARGB(255, 235, 240, 245),
      child: Column(
        children: [
          TitleBar(
            hintText: 'Search Songs',
            textController: textController,
            onChanged: onChanged,
            findMyLocation: () {
              if (currentSongNotifier.value == null) {
                return;
              }
              final index = currentSongListNotifier.value.indexOf(
                currentSongNotifier.value!,
              );
              final offset =
                  (title != null ? 200 : 0) -
                  (MediaQuery.heightOf(context) - 280) / 2;

              if (index != -1) {
                scrollController.animateTo(
                  60 * index.toDouble() + offset,
                  duration: Duration(milliseconds: 300), // smooth animation
                  curve: Curves.linear,
                );
              }
            },
          ),

          Expanded(
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(child: titleHeader()),

                SliverToBoxAdapter(child: contentHeader()),

                ValueListenableBuilder(
                  valueListenable: currentSongListNotifier,
                  builder: (context, currentSongList, child) {
                    final List<ValueNotifier<bool>> isSelectedList =
                        List.generate(
                          currentSongList.length,
                          (_) => ValueNotifier(false),
                        );

                    continuousSelectBeginIndex = 0;

                    return SliverReorderableList(
                      itemExtent: 60,
                      itemBuilder: (context, index) {
                        return playlist != null && textController.text == ''
                            ? ReorderableDragStartListener(
                                // reusing the same widget to avoid unnecessary rebuild
                                key: ValueKey(currentSongList[index]),
                                index: index,
                                child: listItem(
                                  context,
                                  currentSongList,
                                  index,
                                  isSelectedList,
                                ),
                              )
                            : SizedBox(
                                key: ValueKey(index),
                                child: listItem(
                                  context,
                                  currentSongList,
                                  index,
                                  isSelectedList,
                                ),
                              );
                      },
                      itemCount: currentSongList.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final checkBoxitem = isSelectedList.removeAt(oldIndex);
                        isSelectedList.insert(newIndex, checkBoxitem);

                        final item = playlist!.songs.removeAt(oldIndex);
                        playlist!.songs.insert(newIndex, item);

                        playlist!.update();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget titleHeader() {
    if (title == null) {
      return SizedBox.shrink();
    }
    return ValueListenableBuilder(
      valueListenable: currentSongListNotifier,
      builder: (context, songList, child) {
        return Column(
          children: [
            Row(
              children: [
                SizedBox(width: 30),
                Material(
                  elevation: 5,
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: songList.isNotEmpty
                      ? ValueListenableBuilder(
                          valueListenable: songIsUpdated[songList.first]!,
                          builder: (_, _, _) {
                            return CoverArtWidget(
                              size: 200,
                              borderRadius: 10,
                              source: getCoverArt(songList.first),
                            );
                          },
                        )
                      : CoverArtWidget(
                          size: 200,
                          borderRadius: 10,
                          source: null,
                        ),
                ),

                Expanded(
                  child: ListTile(
                    title: AutoSizeText(
                      title!,
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
            SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Widget contentHeader() {
    return SizedBox(
      height: 50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Row(
          children: [
            SizedBox(width: 60, child: Center(child: Text('#'))),

            Expanded(child: Text('Title', overflow: TextOverflow.ellipsis)),

            SizedBox(width: 30),

            Expanded(child: Text('Album', overflow: TextOverflow.ellipsis)),

            SizedBox(width: 20),

            SizedBox(
              width: 80,
              child: Text('Favorited', overflow: TextOverflow.ellipsis),
            ),

            SizedBox(
              width: 80,
              child: Text('Duration', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget listItem(
    BuildContext context,
    List<AudioMetadata> currentSongList,
    int index,
    List<ValueNotifier<bool>> isSelectedList,
  ) {
    final isSelected = isSelectedList[index];

    return ContextMenuWidget(
      child: ListItemChild(
        index: index,
        isSelected: isSelected,
        currentSongList: currentSongList,
        onTap: () {
          if (ctrlIsPressed) {
            isSelected.value = !isSelected.value;
            continuousSelectBeginIndex = index;
          } else if (shiftIsPressed) {
            int left = continuousSelectBeginIndex < index
                ? continuousSelectBeginIndex
                : index;
            int right = continuousSelectBeginIndex > index
                ? continuousSelectBeginIndex
                : index;

            for (int i = 0; i < isSelectedList.length; i++) {
              if (i < left || i > right) {
                isSelectedList[i].value = false;
              } else {
                isSelectedList[i].value = true;
              }
            }
          } else {
            // clear select
            for (var tmp in isSelectedList) {
              tmp.value = false;
            }
            isSelected.value = true;
            continuousSelectBeginIndex = index;
          }
        },
      ),
      menuProvider: (_) async {
        // select current and clear others if it's not selected
        if (!isSelected.value) {
          for (var tmp in isSelectedList) {
            tmp.value = false;
          }
          isSelected.value = true;
          continuousSelectBeginIndex = index;
        }

        int selectedCnt = 0;

        for (int i = isSelectedList.length - 1; i >= 0; i--) {
          if (isSelectedList[i].value) {
            selectedCnt++;
          }
        }

        return Menu(
          children: [
            MenuAction(
              title: 'Play Now',
              image: MenuImage.icon(Icons.play_arrow_rounded),
              callback: () async {
                AudioMetadata? tmp;
                for (int i = isSelectedList.length - 1; i >= 0; i--) {
                  if (isSelectedList[i].value) {
                    tmp = currentSongList[i];
                    audioHandler.insert2Next(i, currentSongList);
                  }
                }
                if (tmp != currentSongNotifier.value) {
                  await audioHandler.skipToNext();
                }
                await audioHandler.play();
              },
            ),
            MenuAction(
              title: 'Play Next',
              image: MenuImage.icon(Icons.navigate_next_rounded),
              callback: () async {
                bool needPlay = false;
                if (playQueue.isEmpty) {
                  needPlay = true;
                }
                for (int i = isSelectedList.length - 1; i >= 0; i--) {
                  if (isSelectedList[i].value) {
                    audioHandler.insert2Next(i, currentSongList);
                  }
                }
                if (needPlay) {
                  await audioHandler.skipToNext();
                  await audioHandler.play();
                }
              },
            ),

            MenuAction(
              title: 'Add to Playlists',
              image: MenuImage.icon(Icons.playlist_add_rounded),
              callback: () {
                final List<AudioMetadata> tmpSongList = [];
                for (int i = isSelectedList.length - 1; i >= 0; i--) {
                  if (isSelectedList[i].value) {
                    tmpSongList.add(currentSongList[i]);
                  }
                }
                showAddPlaylistDialog(context, tmpSongList);
              },
            ),

            if (selectedCnt == 1 || playlist != null) MenuSeparator(),

            if (selectedCnt == 1)
              MenuAction(
                title: 'Edit Metadata',
                image: MenuImage.icon(Icons.edit_rounded),
                callback: () {
                  showSongMetadataDialog(context, currentSongList[index]);
                },
              ),
            if (playlist != null)
              MenuAction(
                title: 'Delete',
                image: MenuImage.icon(Icons.delete_rounded),
                callback: () async {
                  if (await showConfirmDialog(context, 'Delete Action')) {
                    final List<AudioMetadata> tmpSongList = [];
                    for (int i = isSelectedList.length - 1; i >= 0; i--) {
                      if (isSelectedList[i].value) {
                        tmpSongList.add(currentSongList[i]);
                      }
                    }
                    playlist!.remove(tmpSongList);
                  }
                },
              ),
          ],
        );
      },
    );
  }
}

class ListItemChild extends StatefulWidget {
  final int index;
  final ValueNotifier<bool> isSelected;
  final List<AudioMetadata> currentSongList;
  final void Function() onTap;

  const ListItemChild({
    super.key,
    required this.index,
    required this.isSelected,
    required this.currentSongList,
    required this.onTap,
  });

  @override
  State<StatefulWidget> createState() => ListItemChildState();
}

class ListItemChildState extends State<ListItemChild> {
  final showPlayButtonNotifier = ValueNotifier(false);

  Widget indexOrPlayButton() {
    return ValueListenableBuilder(
      valueListenable: showPlayButtonNotifier,
      builder: (context, value, child) {
        return value
            ? IconButton(
                onPressed: () async {
                  audioHandler.currentIndex = widget.index;
                  playQueue = List.from(widget.currentSongList);
                  if (playModeNotifier.value == 1 ||
                      (playModeNotifier.value == 2 &&
                          audioHandler.tmpPlayMode == 1)) {
                    audioHandler.shuffle();
                  }
                  await audioHandler.load();
                  await audioHandler.play();
                },
                icon: Icon(Icons.play_arrow_rounded),
              )
            : Text(
                (widget.index + 1).toString(),
                overflow: TextOverflow.ellipsis,
              );
      },
    );
  }

  Widget songListTile(AudioMetadata song) {
    return ListTile(
      contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 0),
      visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
      leading: CoverArtWidget(
        size: 40,
        borderRadius: 4,
        source: getCoverArt(song),
      ),
      title: ValueListenableBuilder(
        valueListenable: currentSongNotifier,
        builder: (_, currentSong, _) {
          return Text(
            getTitle(song),
            overflow: TextOverflow.ellipsis,
            style: song == currentSong
                ? TextStyle(
                    color: Color.fromARGB(255, 75, 200, 200),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  )
                : TextStyle(fontSize: 15),
          );
        },
      ),
      subtitle: Text(
        getArtist(song),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.index;
    final song = widget.currentSongList[index];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: SmoothClipRRect(
        smoothness: 1,
        borderRadius: BorderRadius.circular(15),
        child: ValueListenableBuilder(
          valueListenable: widget.isSelected,
          builder: (context, value, child) {
            return Material(
              color: value ? Colors.white : Color.fromARGB(255, 235, 240, 245),
              child: MouseRegion(
                onEnter: (event) {
                  showPlayButtonNotifier.value = true;
                },
                onExit: (event) {
                  showPlayButtonNotifier.value = false;
                },
                child: InkWell(
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  mouseCursor: SystemMouseCursors.basic,

                  onTap: widget.onTap,
                  child: ValueListenableBuilder(
                    valueListenable: songIsUpdated[song]!,
                    builder: (_, _, _) {
                      return Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Center(child: indexOrPlayButton()),
                          ),

                          Expanded(child: songListTile(song)),

                          SizedBox(width: 30),

                          Expanded(
                            child: Text(
                              getAlbum(song),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          SizedBox(width: 20),
                          SizedBox(
                            width: 80,
                            child: Align(
                              alignment: AlignmentGeometry.centerLeft,
                              child: IconButton(
                                onPressed: () {
                                  toggleFavoriteState(song);
                                },
                                icon: ValueListenableBuilder(
                                  valueListenable: songIsFavorite[song]!,
                                  builder: (context, value, child) {
                                    return value
                                        ? Icon(
                                            Icons.favorite_rounded,
                                            color: Colors.red,
                                            size: 20,
                                          )
                                        : Icon(
                                            Icons.favorite_outline,
                                            size: 20,
                                          );
                                  },
                                ),
                              ),
                            ),
                          ),

                          SizedBox(
                            width: 80,
                            child: Text(
                              formatDuration(getDuration(song)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
