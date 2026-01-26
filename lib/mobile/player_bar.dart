import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/mobile/pages/lyrics_page.dart';
import 'package:particle_music/mobile/play_queue_sheet.dart';
import 'package:smooth_corner/smooth_corner.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (_, currentSong, _) {
        if (currentSong == null) return const SizedBox.shrink();

        return SizedBox(
          height: 50,
          child: SmoothClipRRect(
            smoothness: 1,
            borderRadius: BorderRadius.circular(25), // rounded half-circle ends

            child: Material(
              color: Colors.white70,
              child: InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) {
                      return DraggableScrollableSheet(
                        initialChildSize: 1.0,
                        builder: (_, _) => LyricsPage(),
                      );
                    },
                  );
                },

                child: Row(
                  children: [
                    const SizedBox(width: 15),
                    CoverArtWidget(
                      size: 35,
                      borderRadius: 3,
                      song: currentSong,
                    ),

                    const SizedBox(width: 10),
                    Expanded(
                      child: MyAutoSizeText(
                        "${getTitle(currentSong)} - ${getArtist(currentSong)}",
                        key: ValueKey(currentSong),
                        maxLines: 1,
                        textStyle: TextStyle(fontSize: 16),
                      ),
                    ),

                    // Play/Pause Button
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: ValueListenableBuilder(
                          valueListenable: isPlayingNotifier,
                          builder: (_, isPlaying, _) {
                            return isPlaying
                                ? const ImageIcon(
                                    pauseCircleImage,
                                    color: Colors.black,
                                    size: 25,
                                  )
                                : const ImageIcon(
                                    playCircleFillImage,
                                    color: Colors.black,
                                    size: 25,
                                  );
                          },
                        ),

                        onPressed: () {
                          tryVibrate();
                          audioHandler.togglePlay();
                        },
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: Icon(
                          Icons.playlist_play_rounded,
                          color: Colors.black,
                          size: 30,
                        ),
                        onPressed: () {
                          tryVibrate();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) {
                              return PlayQueueSheet();
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 15),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
