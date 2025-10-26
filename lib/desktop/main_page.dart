import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/desktop/bottom_control.dart';
import 'package:particle_music/desktop/play_quee_page.dart';
import 'package:particle_music/desktop/sidebar.dart';
import 'package:particle_music/desktop/song_list_plane.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/desktop/lyrics_page.dart';
import 'package:particle_music/playlists.dart';
import 'package:smooth_corner/smooth_corner.dart';

class DesktopMainPage extends StatelessWidget {
  final controller = ScrollController();

  final ValueNotifier<List<AudioMetadata>> currentSongListNotifier =
      ValueNotifier(librarySongs);

  final ValueNotifier<Playlist?> currentPlaylistNotifier = ValueNotifier(null);

  final ValueNotifier<bool> displayLyricsPageNotifier = ValueNotifier(false);

  final ValueNotifier<bool> displayPlayQueuePageNotifier = ValueNotifier(false);

  DesktopMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Sidebar(
                    currentSongListNotifier: currentSongListNotifier,
                    currentPlaylistNotifier: currentPlaylistNotifier,
                  ),
                  SongListPlane(
                    currentSongListNotifier: currentSongListNotifier,
                    currentPlaylistNotifier: currentPlaylistNotifier,
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
