import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:particle_music/common.dart';
import '../audio_handler.dart';

class PlayQueueSheet extends StatefulWidget {
  const PlayQueueSheet({super.key});

  @override
  State<StatefulWidget> createState() => PlayQueueSheetState();
}

class PlayQueueSheetState extends State<PlayQueueSheet> {
  List<GlobalKey> playQueueGlobalKeys = [];
  final scrollController = ScrollController();
  double lineHeight = 0;

  @override
  void initState() {
    super.initState();
    playQueueGlobalKeys = List.generate(playQueue.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      lineHeight =
          (playQueueGlobalKeys[0].currentContext!.findRenderObject()
                  as RenderBox)
              .size
              .height;

      scrollController.jumpTo(lineHeight * audioHandler.currentIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    return mySheet(
      Column(
        children: [
          // Optional drag handle
          Container(
            margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
            width: 50,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          SizedBox(
            child: Row(
              children: [
                SizedBox(width: 15),
                Text(
                  'Play Queue',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Spacer(),

                IconButton(
                  color: Colors.black,
                  icon: ImageIcon(
                    playModeNotifier.value == 0
                        ? loopImage
                        : playModeNotifier.value == 1
                        ? shuffleImage
                        : repeatImage,
                    size: 25,
                  ),
                  onPressed: () {
                    if (playModeNotifier.value != 2) {
                      audioHandler.switchPlayMode();
                      switch (playModeNotifier.value) {
                        case 0:
                          showCenterMessage(context, "loop");
                          break;
                        default:
                          showCenterMessage(context, "shuffle");
                          break;
                      }
                      setState(() {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          scrollController.animateTo(
                            lineHeight * audioHandler.currentIndex,
                            duration: Duration(
                              milliseconds: 300,
                            ), // smooth animation
                            curve: Curves.linear,
                          );
                        });
                      });
                    }
                  },
                  onLongPress: () {
                    audioHandler.toggleRepeat();
                    switch (playModeNotifier.value) {
                      case 0:
                        showCenterMessage(context, "loop");
                        break;
                      case 1:
                        showCenterMessage(context, "shuffle");
                        break;
                      default:
                        showCenterMessage(context, "repeat");
                        break;
                    }
                    setState(() {});
                  },
                ),
                IconButton(
                  onPressed: () async {
                    if (await showConfirmDialog(context, 'Clear Action')) {
                      audioHandler.clear();

                      while (context.mounted && Navigator.canPop(context)) {
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    }
                  },
                  icon: const ImageIcon(deleteImage, color: Colors.black),
                ),
              ],
            ),
          ),

          Expanded(
            child: ReorderableListView.builder(
              scrollController: scrollController,

              onReorder: (oldIndex, newIndex) {
                setState(() {
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
                });
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
                      color:
                          Colors.grey.shade100, // background color while moving
                      child: child,
                    );
                  },
              itemCount: playQueue.length,
              itemBuilder: (_, index) {
                final song = playQueue[index];
                return ListTile(
                  key: playQueueGlobalKeys[index],
                  contentPadding: EdgeInsets.fromLTRB(15, 0, 0, 0),
                  title: ValueListenableBuilder(
                    valueListenable: currentSongNotifier,
                    builder: (_, currentSong, _) {
                      return Text(
                        "${getTitle(song)} - ${getArtist(song)}",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: song == currentSong
                              ? Color.fromARGB(255, 75, 210, 210)
                              : null,
                          fontWeight: song == currentSong
                              ? FontWeight.bold
                              : null,
                        ),
                      );
                    },
                  ),

                  visualDensity: const VisualDensity(
                    horizontal: 0,
                    vertical: -4,
                  ),
                  onTap: () async {
                    audioHandler.currentIndex = index;
                    await audioHandler.load();
                    await audioHandler.play();
                  },

                  trailing: IconButton(
                    onPressed: () async {
                      audioHandler.delete(index);
                      setState(() {});
                      if (index < audioHandler.currentIndex) {
                        audioHandler.currentIndex -= 1;
                      } else if (index == audioHandler.currentIndex) {
                        if (playQueue.isEmpty) {
                          audioHandler.clear();
                          while (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        } else {
                          if (index == playQueue.length) {
                            audioHandler.currentIndex = 0;
                          }
                          await audioHandler.load();
                        }
                      }
                    },
                    icon: Icon(
                      Icons.clear_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
