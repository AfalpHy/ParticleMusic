import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/utils.dart';
import 'package:super_context_menu/super_context_menu.dart';

class PlayQueuePage extends StatefulWidget {
  const PlayQueuePage({super.key});

  @override
  State<StatefulWidget> createState() => PlayQueuePageState();
}

class PlayQueuePageState extends State<PlayQueuePage> {
  final scrollController = ScrollController();

  List<ValueNotifier<bool>> isSelectedList = [];
  int continuousSelectBeginIndex = 0;

  late bool isMiniMode;
  late double itemExtend;
  @override
  void initState() {
    super.initState();
    isMiniMode = miniModeNotifier.value;
    itemExtend = isMiniMode ? 56 : 64;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (playQueue.length != isSelectedList.length) {
      isSelectedList = List.generate(
        playQueue.length,
        (_) => ValueNotifier(false),
      );

      continuousSelectBeginIndex = 0;
    }

    return Column(
      children: [
        SizedBox(height: 10),
        topBar(l10n),
        SizedBox(height: 10),

        Expanded(
          child: ReorderableListView.builder(
            itemExtent: itemExtend,
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
              // clearing selected after reordering
              for (var tmp in isSelectedList) {
                tmp.value = false;
              }
              continuousSelectBeginIndex = 0;
            },

            proxyDecorator:
                (Widget child, int index, Animation<double> animation) {
                  return Material(
                    elevation: 0.1,
                    color: isMiniMode
                        ? Colors.grey.shade300
                        : Colors.grey.shade100, // background color while moving
                    child: child,
                  );
                },
            itemCount: playQueue.length,
            itemBuilder: (context, index) {
              return playQueueItemWithContextMenu(
                context,
                index,
                isSelectedList,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget topBar(AppLocalizations l10n) {
    return Row(
      children: [
        SizedBox(width: 15),
        Text(
          l10n.playQueue,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isMiniMode ? Colors.grey.shade100 : null,
          ),
        ),
        Spacer(),

        ValueListenableBuilder(
          valueListenable: playModeNotifier,
          builder: (_, playMode, _) {
            return IconButton(
              color: isMiniMode ? Colors.grey.shade100 : Colors.black,
              icon: ImageIcon(
                playMode == 0
                    ? loopImage
                    : playMode == 1
                    ? shuffleImage
                    : repeatImage,
                size: 22,
              ),
              onPressed: () {
                if (playModeNotifier.value != 2) {
                  audioHandler.switchPlayMode();
                  switch (playModeNotifier.value) {
                    case 0:
                      showCenterMessage(context, l10n.loop);
                      break;
                    default:
                      showCenterMessage(context, l10n.shuffle);
                      break;
                  }
                }
                setState(() {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // using animateTo to avoid overscroll
                    scrollController.animateTo(
                      itemExtend * audioHandler.currentIndex,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.linear,
                    );
                  });
                });
              },
              onLongPress: () {
                audioHandler.toggleRepeat();
                switch (playModeNotifier.value) {
                  case 0:
                    showCenterMessage(context, l10n.loop);
                    break;
                  case 1:
                    showCenterMessage(context, l10n.shuffle);
                    break;
                  default:
                    showCenterMessage(context, l10n.repeat);
                    break;
                }
              },
            );
          },
        ),

        IconButton(
          color: isMiniMode ? Colors.grey.shade100 : Colors.black,
          onPressed: () {
            scrollController.animateTo(
              itemExtend * audioHandler.currentIndex,
              duration: Duration(milliseconds: 300),
              curve: Curves.linear,
            );
          },
          icon: Icon(Icons.my_location_rounded, size: 20),
        ),
        IconButton(
          onPressed: () async {
            if (await showConfirmDialog(context, l10n.clear)) {
              await audioHandler.clear();

              displayPlayQueuePageNotifier.value = false;
              displayLyricsPageNotifier.value = false;
            }
          },
          icon: ImageIcon(
            deleteImage,
            color: isMiniMode ? Colors.grey.shade100 : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget playQueueItemWithContextMenu(
    BuildContext context,
    int index,
    List<ValueNotifier<bool>> isSelectedList,
  ) {
    final song = playQueue[index];
    final isSelected = isSelectedList[index];
    final l10n = AppLocalizations.of(context);

    return ContextMenuWidget(
      key: ValueKey(song),
      child: PlayQueueItem(
        index: index,
        isSelected: isSelected,
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
              title: l10n.add2Playlists,
              image: MenuImage.icon(Icons.playlist_add_rounded),
              callback: () {
                final List<MyAudioMetadata> tmpSongList = [];
                for (int i = isSelectedList.length - 1; i >= 0; i--) {
                  if (isSelectedList[i].value) {
                    tmpSongList.add(playQueue[i]);
                  }
                }
                showAddPlaylistDialog(context, tmpSongList);
              },
            ),
            MenuAction(
              title: l10n.remove,
              image: MenuImage.icon(Icons.close_rounded),
              callback: () async {
                bool removeCurrent = false;
                for (int i = isSelectedList.length - 1; i >= 0; i--) {
                  if (isSelectedList[i].value) {
                    if (i < audioHandler.currentIndex) {
                      audioHandler.currentIndex -= 1;
                    } else if (i == audioHandler.currentIndex) {
                      removeCurrent = true;
                      if (audioHandler.currentIndex == playQueue.length - 1) {
                        audioHandler.currentIndex = 0;
                      }
                    }
                    audioHandler.delete(i);
                  }
                }

                setState(() {});
                if (playQueue.isEmpty) {
                  await audioHandler.clear();
                  displayPlayQueuePageNotifier.value = false;
                  displayLyricsPageNotifier.value = false;
                } else if (removeCurrent) {
                  await audioHandler.load();
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class PlayQueueItem extends StatefulWidget {
  final int index;
  final ValueNotifier<bool> isSelected;
  final void Function()? onTap;

  const PlayQueueItem({
    super.key,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<StatefulWidget> createState() => PlayQueueItemChildState();
}

class PlayQueueItemChildState extends State<PlayQueueItem> {
  final showPlayButtonNotifier = ValueNotifier(false);

  Widget songListTile() {
    final song = playQueue[widget.index];
    return ListTile(
      leading: Stack(
        children: [
          miniModeNotifier.value
              ? CoverArtWidget(size: 40, borderRadius: 4, song: song)
              : CoverArtWidget(size: 50, borderRadius: 5, song: song),
          ValueListenableBuilder(
            valueListenable: showPlayButtonNotifier,
            builder: (context, value, child) {
              return value
                  ? IconButton(
                      onPressed: () async {
                        audioHandler.currentIndex = widget.index;
                        await audioHandler.load();
                        await audioHandler.play();
                      },
                      icon: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: miniModeNotifier.value ? 20 : 30,
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
                  ? miniModeNotifier.value
                        ? Colors.white
                        : textColor
                  : miniModeNotifier.value
                  ? Colors.grey.shade100
                  : null,

              fontWeight: song == currentSong ? FontWeight.w900 : null,
              fontSize: 15,
            ),
          );
        },
      ),
      subtitle: Text(
        "${getArtist(song)} - ${getAlbum(song)}",
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: miniModeNotifier.value ? Colors.grey.shade100 : null,
        ),
      ),
      trailing: Text(
        formatDuration(getDuration(song)),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: miniModeNotifier.value ? Colors.grey.shade100 : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: widget.index,
      child: ValueListenableBuilder(
        valueListenable: widget.isSelected,
        builder: (context, value, child) {
          return Material(
            color: value
                ? miniModeNotifier.value
                      ? currentCoverArtColor
                      : Colors.grey.shade300
                : Colors.transparent,
            child: child,
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
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            onTap: widget.onTap,
            child: songListTile(),
          ),
        ),
      ),
    );
  }
}
