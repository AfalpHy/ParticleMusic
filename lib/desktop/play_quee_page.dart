import 'dart:async';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/desktop/keyboard.dart';
import 'package:super_context_menu/super_context_menu.dart';
import '../audio_handler.dart';

final ValueNotifier<bool> displayPlayQueuePageNotifier = ValueNotifier(false);

class PlayQueuePage extends StatefulWidget {
  const PlayQueuePage({super.key});

  @override
  State<StatefulWidget> createState() => PlayQueueSheetState();
}

class PlayQueueSheetState extends State<PlayQueuePage> {
  final scrollController = ScrollController();
  int continuousSelectBeginIndex = -1;
  bool hideWiget = true;

  @override
  void initState() {
    super.initState();
    displayPlayQueuePageNotifier.addListener(() {
      if (displayPlayQueuePageNotifier.value) {
        hideWiget = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // using animateTo to avoid overscroll
          scrollController.animateTo(
            64.0 * audioHandler.currentIndex,
            duration: Duration(milliseconds: 1),
            curve: Curves.linear,
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<ValueNotifier<bool>> isSelectedList = List.generate(
      playQueue.length,
      (_) => ValueNotifier(false),
    );
    final Map<AudioMetadata, ValueNotifier<bool>> showPlayButtonMap = {};
    for (AudioMetadata song in playQueue) {
      showPlayButtonMap[song] = ValueNotifier(false);
    }
    if (displayPlayQueuePageNotifier.value == false && hideWiget == false) {
      Timer(Duration(milliseconds: 200), () {
        setState(() {
          hideWiget = true;
        });
      });
    }
    continuousSelectBeginIndex = -1;
    return hideWiget
        ? SizedBox.shrink()
        : Column(
            children: [
              SizedBox(height: 10),
              SizedBox(
                child: Row(
                  children: [
                    SizedBox(width: 15),
                    Text(
                      'Play Queue',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),

                    IconButton(
                      color: Colors.black,
                      onPressed: () {
                        scrollController.animateTo(
                          64.0 * audioHandler.currentIndex,
                          duration: Duration(milliseconds: 300),
                          curve: Curves.linear,
                        );
                      },
                      icon: Icon(Icons.my_location_rounded, size: 20),
                    ),
                    IconButton(
                      onPressed: () async {
                        if (await showConfirmDialog(context, 'Clear Action')) {
                          audioHandler.clear();

                          setState(() {});
                          displayPlayQueuePageNotifier.value = false;
                        }
                      },
                      icon: const ImageIcon(deleteImage, color: Colors.black),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),

              Expanded(
                child: ReorderableListView.builder(
                  itemExtent: 64,
                  scrollController: scrollController,
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    if (oldIndex == audioHandler.currentIndex) {
                      audioHandler.currentIndex = newIndex;
                    } else if (oldIndex < audioHandler.currentIndex &&
                        newIndex >= audioHandler.currentIndex) {
                      audioHandler.currentIndex -= 1;
                    } else if (oldIndex > audioHandler.currentIndex &&
                        newIndex <= audioHandler.currentIndex) {
                      audioHandler.currentIndex += 1;
                    }
                    final item = playQueue.removeAt(oldIndex);
                    playQueue.insert(newIndex, item);
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
                  itemCount: playQueue.length,
                  itemBuilder: (_, index) {
                    final song = playQueue[index];
                    final isSelected = isSelectedList[index];
                    final showPlayButtonNotifier = showPlayButtonMap[song]!;

                    return ContextMenuWidget(
                      key: ValueKey(song),
                      child: ReorderableDragStartListener(
                        index: index,
                        child: ValueListenableBuilder(
                          valueListenable: currentSongNotifier,
                          builder: (_, currentSong, _) {
                            return Center(
                              child: ValueListenableBuilder(
                                valueListenable: isSelected,
                                builder: (context, value, child) {
                                  return Material(
                                    color: value
                                        ? Colors.grey.shade300
                                        : Colors.transparent,
                                    child: MouseRegion(
                                      onEnter: (_) {
                                        showPlayButtonNotifier.value = true;
                                      },
                                      onExit: (_) {
                                        showPlayButtonNotifier.value = false;
                                      },
                                      child: InkWell(
                                        highlightColor: Colors.transparent,
                                        splashColor: Colors.transparent,
                                        child: ListTile(
                                          leading: Stack(
                                            children: [
                                              CoverArtWidget(
                                                size: 50,
                                                borderRadius: 5,
                                                source: getCoverArt(song),
                                              ),
                                              ValueListenableBuilder(
                                                valueListenable:
                                                    showPlayButtonNotifier,
                                                builder: (context, value, child) {
                                                  return value
                                                      ? IconButton(
                                                          onPressed: () async {
                                                            audioHandler
                                                                    .currentIndex =
                                                                index;
                                                            await audioHandler
                                                                .load();
                                                            await audioHandler
                                                                .play();
                                                          },
                                                          icon: Icon(
                                                            Icons
                                                                .play_arrow_rounded,
                                                            color: Colors.white,
                                                            size: 30,
                                                          ),
                                                        )
                                                      : SizedBox.shrink();
                                                },
                                              ),
                                            ],
                                          ),
                                          title: Text(
                                            getTitle(song),
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: song == currentSong
                                                  ? Color.fromARGB(
                                                      255,
                                                      75,
                                                      210,
                                                      210,
                                                    )
                                                  : null,
                                              fontWeight: song == currentSong
                                                  ? FontWeight.bold
                                                  : null,
                                              fontSize: 14,
                                            ),
                                          ),
                                          subtitle: Text(
                                            "${getArtist(song)} - ${getAlbum(song)}",
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          trailing: Text(
                                            formatDuration(getDuration(song)),
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        onTap: () async {
                                          if (ctrlIsPressed) {
                                            isSelected.value =
                                                !isSelected.value;
                                            continuousSelectBeginIndex = index;
                                          } else if (shiftIsPressed) {
                                            if (continuousSelectBeginIndex ==
                                                -1) {
                                              return;
                                            }
                                            int left =
                                                continuousSelectBeginIndex <
                                                    index
                                                ? continuousSelectBeginIndex
                                                : index;
                                            int right =
                                                continuousSelectBeginIndex >
                                                    index
                                                ? continuousSelectBeginIndex
                                                : index;

                                            for (
                                              int i = 0;
                                              i < isSelectedList.length;
                                              i++
                                            ) {
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
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      menuProvider: (request) {
                        // select current and clear others if it's not selected
                        if (!isSelected.value) {
                          for (var tmp in isSelectedList) {
                            tmp.value = false;
                          }
                          isSelected.value = true;
                          continuousSelectBeginIndex = index;
                        }
                        return Menu(
                          children: [
                            MenuAction(
                              title: 'Remove',
                              image: MenuImage.icon(Icons.close_rounded),
                              callback: () async {
                                bool removeCurrent = false;
                                for (
                                  int i = isSelectedList.length - 1;
                                  i >= 0;
                                  i--
                                ) {
                                  if (isSelectedList[i].value) {
                                    if (i < audioHandler.currentIndex) {
                                      audioHandler.currentIndex -= 1;
                                    } else if (i == audioHandler.currentIndex) {
                                      removeCurrent = true;
                                      if (audioHandler.currentIndex ==
                                          playQueue.length - 1) {
                                        audioHandler.currentIndex = 0;
                                      }
                                    }
                                    audioHandler.delete(i);
                                  }
                                }
                                setState(() {});
                                if (playQueue.isEmpty) {
                                  audioHandler.clear();
                                  displayPlayQueuePageNotifier.value = false;
                                } else if (removeCurrent) {
                                  await audioHandler.load();
                                  if (isPlayingNotifier.value) {
                                    await audioHandler.play();
                                  }
                                }
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
  }
}
