import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/lyrics.dart';
import 'package:particle_music/playlists.dart';
import 'package:smooth_corner/smooth_corner.dart';

class DesktopMainPage extends StatelessWidget {
  final controller = ScrollController();

  final ValueNotifier<List<AudioMetadata>> currentSongListNotifier =
      ValueNotifier(librarySongs);

  final ValueNotifier<Playlist?> currentPlaylistNotifier = ValueNotifier(null);

  final ValueNotifier<bool> displayLyricsPageNotifier = ValueNotifier(false);

  DesktopMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(child: Row(children: [sidebar(), songList()])),
            Material(child: bottomControl(context)),
          ],
        ),
        ValueListenableBuilder(
          valueListenable: displayLyricsPageNotifier,
          builder: (context, display, _) {
            return AnimatedSlide(
              offset: display ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.linear,
              child: Material(
                color: coverArtAverageColor,
                child: ValueListenableBuilder(
                  valueListenable: currentSongNotifier,
                  builder: (context, currentSong, child) {
                    return Row(
                      children: [
                        SizedBox(width: MediaQuery.widthOf(context) * 0.15),
                        InkWell(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          onTap: () {
                            displayLyricsPageNotifier.value = false;
                          },
                          child: CoverArtWidget(
                            size: MediaQuery.widthOf(context) * 0.3,
                            borderRadius: MediaQuery.widthOf(context) * 0.03,
                            source: getCoverArt(currentSong),
                          ),
                        ),
                        SizedBox(width: MediaQuery.widthOf(context) * 0.05),
                        SizedBox(
                          width: MediaQuery.widthOf(context) * 0.4,
                          child: ShaderMask(
                            shaderCallback: (rect) {
                              return LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent, // fade out at top
                                  Colors.black, // fully visible
                                  Colors.black, // fully visible
                                  Colors.transparent, // fade out at bottom
                                ],
                                stops: [
                                  0.0,
                                  0.1,
                                  0.8,
                                  1.0,
                                ], // adjust fade height
                              ).createShader(rect);
                            },
                            blendMode: BlendMode.dstIn,
                            // use key to force update
                            child: LyricsListView(
                              key: ValueKey(currentSong),
                              expanded: false,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget wrapWithPSM({
    required Color color,
    required EdgeInsets padding,
    required double radius,
    required Widget child,
  }) {
    return Padding(
      padding: padding,
      child: SmoothClipRRect(
        smoothness: 1,
        borderRadius: BorderRadius.circular(radius),
        child: Material(color: Colors.grey.shade100, child: child),
      ),
    );
  }

  Widget sidebar() {
    return Material(
      color: Colors.grey.shade100,
      child: SizedBox(
        width: 200,
        child: Column(
          children: [
            SizedBox(height: 10),

            wrapWithPSM(
              color: Colors.grey.shade100,
              padding: EdgeInsets.symmetric(horizontal: 10),
              radius: 10,
              child: ListTile(
                leading: const ImageIcon(
                  artistImage,
                  size: 25,
                  color: mainColor,
                ),
                title: Text('Artists', style: TextStyle(fontSize: 15)),
                visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                onTap: () {},
              ),
            ),
            wrapWithPSM(
              color: Colors.grey.shade100,
              padding: EdgeInsets.symmetric(horizontal: 10),
              radius: 10,
              child: ListTile(
                leading: const ImageIcon(
                  albumImage,
                  size: 25,
                  color: mainColor,
                ),
                title: Text('Albums', style: TextStyle(fontSize: 15)),
                visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                onTap: () {},
              ),
            ),
            wrapWithPSM(
              color: Colors.grey.shade100,
              padding: EdgeInsets.symmetric(horizontal: 10),
              radius: 10,
              child: ListTile(
                leading: const ImageIcon(
                  songsImage,
                  size: 25,
                  color: mainColor,
                ),
                title: Text('Songs', style: TextStyle(fontSize: 15)),
                visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                onTap: () {
                  currentSongListNotifier.value = librarySongs;
                  currentPlaylistNotifier.value = null;
                },
              ),
            ),
            SizedBox(height: 10),
            Divider(thickness: 0.5, height: 1, color: Colors.grey.shade300),
            SizedBox(height: 10),

            Expanded(
              child: ValueListenableBuilder(
                valueListenable: playlistsManager.changeNotifier,
                builder: (context, _, _) {
                  return ListView.builder(
                    itemCount: playlistsManager.length(),
                    itemBuilder: (_, index) {
                      final playlist = playlistsManager.getPlaylistByIndex(
                        index,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: SmoothClipRRect(
                          smoothness: 1,
                          borderRadius: BorderRadius.circular(10),
                          child: Material(
                            color: Colors.grey.shade100,
                            child: GestureDetector(
                              onSecondaryTapDown: (TapDownDetails details) {},
                              child: ListTile(
                                visualDensity: const VisualDensity(
                                  horizontal: 0,
                                  vertical: -3,
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
                                  style: TextStyle(fontSize: 14),
                                ),

                                onTap: () {
                                  currentPlaylistNotifier.value = playlist;
                                  currentSongListNotifier.value =
                                      playlist.songs;
                                },
                              ),
                            ),
                          ),
                        ),
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

  Widget songList() {
    return Expanded(
      child: Material(
        color: Colors.white,
        child: Column(
          children: [
            ValueListenableBuilder(
              valueListenable: currentPlaylistNotifier,
              builder: (context, playlist, _) {
                if (playlist == null) {
                  return SizedBox.shrink();
                } else {
                  return Column(
                    children: [
                      SizedBox(height: 30),
                      Row(
                        children: [
                          SizedBox(width: 30),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Row(
                  children: [
                    SizedBox(width: 60, child: Center(child: Text('#'))),
                    Expanded(
                      child: SizedBox(
                        child: Text('Title', overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    SizedBox(width: 30),

                    SizedBox(
                      width: 200,
                      child: Text('Album', overflow: TextOverflow.ellipsis),
                    ),
                    SizedBox(width: 30),

                    SizedBox(
                      width: 100,
                      child: Text('Duration', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: ValueListenableBuilder(
                valueListenable: currentSongListNotifier,
                builder: (context, currentSongList, child) {
                  return ListView.builder(
                    controller: controller,
                    prototypeItem: ListTile(
                      contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 0),
                      visualDensity: const VisualDensity(
                        horizontal: 0,
                        vertical: -4,
                      ),
                      leading: CoverArtWidget(
                        size: 40,
                        borderRadius: 4,
                        source: null,
                      ),
                      title: Text('title'),
                      subtitle: Text('subtitle'),
                    ),
                    itemCount: currentSongList.length,
                    itemBuilder: (context, index) {
                      final song = currentSongList[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: SmoothClipRRect(
                          smoothness: 1,
                          borderRadius: BorderRadius.circular(15),
                          child: Material(
                            color: Colors.white,
                            child: InkWell(
                              onDoubleTap: () async {
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

                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 60,
                                    child: Center(
                                      child: Text(
                                        (index + 1).toString(),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: ListTile(
                                      contentPadding: EdgeInsets.fromLTRB(
                                        0,
                                        0,
                                        0,
                                        0,
                                      ),
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
                                                    fontSize: 15,
                                                  )
                                                : TextStyle(fontSize: 15),
                                          );
                                        },
                                      ),
                                      subtitle: Text(
                                        getArtist(song),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 30),
                                  SizedBox(
                                    width: 200,
                                    child: Text(
                                      getAlbum(song),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 30),

                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      '${getDuration(song).inMinutes.toString().padLeft(2, '0')}:${(getDuration(song).inSeconds % 60).toString().padLeft(2, '0')}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
                    onTap: () {
                      displayLyricsPageNotifier.value = true;
                    },
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
                            ? loopImage
                            : playMode == 1
                            ? shuffleImage
                            : repeatImage,
                        size: 30,
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
                  icon: const ImageIcon(previousButtonImage, size: 30),
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
                        size: 45,
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
                  icon: const ImageIcon(nextButtonImage, size: 30),
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
                    size: 30,
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
                width: 175,
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
              SizedBox(width: 30),
            ],
          ),
        ],
      ),
    );
  }
}
