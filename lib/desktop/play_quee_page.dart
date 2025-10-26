import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import '../audio_handler.dart';

class PlayQueuePage extends StatefulWidget {
  const PlayQueuePage({super.key});

  @override
  State<StatefulWidget> createState() => PlayQueueSheetState();
}

class PlayQueueSheetState extends State<PlayQueuePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 10),
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
                onPressed: () async {
                  if (await showConfirmDialog(context, 'Clear Action')) {
                    audioHandler.clear();

                    setState(() {});
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
                    color:
                        Colors.grey.shade100, // background color while moving
                    child: child,
                  );
                },
            itemCount: playQueue.length,
            itemBuilder: (_, index) {
              final song = playQueue[index];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(index),
                index: index,
                child: ValueListenableBuilder(
                  valueListenable: currentSongNotifier,
                  builder: (_, currentSong, _) {
                    return Center(
                      child: ListTile(
                        leading: CoverArtWidget(
                          size: 50,
                          borderRadius: 5,
                          source: getCoverArt(song),
                        ),
                        title: Text(
                          getTitle(song),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: song == currentSong
                                ? Color.fromARGB(255, 75, 210, 210)
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
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Text(
                          twoPadDuration(getDuration(song)),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12),
                        ),
                        onTap: () async {
                          audioHandler.currentIndex = index;
                          await audioHandler.load();
                          await audioHandler.play();
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
