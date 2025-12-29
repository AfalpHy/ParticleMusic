import 'dart:async';
import 'dart:math';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/desktop/keyboard.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/metadata.dart';
import 'package:particle_music/my_location.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/base_song_list.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:super_context_menu/super_context_menu.dart';

class SongListPanel extends BaseSongListWidget {
  final Widget? foldersWidget;
  const SongListPanel({
    super.key,
    super.playlist,
    super.artist,
    super.album,
    super.folder,
    this.foldersWidget,
  });

  @override
  State<SongListPanel> createState() => _SongListPanel();
}

class _SongListPanel extends BaseSongListState<SongListPanel> {
  int continuousSelectBeginIndex = 0;

  late EdgeInsets padding;

  @override
  void initState() {
    super.initState();

    padding = folder == null
        ? const EdgeInsets.symmetric(horizontal: 30)
        : const EdgeInsets.fromLTRB(30, 0, 10, 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        TitleBar(
          searchField: titleSearchField(
            l10n.searchSongs,
            textController: textController,
            onChanged: (_) {
              updateSongList();
            },
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: contentWidget(context)),

              if (widget.foldersWidget != null) ...[
                SizedBox(width: 5),

                VerticalDivider(
                  thickness: 0.5,
                  width: 1,
                  color: Colors.grey.shade400,
                ),
                SizedBox(width: 10),

                widget.foldersWidget!,

                SizedBox(width: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget contentWidget(BuildContext context) {
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
                child: Padding(padding: padding, child: header()),
              ),

              SliverToBoxAdapter(
                child: Padding(padding: padding, child: label()),
              ),

              SliverPadding(
                padding: padding,
                sliver: ValueListenableBuilder(
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
                        return playlist != null &&
                                textController.text == '' &&
                                sortTypeNotifier.value == 0
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

                        final item = playlist!.songs.removeAt(oldIndex);
                        playlist!.songs.insert(newIndex, item);

                        playlist!.update();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        Positioned(
          right: folder == null ? 120 : 100,
          bottom: 100,
          child: MyLocation(
            scrollController: scrollController,
            listIsScrollingNotifier: listIsScrollingNotifier,
            currentSongListNotifier: currentSongListNotifier,
            offset: 200 - (MediaQuery.heightOf(context) - 280) / 2,
          ),
        ),
      ],
    );
  }

  Widget header() {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: 200,
      child: Row(
        children: [
          mainCover(180),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                SizedBox(height: 30),
                ListTile(
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
                Spacer(),

                Row(
                  children: [
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        if (currentSongListNotifier.value.isEmpty) {
                          return;
                        }
                        audioHandler.currentIndex = 0;
                        playModeNotifier.value = 0;
                        await audioHandler.setPlayQueue(
                          currentSongListNotifier.value,
                        );
                        await audioHandler.play();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 240, 245, 250),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        padding: EdgeInsets.all(10),
                      ),
                      child: Text(l10n.playAll),
                    ),
                    SizedBox(width: 15),

                    ElevatedButton(
                      onPressed: () async {
                        if (currentSongListNotifier.value.isEmpty) {
                          return;
                        }
                        audioHandler.currentIndex = Random().nextInt(
                          currentSongListNotifier.value.length,
                        );
                        playModeNotifier.value = 1;
                        await audioHandler.setPlayQueue(
                          currentSongListNotifier.value,
                        );
                        await audioHandler.play();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 240, 245, 250),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        padding: EdgeInsets.all(10),
                      ),
                      child: Text(l10n.shuffle),
                    ),
                    SizedBox(width: 10),
                  ],
                ),
                SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget label() {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: 50,
      child: Row(
        children: [
          SizedBox(width: 60, child: Center(child: Text('#'))),

          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(5),
              onTap: () {
                if (sortTypeNotifier.value > 4) {
                  sortTypeNotifier.value = 1;
                } else if (sortTypeNotifier.value < 4) {
                  sortTypeNotifier.value++;
                } else {
                  sortTypeNotifier.value = 0;
                }
                playlist?.saveSetting();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: ValueListenableBuilder(
                  valueListenable: sortTypeNotifier,
                  builder: (context, value, child) {
                    String text = '${l10n.title} & ${l10n.artist}';
                    switch (value) {
                      case 1:
                      case 2:
                        text = l10n.title;
                        break;
                      case 3:
                      case 4:
                        text = text = l10n.artist;
                        break;
                    }
                    return Row(
                      children: [
                        Text(text, overflow: TextOverflow.ellipsis),
                        if (value > 0 && value <= 4)
                          ImageIcon(
                            (value == 1 || value == 3)
                                ? longArrowUpImage
                                : longArrowDownImage,
                            size: 20,
                            color: Colors.black54,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          SizedBox(width: 10),

          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(5),
              onTap: () {
                if (sortTypeNotifier.value == 5) {
                  sortTypeNotifier.value = 6;
                } else if (sortTypeNotifier.value == 6) {
                  sortTypeNotifier.value = 0;
                } else {
                  sortTypeNotifier.value = 5;
                }
                playlist?.saveSetting();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Text(l10n.album, overflow: TextOverflow.ellipsis),
                    ValueListenableBuilder(
                      valueListenable: sortTypeNotifier,
                      builder: (context, value, child) {
                        if (value == 5 || value == 6) {
                          return ImageIcon(
                            value == 5 ? longArrowUpImage : longArrowDownImage,
                            size: 20,
                            color: Colors.black54,
                          );
                        }
                        return SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(width: 10),

          SizedBox(
            width: 80,
            child: Text(l10n.favorited, overflow: TextOverflow.ellipsis),
          ),

          SizedBox(
            width: 90,
            child: InkWell(
              borderRadius: BorderRadius.circular(5),
              onTap: () {
                if (sortTypeNotifier.value == 7) {
                  sortTypeNotifier.value = 8;
                } else if (sortTypeNotifier.value == 8) {
                  sortTypeNotifier.value = 0;
                } else {
                  sortTypeNotifier.value = 7;
                }
                playlist?.saveSetting();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Text(l10n.duration, overflow: TextOverflow.ellipsis),
                    ValueListenableBuilder(
                      valueListenable: sortTypeNotifier,
                      builder: (context, value, child) {
                        if (value == 7 || value == 8) {
                          return ImageIcon(
                            value == 7 ? longArrowUpImage : longArrowDownImage,
                            size: 20,
                            color: Colors.black54,
                          );
                        }
                        return SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    final l10n = AppLocalizations.of(context);

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
              title: l10n.playNow,
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
              title: l10n.playNext,
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
              title: l10n.add2Playlists,
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
                title: l10n.editMetadata,
                image: MenuImage.icon(Icons.edit_rounded),
                callback: () {
                  showSongMetadataDialog(context, currentSongList[index]);
                },
              ),
            if (playlist != null)
              MenuAction(
                title: l10n.delete,
                image: MenuImage.icon(Icons.delete_rounded),
                callback: () async {
                  if (await showConfirmDialog(context, l10n.delete)) {
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
                  await audioHandler.setPlayQueue(widget.currentSongList);
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

    return SmoothClipRRect(
      smoothness: 1,
      borderRadius: BorderRadius.circular(15),
      child: ValueListenableBuilder(
        valueListenable: widget.isSelected,
        builder: (context, value, child) {
          return Material(
            color: value ? Colors.white : Color.fromARGB(255, 235, 240, 245),
            child: child,
          );
        },
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

                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        getAlbum(song),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    SizedBox(width: 10),
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
                                  : Icon(Icons.favorite_outline, size: 20);
                            },
                          ),
                        ),
                      ),
                    ),

                    SizedBox(
                      width: 90,
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
      ),
    );
  }
}
