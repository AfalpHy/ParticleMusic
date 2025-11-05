import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/desktop/keyboard.dart';
import 'package:particle_music/desktop/pages/lyrics_page.dart';
import 'package:particle_music/playlists.dart';
import 'package:super_context_menu/super_context_menu.dart';
import '../../audio_handler.dart';

final ValueNotifier<bool> displayPlayQueuePageNotifier = ValueNotifier(false);

class PlayQueuePage extends StatefulWidget {
  const PlayQueuePage({super.key});

  @override
  State<StatefulWidget> createState() => PlayQueuePageState();
}

class PlayQueuePageState extends State<PlayQueuePage> {
  final scrollController = ScrollController();
  int continuousSelectBeginIndex = 0;

  @override
  void initState() {
    super.initState();
    displayPlayQueuePageNotifier.addListener(() {
      if (displayPlayQueuePageNotifier.value) {
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

    continuousSelectBeginIndex = 0;

    return Column(
      children: [
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 15),
            Text(
              'Play Queue',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

                  displayPlayQueuePageNotifier.value = false;
                  displayLyricsPageNotifier.value = false;
                }
              },
              icon: const ImageIcon(deleteImage, color: Colors.black),
            ),
          ],
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
                    color:
                        Colors.grey.shade100, // background color while moving
                    child: child,
                  );
                },
            itemCount: playQueue.length,
            itemBuilder: (context, index) {
              return playQueueItem(context, index, isSelectedList);
            },
          ),
        ),
      ],
    );
  }

  Widget playQueueItem(
    BuildContext context,
    int index,
    List<ValueNotifier<bool>> isSelectedList,
  ) {
    final song = playQueue[index];
    final isSelected = isSelectedList[index];

    return ContextMenuWidget(
      key: ValueKey(song),
      child: PlayQueueItemChild(
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
              title: 'Add to Playlists',
              image: MenuImage.icon(Icons.playlist_add_rounded),
              callback: () {
                final List<AudioMetadata> tmpSongList = [];
                for (int i = isSelectedList.length - 1; i >= 0; i--) {
                  if (isSelectedList[i].value) {
                    tmpSongList.add(playQueue[i]);
                  }
                }
                showAddPlaylistDialog(context, tmpSongList);
              },
            ),
            MenuAction(
              title: 'Remove',
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
                  audioHandler.clear();
                  displayPlayQueuePageNotifier.value = false;
                  displayLyricsPageNotifier.value = false;
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
  }
}

class PlayQueueItemChild extends StatefulWidget {
  final int index;
  final ValueNotifier<bool> isSelected;
  final void Function()? onTap;

  const PlayQueueItemChild({
    super.key,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<StatefulWidget> createState() => PlayQueueItemChildState();
}

class PlayQueueItemChildState extends State<PlayQueueItemChild> {
  final showPlayButtonNotifier = ValueNotifier(false);

  Widget songListTile() {
    final song = playQueue[widget.index];
    return ListTile(
      leading: Stack(
        children: [
          CoverArtWidget(size: 50, borderRadius: 5, source: getCoverArt(song)),
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
                        size: 30,
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
                  ? Color.fromARGB(255, 75, 210, 210)
                  : null,
              fontWeight: song == currentSong ? FontWeight.bold : null,
              fontSize: 14,
            ),
          );
        },
      ),
      subtitle: Text(
        "${getArtist(song)} - ${getAlbum(song)}",
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: Text(
        formatDuration(getDuration(song)),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12),
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
            color: value ? Colors.grey.shade300 : Colors.transparent,
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
          );
        },
      ),
    );
  }
}
