import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'audio_handler.dart';

class PlayQueuePage extends StatefulWidget {
  const PlayQueuePage({super.key});

  @override
  State<StatefulWidget> createState() => PlayQueuePageState();
}

class PlayQueuePageState extends State<PlayQueuePage> {
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

      scrollController.animateTo(
        lineHeight * audioHandler.currentIndex,
        duration: Duration(milliseconds: 300), // smooth animation
        curve: Curves.linear,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      child: Container(
        height: 500,
        color: Colors.grey.shade100,
        child: Column(
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
                  Selector<MyAudioHandler, int>(
                    selector: (_, audioHandler) => audioHandler.playMode,
                    builder: (_, playMode, _) {
                      return IconButton(
                        color: Colors.black,
                        icon: Icon(
                          playMode == 0
                              ? Icons.loop_rounded
                              : playMode == 1
                              ? Icons.repeat_rounded
                              : Icons.shuffle_rounded,
                          size: 20,
                        ),
                        onPressed: () {
                          audioHandler.switchPlayMode();
                          setState(() {
                            if (audioHandler.playMode != 1) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                scrollController.animateTo(
                                  lineHeight * audioHandler.currentIndex,
                                  duration: Duration(
                                    milliseconds: 300,
                                  ), // smooth animation
                                  curve: Curves.linear,
                                );
                              });
                            }
                          });
                        },
                      );
                    },
                  ),
                  IconButton(
                    onPressed: () {
                      playQueue = [];
                      audioHandler.clear();
                      while (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    icon: Icon(
                      Icons.delete_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ReorderableListView(
                scrollController: scrollController,
                physics: ClampingScrollPhysics(),

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
                children: List.generate(playQueue.length, (index) {
                  final song = playQueue[index];
                  return Selector<MyAudioHandler, int>(
                    key: playQueueGlobalKeys[index],
                    selector: (_, audioHandler) => audioHandler.currentIndex,
                    builder: (_, currentIndex, _) {
                      final isCurrentSong = index == currentIndex;
                      return ListTile(
                        contentPadding: EdgeInsets.fromLTRB(15, 0, 0, 0),
                        title: Text(
                          "${song.title ?? "Unknown Title"} - ${song.artist ?? "Unknown Artist"}",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrentSong
                                ? Color.fromARGB(255, 75, 210, 210)
                                : null,
                            fontWeight: isCurrentSong ? FontWeight.bold : null,
                          ),
                        ),

                        visualDensity: const VisualDensity(
                          horizontal: 0,
                          vertical: -4,
                        ),
                        onTap: () async {
                          audioHandler.setIndex(index);
                          await audioHandler.load();
                          audioHandler.play();
                        },

                        trailing: IconButton(
                          onPressed: () {
                            audioHandler.delete(index);
                            if (index < audioHandler.currentIndex) {
                              audioHandler.currentIndex -= 1;
                            } else if (index == audioHandler.currentIndex) {
                              if (playQueue.isEmpty) {
                                audioHandler.clear();
                                while (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }
                              } else {
                                audioHandler.load();
                              }
                            }
                            setState(() {});
                          },
                          icon: Icon(
                            Icons.clear_rounded,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
