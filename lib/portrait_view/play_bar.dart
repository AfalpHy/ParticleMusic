import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common_widgets/my_auto_size_text.dart';
import 'package:particle_music/common_widgets/play_queue_sheet.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

class PlayBar extends StatelessWidget {
  const PlayBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (_, currentSong, _) {
        if (currentSong == null) return const SizedBox.shrink();

        return SizedBox(
          height: 50,
          child: Material(
            shape: SmoothRectangleBorder(
              smoothness: 1,
              borderRadius: BorderRadius.circular(
                25,
              ), // rounded half-circle ends
            ),
            color: enableCustomColorNotifier.value
                ? Colors.transparent
                : backgroundBaseColor.withAlpha(180),
            clipBehavior: .antiAlias,
            child: Container(
              color: playBarColor,
              child: InkWell(
                onTap: () {
                  displayLyricsPageNotifier.value = true;
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
                        textStyle: TextStyle(fontSize: 16, color: textColor),
                      ),
                    ),

                    // Play/Pause Button
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: ValueListenableBuilder(
                          valueListenable: isPlayingNotifier,
                          builder: (_, isPlaying, _) {
                            return ImageIcon(
                              isPlaying
                                  ? pauseCircleImage
                                  : playCircleFillImage,
                              color: iconColor,
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
                          color: iconColor,
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
