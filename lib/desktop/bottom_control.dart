import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/full_width_track_shape.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/common_widgets/seekbar.dart';
import 'package:particle_music/utils.dart';

class BottomControl extends StatelessWidget {
  const BottomControl({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bottomColor,
      child: SizedBox(
        height: 75,
        child: Stack(
          children: [currentSongTile(), playControls(context), otherControls()],
        ),
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
          builder: (context, currentSong, _) {
            return Theme(
              data: Theme.of(context).copyWith(
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                hoverColor: Colors.transparent,
              ),
              child: ListTile(
                leading: CoverArtWidget(
                  size: 50,
                  borderRadius: 5,
                  song: currentSong,
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
                  if (playQueue.isEmpty) {
                    return;
                  }
                  displayLyricsPageNotifier.value = true;
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget playControls(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
                            showCenterMessage(context, l10n.loop);
                            break;
                          default:
                            showCenterMessage(context, l10n.shuffle);
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
                          showCenterMessage(context, l10n.loop);
                          break;
                        case 1:
                          showCenterMessage(context, l10n.shuffle);
                          break;
                        default:
                          showCenterMessage(context, l10n.repeat);
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
                  audioHandler.skipToNext();
                },
              ),
              IconButton(
                color: Colors.black,
                icon: const ImageIcon(playQueueImage, size: 25),
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
                child: ValueListenableBuilder(
                  valueListenable: currentSongNotifier,
                  builder: (_, _, _) {
                    return SeekBar(widgetHeight: 20, seekBarHeight: 10);
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

  Widget otherControls() {
    return Row(
      children: [
        Spacer(),
        IconButton(
          onPressed: () async {
            if (lyricsWindowVisible) {
              await lyricsWindowController!.hide();
            } else {
              await updateDesktopLyrics();
              await lyricsWindowController!.show();
            }
            lyricsWindowVisible = !lyricsWindowVisible;
          },
          icon: const ImageIcon(
            desktopLyricsImage,
            size: 25,
            color: Colors.black,
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const ImageIcon(speakerImage, size: 25, color: Colors.black),
        ),
        Center(
          child: SizedBox(
            height: 20,
            width: 120,
            child: ValueListenableBuilder(
              valueListenable: volumeNotifier,
              builder: (context, value, child) {
                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    trackShape: const FullWidthTrackShape(),
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 0),
                    overlayColor: Colors.transparent,
                    activeTrackColor: Colors.black,
                    inactiveTrackColor: Colors.black12,
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
                    onChangeEnd: (value) {
                      audioHandler.savePlayState();
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
