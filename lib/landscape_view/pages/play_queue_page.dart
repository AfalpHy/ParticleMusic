import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/utils/format_duration.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/widgets/buttons.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/playlist_widgets.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/base/services/keyboard.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';

class PlayQueuePage extends StatefulWidget {
  const PlayQueuePage({super.key});

  @override
  State<StatefulWidget> createState() => PlayQueuePageState();
}

class PlayQueuePageState extends State<PlayQueuePage> {
  final scrollController = ScrollController();

  List<ValueNotifier<bool>> isSelectedList = [];
  int continuousSelectBeginIndex = 0;

  final showPlayButtonNotifierMap = <MyAudioMetadata, ValueNotifier<bool>>{};

  double itemExtend = 64;

  void jumpToCurrentSong() {
    final position = scrollController.position;
    final maxScrollExtent = position.maxScrollExtent;
    final minScrollExtent = position.minScrollExtent;
    scrollController.jumpTo(
      (itemExtend * audioHandler.currentIndex).clamp(
        minScrollExtent,
        maxScrollExtent,
      ),
    );
  }

  void updateQueue({bool needJump = true}) {
    setState(() {
      isSelectedList = List.generate(
        playQueue.length,
        (_) => ValueNotifier(false),
      );
      continuousSelectBeginIndex = 0;

      showPlayButtonNotifierMap.clear();
      for (var e in playQueue) {
        showPlayButtonNotifierMap[e] = ValueNotifier(false);
      }
    });
    if (needJump) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        jumpToCurrentSong();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    playModeNotifier.addListener(updateQueue);
    isSelectedList = List.generate(
      playQueue.length,
      (_) => ValueNotifier(false),
    );
    continuousSelectBeginIndex = 0;

    for (var e in playQueue) {
      showPlayButtonNotifierMap[e] = ValueNotifier(false);
    }
  }

