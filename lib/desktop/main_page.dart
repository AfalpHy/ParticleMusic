import 'package:flutter/material.dart';
import 'package:particle_music/desktop/artist_album_plane.dart';
import 'package:particle_music/desktop/bottom_control.dart';
import 'package:particle_music/desktop/play_quee_page.dart';
import 'package:particle_music/desktop/sidebar.dart';
import 'package:particle_music/desktop/song_list_plane.dart';
import 'package:particle_music/desktop/lyrics_page.dart';
import 'package:particle_music/playlists.dart';
import 'package:smooth_corner/smooth_corner.dart';

class DesktopMainPage extends StatelessWidget {
  final ValueNotifier<Playlist?> currentPlaylistNotifier = ValueNotifier(null);

  final ValueNotifier<bool> displayLyricsPageNotifier = ValueNotifier(false);

  final ValueNotifier<bool> displayPlayQueuePageNotifier = ValueNotifier(false);

  // 0 library song, 1 artist plane, 2 album plane, 3 artist song list
  // 4 album song list, 5 playlist song list
  final ValueNotifier<int> displayWhichPlaneNotifier = ValueNotifier(0);

  DesktopMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    String? songListTitle;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Sidebar(
                    currentPlaylistNotifier: currentPlaylistNotifier,
                    displayWhichPlaneNotifier: displayWhichPlaneNotifier,
                  ),
                  ValueListenableBuilder(
                    valueListenable: displayWhichPlaneNotifier,
                    builder: (context, value, child) {
                      switch (value) {
                        case 0:
                          return SongListPlane();
                        case 1:
                          return ArtistAlbumPlane(
                            isArtist: true,
                            switchPlane: (title) {
                              displayWhichPlaneNotifier.value = 3;
                              songListTitle = title;
                            },
                          );
                        case 2:
                          return ArtistAlbumPlane(
                            isArtist: false,
                            switchPlane: (title) {
                              displayWhichPlaneNotifier.value = 4;
                              songListTitle = title;
                            },
                          );
                        case 3:
                          return SongListPlane(artist: songListTitle);
                        case 4:
                          return SongListPlane(album: songListTitle);
                        default:
                          return ValueListenableBuilder(
                            valueListenable: currentPlaylistNotifier,
                            builder: (context, playlist, child) {
                              return SongListPlane(
                                key: ValueKey(playlist),
                                playlist: playlist,
                              );
                            },
                          );
                      }
                    },
                  ),
                ],
              ),
            ),
            Material(
              child: BottomControl(
                displayLyricsPageNotifier: displayLyricsPageNotifier,
                displayPlayQueuePageNotifier: displayPlayQueuePageNotifier,
              ),
            ),
          ],
        ),

        LyricsPage(displayLyricsPageNotifier: displayLyricsPageNotifier),

        ValueListenableBuilder(
          valueListenable: displayPlayQueuePageNotifier,
          builder: (context, display, _) {
            if (display) {
              return GestureDetector(
                onTap: () {
                  displayPlayQueuePageNotifier.value = false;
                },
                child: Container(color: Colors.black.withAlpha(25)),
              );
            } else {
              return SizedBox.shrink();
            }
          },
        ),

        Positioned(
          top: 80,
          bottom: 100,
          right: 0,
          child: ValueListenableBuilder(
            valueListenable: displayPlayQueuePageNotifier,
            builder: (context, display, _) {
              return AnimatedSlide(
                offset: display ? Offset.zero : Offset(1, 0),
                duration: const Duration(milliseconds: 200),
                curve: Curves.linear,
                child: Material(
                  elevation: 5,
                  color: Colors.grey.shade50,
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(15),
                    ),
                  ),

                  child: SizedBox(
                    width: 350,
                    child: PlayQueuePage(
                      displayPlayQueuePageNotifier:
                          displayPlayQueuePageNotifier,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
