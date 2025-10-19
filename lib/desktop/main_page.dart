import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/playlists.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:smooth_corner/smooth_corner.dart';

class DesktopMainPage extends StatelessWidget {
  final itemScrollController = ItemScrollController();

  final ValueNotifier<List<AudioMetadata>> currentSongListNotifier =
      ValueNotifier(librarySongs);

  final ValueNotifier<Playlist?> currentPlaylistNotifier = ValueNotifier(null);
  final ValueNotifier<double> sidebarWidthNotifier = ValueNotifier(200);

  DesktopMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                ValueListenableBuilder(
                  valueListenable: sidebarWidthNotifier,
                  builder: (context, width, child) {
                    return sidebar(width);
                  },
                ), // Drag handle
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      sidebarWidthNotifier.value = details.globalPosition.dx
                          .clamp(200, 600);
                    },

                    child: Container(width: 10, color: Colors.grey.shade100),
                  ),
                ),
                Container(color: Colors.white, width: 30),
                songList(),
              ],
            ),
          ),
          bottomControl(context),
        ],
      ),
    );
  }

  Widget sidebar(double width) {
    return Container(
      color: Colors.grey.shade100,
      width: width,
      child: Column(
        children: [
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
            onTap: () {
              currentSongListNotifier.value = librarySongs;
              currentPlaylistNotifier.value = null;
            },
          ),
          Divider(thickness: 0.5, height: 1, color: Colors.grey.shade300),

          Expanded(
            child: ValueListenableBuilder(
              valueListenable: playlistsManager.changeNotifier,
              builder: (context, _, _) {
                return ListView.builder(
                  itemCount: playlistsManager.length() + 1,
                  itemBuilder: (_, index) {
                    if (index < playlistsManager.length()) {
                      final playlist = playlistsManager.getPlaylistByIndex(
                        index,
                      );
                      return GestureDetector(
                        onSecondaryTapDown: (TapDownDetails details) {
                          showMenu(
                            color: Colors.white,
                            context: context,
                            position: RelativeRect.fromLTRB(
                              details.globalPosition.dx,
                              details.globalPosition.dy,
                              details.globalPosition.dx,
                              details.globalPosition.dy,
                            ),
                            items: [
                              PopupMenuItem(
                                onTap: () async {
                                  if (await showConfirmDialog(
                                    context,
                                    'Delete Action',
                                  )) {
                                    playlistsManager.deletePlaylist(index);
                                  }
                                },
                                child: ListTile(
                                  leading: ImageIcon(
                                    AssetImage("assets/images/delete.png"),
                                  ),
                                  title: Text('Delete'),
                                ),
                              ),
                            ],
                          );
                        },
                        child: ListTile(
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -2,
                          ),

                          leading: ValueListenableBuilder(
                            valueListenable: playlist.changeNotifier,
                            builder: (_, _, _) {
                              return CoverArtWidget(
                                size: 30,
                                borderRadius: 3,
                                source: playlist.songs.isNotEmpty
                                    ? getCoverArt(playlist.songs.first)
                                    : null,
                              );
                            },
                          ),
                          title: Text(
                            playlist.name,
                            overflow: TextOverflow.ellipsis,
                          ),

                          onTap: () {
                            currentPlaylistNotifier.value = playlist;
                            currentSongListNotifier.value = playlist.songs;
                          },
                        ),
                      );
                    }

                    return ListTile(
                      leading: SmoothClipRRect(
                        smoothness: 1,
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          color: const Color.fromARGB(255, 245, 235, 245),
                          child: ImageIcon(
                            AssetImage("assets/images/add.png"),
                            size: 30,
                          ),
                        ),
                      ),
                      title: Text('Create Playlist'),
                      onTap: () {
                        showCreatePlaylistSheet(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget songList() {
    return Expanded(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            ValueListenableBuilder(
              valueListenable: currentPlaylistNotifier,
              builder: (_, playlist, _) {
                if (playlist == null) {
                  return SizedBox.shrink();
                } else {
                  return Column(
                    children: [
                      SizedBox(height: 30),
                      Row(
                        children: [
                          Material(
                            elevation: 5,
                            shape: SmoothRectangleBorder(
                              smoothness: 1,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: CoverArtWidget(
                              size: 200,
                              borderRadius: 15,
                              source: playlist.songs.isNotEmpty
                                  ? getCoverArt(playlist.songs.first)
                                  : null,
                            ),
                          ),

                          Expanded(
                            child: ListTile(
                              title: AutoSizeText(
                                playlist.name,
                                maxLines: 1,
                                minFontSize: 20,
                                maxFontSize: 20,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text("${playlist.songs.length} songs"),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 30),
                    ],
                  );
                }
              },
            ),

            SizedBox(
              height: 50,
              child: Row(
                spacing: 20,
                children: [
                  Expanded(
                    child: SizedBox(
                      child: Text('Title', overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: Text('Album', overflow: TextOverflow.ellipsis),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text('Duration', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ValueListenableBuilder(
                valueListenable: currentSongListNotifier,
                builder: (context, currentSongList, child) {
                  return ScrollablePositionedList.builder(
                    itemScrollController: itemScrollController,
                    itemCount: currentSongList.length,
                    itemBuilder: (context, index) {
                      final song = currentSongList[index];
                      return Row(
                        spacing: 20,
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 0),
                              visualDensity: const VisualDensity(
                                horizontal: 0,
                                vertical: -4,
                              ),
                              leading: CoverArtWidget(
                                size: 40,
                                borderRadius: 4,
                                source: getCoverArt(song),
                              ),
                              title: ValueListenableBuilder(
                                valueListenable: currentSongNotifier,
                                builder: (_, currentSong, _) {
                                  return Text(
                                    getTitle(song),
                                    overflow: TextOverflow.ellipsis,
                                    style: song == currentSong
                                        ? TextStyle(
                                            color: Color.fromARGB(
                                              255,
                                              75,
                                              200,
                                              200,
                                            ),
                                            fontWeight: FontWeight.bold,
                                          )
                                        : null,
                                  );
                                },
                              ),
                              subtitle: Text(getArtist(song)),
                              onTap: () async {
                                audioHandler.currentIndex = index;
                                playQueue = List.from(currentSongList);
                                if (playModeNotifier.value == 1 ||
                                    (playModeNotifier.value == 2 &&
                                        audioHandler.tmpPlayMode == 1)) {
                                  audioHandler.shuffle();
                                }
                                await audioHandler.load();
                                await audioHandler.play();
                              },
                            ),
                          ),
                          SizedBox(
                            width: 300,
                            child: Text(
                              getAlbum(song),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text(
                              '${getDuration(song).inMinutes.toString().padLeft(2, '0')}:${(getDuration(song).inSeconds % 60).toString().padLeft(2, '0')}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget bottomControl(BuildContext context) {
    final volumeNotifier = ValueNotifier(1.0);
    return Container(
      color: Colors.grey.shade50,
      height: 75,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 300,
              child: ValueListenableBuilder(
                valueListenable: currentSongNotifier,
                builder: (_, currentSong, _) {
                  return ListTile(
                    leading: CoverArtWidget(
                      size: 50,
                      borderRadius: 5,
                      source: getCoverArt(currentSong),
                    ),
                    title: Text(
                      getTitle(currentSong),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: currentSong != null
                        ? Text(
                            "${getArtist(currentSong)} - ${getAlbum(currentSong)}",
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                  );
                },
              ),
            ),
          ),

          Center(
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
                  },
                ),
                Spacer(),
              ],
            ),
          ),
          Row(
            children: [
              Spacer(),
              SizedBox(width: 10, child: Icon(Icons.volume_down_rounded)),
              SizedBox(
                width: 200,
                child: ValueListenableBuilder(
                  valueListenable: volumeNotifier,
                  builder: (context, value, child) {
                    return SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 1.5, // thinner track
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: 2.5,
                        ), // smaller thumb
                        overlayColor: Colors.transparent,
                        activeTrackColor: Colors.black,
                        inactiveTrackColor: Colors.black54,
                        thumbColor: Colors.black,
                      ),
                      child: Slider(
                        value: value,
                        min: 0,
                        max: 1,
                        onChanged: (value) {
                          volumeNotifier.value = value;
                          audioHandler.setVolume(value);
                        },
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: 50),
            ],
          ),
        ],
      ),
    );
  }
}