  @override
  void dispose() {
    playModeNotifier.removeListener(updateQueue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 10),
        topBar(context),
        SizedBox(height: 10),

        Expanded(
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverReorderableList(
                itemExtent: itemExtend,
                onReorderItem: (oldIndex, newIndex) {
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

                  audioHandler.saveAllStates();

                  // clearing selected after reordering
                  for (var tmp in isSelectedList) {
                    tmp.value = false;
                  }
                  continuousSelectBeginIndex = 0;
                },

                itemCount: playQueue.length,
                itemBuilder: (context, index) {
                  return playQueueItem(index);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget topBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final specificTextColor = colorManager.getSpecificTextColor();
    final specificIconColor = colorManager.getSpecificIconColor();

    return Row(
      children: [
        SizedBox(width: 15),
        Text(
          l10n.playQueue,
          style: TextStyle(
            fontSize: viewModeNotifier.value == .mini ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: specificTextColor,
          ),
        ),
        Spacer(),

        IconButton(
          color: specificIconColor,
          onPressed: () {
            audioHandler.reversePlayQueue();
            updateQueue();
          },
          icon: ImageIcon(reverseImage),
        ),

        playModeButton(null, iconColor: specificIconColor),

        IconButton(
          color: specificIconColor,
          onPressed: () {
            final position = scrollController.position;
            final maxScrollExtent = position.maxScrollExtent;
            final minScrollExtent = position.minScrollExtent;
            scrollController.animateTo(
              (itemExtend * audioHandler.currentIndex).clamp(
                minScrollExtent,
                maxScrollExtent,
              ),
              duration: Duration(milliseconds: 300),
              curve: Curves.linear,
            );
          },
          icon: ImageIcon(locationImage),
        ),
        IconButton(
          color: specificIconColor,
          onPressed: () async {
            if (await showConfirmDialog(context, l10n.clear)) {
              await audioHandler.clear();

              while (context.mounted && Navigator.canPop(context)) {
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            }
          },
          icon: ImageIcon(deleteImage),
        ),
      ],
    );
  }

  Widget playQueueItem(int index) {
    final isSelected = isSelectedList[index];
    final song = playQueue[index];
    final showPlayButtonNotifier = showPlayButtonNotifierMap[song]!;

    final specificTextColor = colorManager.getSpecificTextColor();
    final specificHighlightText = colorManager.getSpecificHighlightTextColor();

    return ReorderableDragStartListener(
      key: ValueKey(index),
      index: index,
      child: ValueListenableBuilder(
        valueListenable: isSelected,
        builder: (context, value, child) {
          return ValueListenableBuilder(
            valueListenable: currentSongNotifier,
            builder: (_, _, _) {
              return Material(
                color: value
                    ? colorManager.getSpecificSelectedItemColor()
                    : Colors.transparent,
                child: child,
              );
            },
          );
        },
        child: MouseRegion(
          onEnter: (_) {
            showPlayButtonNotifier.value = true;
          },
          onExit: (_) {
            showPlayButtonNotifier.value = false;
          },
          child: InkWell(
            child: ListTile(
              leading: Stack(
                children: [
                  viewModeNotifier.value == .mini
                      ? CoverArtWidget(size: 40, borderRadius: 4, song: song)
                      : CoverArtWidget(size: 50, borderRadius: 5, song: song),
                  ValueListenableBuilder(
                    valueListenable: showPlayButtonNotifier,
                    builder: (context, value, child) {
                      return value
                          ? IconButton(
                              onPressed: () async {
                                audioHandler.currentIndex = index;
                                await audioHandler.load();
                                await audioHandler.play();
                              },
                              icon: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: viewModeNotifier.value == .mini ? 20 : 30,
                              ),
                            )
                          : SizedBox.shrink();
                    },
                  ),
                ],
              ),
              title: ValueListenableBuilder(
                valueListenable: currentSongNotifier,
                builder: (_, currentSong, _) {
                  return Text(
                    getTitle(song),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: song == currentSong
                          ? specificHighlightText
                          : specificTextColor,

                      fontWeight: song == currentSong ? FontWeight.bold : null,
                      fontSize: 15,
                    ),
                  );
                },
              ),
              subtitle: Text(
                "${getArtist(song)} - ${getAlbum(song)}",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: specificTextColor),
              ),
              trailing: Text(
                formatDuration(getDuration(song)),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: specificTextColor),
              ),
            ),

            onTap: () async {
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

            onSecondaryTapUp: (details) {
              if (!isSelected.value) {
                for (var tmp in isSelectedList) {
                  tmp.value = false;
                }
                isSelected.value = true;
                continuousSelectBeginIndex = index;
              }
              final l10n = AppLocalizations.of(context);
              final menuItems = <MenuItem>[];

              final List<MyAudioMetadata> selectedSongList = [];
              for (int i = isSelectedList.length - 1; i >= 0; i--) {
                if (isSelectedList[i].value) {
                  selectedSongList.add(playQueue[i]);
                }
              }
              menuItems.add(
                MenuItem(
                  iconData: Icons.playlist_add_rounded,
                  text: l10n.add2Playlist,
                  callback: () {
                    showAddPlaylistDialog(context, selectedSongList);
                  },
                ),
              );

              menuItems.add(
                MenuItem(
                  text: l10n.playNext,
                  iconData: Icons.navigate_next_rounded,
                  callback: () async {
                    for (int i = 0; i < selectedSongList.length; i++) {
                      audioHandler.insert2Next(selectedSongList[i]);
                    }
                    audioHandler.saveAllStates();
                    setState(() {});
                  },
                ),
              );

              menuItems.add(
                MenuItem(
                  iconData: Icons.close_rounded,
                  text: l10n.remove,
                  callback: () async {
                    bool removeCurrent = false;
                    for (int i = isSelectedList.length - 1; i >= 0; i--) {
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

                    if (playQueue.isEmpty) {
                      while (Navigator.canPop(context)) {
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                      await audioHandler.clear();
                    } else {
                      updateQueue(needJump: false);
                      if (removeCurrent) {
                        await audioHandler.load();
                      }
                    }

                    audioHandler.saveAllStates();
                  },
                ),
              );

              showContextMenu(context, menuItems, details.globalPosition);
            },
          ),
        ),
      ),
    );
  }
}
