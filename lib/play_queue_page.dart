import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'audio_handler.dart';

class PlayQueuePage extends StatefulWidget {
  const PlayQueuePage({super.key});

  @override
  State<StatefulWidget> createState() => PlayQueuePageState();
}

class PlayQueuePageState extends State<PlayQueuePage> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 500,
      child: Column(
        children: [
          // Optional drag handle
          Container(
            margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.black,
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
                  selector: (_, audioHandeler) => audioHandeler.playMode,
                  builder: (_, playMode, _) {
                    return IconButton(
                      color: Colors.black,
                      icon: Icon(
                        playMode == 0
                            ? Icons.loop_rounded
                            : playMode == 1
                            ? Icons.repeat_rounded
                            : Icons.shuffle_rounded,
                        size: 15,
                      ),
                      onPressed: () {
                        audioHandler.switchPlayMode();
                        setState(() {});
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
                    size: 15,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ReorderableListView(
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
                  key: ValueKey(index),
                  selector: (_, audioHandeler) => audioHandeler.currentIndex,
                  builder: (_, currentIndex, _) {
                    final isCurrentSong = index == currentIndex;
                    return ListTile(
                      contentPadding: EdgeInsets.fromLTRB(15, 0, 0, 0),
                      tileColor: isCurrentSong ? Colors.white54 : null,
                      title: Text(
                        "${song.title ?? "Unknown Title"} - ${song.artist ?? "Unknown Artist"}",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrentSong ? Colors.brown : null,
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
                          size: 15,
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
    );
  }
}
