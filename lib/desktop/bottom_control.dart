import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/seekbar.dart';

class BottomControl extends StatelessWidget {
  final ValueNotifier<bool> displayLyricsPageNotifier;

  final ValueNotifier<bool> displayPlayQueuePageNotifier;
  const BottomControl({
    super.key,
    required this.displayLyricsPageNotifier,
    required this.displayPlayQueuePageNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      height: 75,
      child: Stack(
        children: [currentSongTile(), playControls(context), volumeControl()],
      ),
    );
  }

  Widget currentSongTile() {
    return Align(
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
    );
  }

  Widget playControls(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
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
                      size: 25,
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
                icon: const ImageIcon(previousButtonImage, size: 25),
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
                      size: 35,
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
                icon: const ImageIcon(nextButtonImage, size: 25),
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
                  size: 25,
                  color: Colors.black,
                ),
                onPressed: () {
                  if (playQueue.isEmpty) {
                    return;
                  }
                  displayPlayQueuePageNotifier.value = true;
                },
              ),
              Spacer(),
            ],
          ),
        ),
        Positioned(
          top: 35,
          bottom: 0,
          left: 0,
          right: 0,
          child: Row(
            children: [
              Spacer(),
              SizedBox(
                width: 400,
                height: 20,
                child: ValueListenableBuilder(
                  valueListenable: currentSongNotifier,
                  builder: (_, _, _) {
                    return SeekBar();
                  },
                ),
              ),

              Spacer(),
            ],
          ),
        ),
      ],
    );
  }

  Widget volumeControl() {
    final volumeNotifier = ValueNotifier(audioHandler.getVolume());

    return Row(
      children: [
        Spacer(),
        SizedBox(width: 10, child: Icon(Icons.volume_down_rounded)),
        Center(
          child: SizedBox(
            height: 20,
            width: 175,
            child: ValueListenableBuilder(
              valueListenable: volumeNotifier,
              builder: (context, value, child) {
                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 0.3, // thinner track
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: 1,
                    ), // smaller thumb
                    overlayColor: Colors.transparent,
                    activeTrackColor: Colors.black,
                    inactiveTrackColor: Colors.black,
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
        ),
        SizedBox(width: 30),
      ],
    );
  }
}
