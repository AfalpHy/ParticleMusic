import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:vibration/vibration.dart';
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
    return SmoothClipRRect(
      smoothness: 1,
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      child: Container(
        height: 500,
        color: Colors.white,
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
                  IconButton(
                    color: Colors.black,
                    icon: ImageIcon(
                      playModeNotifier.value == 0
                          ? AssetImage("assets/images/loop.png")
                          : playModeNotifier.value == 1
                          ? AssetImage("assets/images/repeat.png")
                          : AssetImage("assets/images/shuffle.png"),
                      size: 25,
                    ),
                    onPressed: () {
                      audioHandler.switchPlayMode();
                      setState(() {
                        if (playModeNotifier.value != 1) {
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
                  if (hasVibration) {
                    Vibration.vibrate(duration: 5);
                  }
                },
                onReorderEnd: (_) {
                  if (hasVibration) {
                    Vibration.vibrate(duration: 5);
                  }
                },
                proxyDecorator:
                    (Widget child, int index, Animation<double> animation) {
                      return Material(
                        elevation: 1,
                        color: Colors.white, // background color while moving
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
                          "${song.title ?? "Unknown Title"} - ${song.artist ?? "Unknown Artist"}",
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
                      audioHandler.setIndex(index);
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
      ),
    );
  }
}
