import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/mobile/play_queue_sheet.dart';
import 'package:particle_music/song_list_tile.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class DesktopMainPage extends StatelessWidget {
  final itemScrollController = ItemScrollController();

  DesktopMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  color: Colors.grey.shade100,
                  width: 200,
                  child: ListView(
                    physics: ClampingScrollPhysics(),
                    children: [
                      ListTile(
                        leading: const ImageIcon(
                          AssetImage("assets/images/playlists.png"),
                          size: 30,
                          color: mainColor,
                        ),
                        title: Text('Playlists'),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: const ImageIcon(
                          AssetImage("assets/images/artist.png"),
                          size: 30,
                          color: mainColor,
                        ),
                        title: Text('Artists'),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: const ImageIcon(
                          AssetImage("assets/images/album.png"),
                          size: 30,
                          color: mainColor,
                        ),
                        title: Text('Albums'),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: const ImageIcon(
                          AssetImage("assets/images/songs.png"),
                          size: 30,
                          color: mainColor,
                        ),
                        title: Text('Songs'),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: ScrollablePositionedList.builder(
                      itemScrollController: itemScrollController,
                      itemCount: librarySongs.length,
                      itemBuilder: (context, index) {
                        return SongListTile(index: index, source: librarySongs);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.grey.shade50,
            height: 75,
            child: Row(
              children: [
                Spacer(),
                ValueListenableBuilder(
                  valueListenable: playModeNotifier,
                  builder: (_, playMode, _) {
                    return IconButton(
                      color: Colors.black,
                      icon: ImageIcon(
                        playMode == 0
                            ? AssetImage("assets/images/loop.png")
                            : playMode == 1
                            ? AssetImage("assets/images/shuffle.png")
                            : AssetImage("assets/images/repeat.png"),
                        size: 35,
                      ),
                      onPressed: () {
                        if (playQueue.isEmpty) {
                          return;
                        }
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
                        }
                      },
                      onLongPress: () {
                        if (playQueue.isEmpty) {
                          return;
                        }
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
                      },
                    );
                  },
                ),

                IconButton(
                  color: Colors.black,
                  icon: const ImageIcon(
                    AssetImage("assets/images/previous_button.png"),
                    size: 35,
                  ),
                  onPressed: () {
                    if (playQueue.isEmpty) {
                      return;
                    }
                    audioHandler.skipToPrevious();
                  },
                ),
                IconButton(
                  color: Colors.black,
                  icon: ValueListenableBuilder(
                    valueListenable: isPlayingNotifier,
                    builder: (_, isPlaying, _) {
                      return Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 48,
                      );
                    },
                  ),
                  onPressed: () {
                    if (playQueue.isEmpty) {
                      return;
                    }
                    audioHandler.togglePlay();
                  },
                ),
                IconButton(
                  color: Colors.black,
                  icon: const ImageIcon(
                    AssetImage("assets/images/next_button.png"),
                    size: 35,
                  ),
                  onPressed: () {
                    if (playQueue.isEmpty) {
                      return;
                    }

                    audioHandler.skipToNext();
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.playlist_play_rounded,
                    size: 35,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    if (playQueue.isEmpty) {
                      return;
                    }
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) {
                        return PlayQueueSheet();
                      },
                    );
                  },
                ),
                Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
