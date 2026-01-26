import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/mobile/widgets/my_sheet.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/utils.dart';

class PlayQueueSheet extends StatefulWidget {
  const PlayQueueSheet({super.key});

  @override
  State<StatefulWidget> createState() => PlayQueueSheetState();
}

class PlayQueueSheetState extends State<PlayQueueSheet> {
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (audioHandler.currentIndex > 3) {
        scrollController.jumpTo(54.0 * audioHandler.currentIndex - 162);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return MySheet(
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
                  l10n.playQueue,
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
                          showCenterMessage(context, l10n.loop);
                          break;
                        default:
                          showCenterMessage(context, l10n.shuffle);
                          break;
                      }
                      setState(() {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          scrollController.animateTo(
                            54.0 * audioHandler.currentIndex - 162,
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
                        showCenterMessage(context, l10n.loop);
                        break;
                      case 1:
                        showCenterMessage(context, l10n.shuffle);
                        break;
                      default:
                        showCenterMessage(context, l10n.repeat);
                        break;
                    }
                    setState(() {});
                  },
                ),
                IconButton(
                  color: Colors.black,
                  onPressed: () {
                    scrollController.animateTo(
                      54.0 * audioHandler.currentIndex - 162,
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
              itemExtent: 54,
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
              onReorderStart: (_) {
                tryVibrate();
              },
              onReorderEnd: (_) {
                tryVibrate();
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
                  key: ValueKey(song),
                  contentPadding: EdgeInsets.fromLTRB(15, 0, 0, 0),
                  leading: CoverArtWidget(
                    size: 40,
                    borderRadius: 4,
                    song: song,
                  ),
                  title: ValueListenableBuilder(
                    valueListenable: currentSongNotifier,
                    builder: (_, currentSong, _) {
                      return Text(
                        getTitle(song),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: song == currentSong ? textColor : null,
                          fontWeight: song == currentSong
                              ? FontWeight.bold
                              : null,
                        ),
                      );
                    },
                  ),
                  subtitle: Text(
                    "${getArtist(song)} - ${getAlbum(song)}",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12),
                  ),
                  visualDensity: VisualDensity(vertical: -4),
                  onTap: () async {
                    audioHandler.currentIndex = index;
                    await audioHandler.load();
                    audioHandler.play();
                  },

                  trailing: IconButton(
                    onPressed: () async {
                      audioHandler.delete(index);
                      setState(() {});
                      if (index < audioHandler.currentIndex) {
                        audioHandler.currentIndex -= 1;
                      } else if (index == audioHandler.currentIndex) {
                        if (playQueue.isEmpty) {
                          while (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          await audioHandler.clear();
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
