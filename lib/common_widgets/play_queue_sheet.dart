import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/buttons.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common_widgets/my_sheet.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/utils.dart';

class PlayQueueSheet extends StatefulWidget {
  const PlayQueueSheet({super.key});

  @override
  State<StatefulWidget> createState() => PlayQueueSheetState();
}

class PlayQueueSheetState extends State<PlayQueueSheet> {
  final scrollController = ScrollController();

  void jumpToCurrentSong() {
    final position = scrollController.position;
    final maxScrollExtent = position.maxScrollExtent;
    final minScrollExtent = position.minScrollExtent;
    scrollController.jumpTo(
      (54.0 * audioHandler.currentIndex).clamp(
        minScrollExtent,
        maxScrollExtent,
      ),
    );
  }

  void updateQueue() {
    jumpToCurrentSong();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      jumpToCurrentSong();
    });
    playModeNotifier.addListener(updateQueue);
  }

  @override
  void dispose() {
    playModeNotifier.removeListener(updateQueue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final specificTextColor = colorManager.getSpecificTextColor();
    final specificIconColor = colorManager.getSpecificIconColor();
    final specificHighlightText = colorManager.getSpecificHighlightTextColor();

    return MySheet(
      Column(
        children: [
          // Optional drag handle
          Container(
            margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
            width: 50,
            height: 3,
            decoration: BoxDecoration(
              color: specificIconColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          SizedBox(
            child: Row(
              children: [
                SizedBox(width: 15),
                Text(
                  l10n.playQueue,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: specificTextColor,
                  ),
                ),
                Spacer(),

                IconButton(
                  autofocus: isTV ? true : false,
                  color: specificIconColor,
                  onPressed: () {
                    audioHandler.reversePlayQueue();
                    updateQueue();
                  },
                  icon: ImageIcon(reverseImage),
                ),

                playModeButton(
                  null,
                  textColor: specificTextColor,
                  iconColor: specificIconColor,
                ),

                IconButton(
                  color: specificIconColor,
                  onPressed: () {
                    final position = scrollController.position;
                    final maxScrollExtent = position.maxScrollExtent;
                    final minScrollExtent = position.minScrollExtent;
                    scrollController.animateTo(
                      (54.0 * audioHandler.currentIndex).clamp(
                        minScrollExtent,
                        maxScrollExtent,
                      ),
                      duration: Duration(milliseconds: 300),
                      curve: Curves.linear,
                    );
                  },
                  icon: ImageIcon(location),
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
                  icon: const ImageIcon(deleteImage),
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
                audioHandler.saveAllStates();
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
                      color: Colors.transparent,
                      child: child,
                    );
                  },
              itemCount: playQueue.length,
              itemBuilder: (_, index) {
                final song = playQueue[index];
                final removeNode = FocusNode();

                return MediaQuery.removePadding(
                  key: ValueKey(song),
                  context: context,
                  removeLeft: true, // for mobile
                  removeRight: true,
                  child: Focus(
                    canRequestFocus: false,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == .arrowRight) {
                        removeNode.requestFocus();
                        return .handled;
                      }
                      return .ignored;
                    },
                    child: ListTile(
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
                              fontWeight: song == currentSong
                                  ? FontWeight.bold
                                  : null,
                              color: song == currentSong
                                  ? specificHighlightText
                                  : specificTextColor,
                            ),
                          );
                        },
                      ),
                      subtitle: Text(
                        "${getArtist(song)} - ${getAlbum(song)}",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: specificTextColor,
                        ),
                      ),
                      visualDensity: VisualDensity(vertical: -4),
                      onTap: () async {
                        audioHandler.currentIndex = index;
                        await audioHandler.load();
                        audioHandler.play();
                      },

                      trailing: IconButton(
                        focusNode: removeNode,
                        color: specificIconColor,

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
                          audioHandler.saveAllStates();
                        },
                        icon: Icon(Icons.clear_rounded, size: 20),
                      ),
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
