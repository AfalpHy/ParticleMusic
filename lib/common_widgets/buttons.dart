import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/play_queue_sheet.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/utils.dart';

Widget playModeButton(double? size, {Color? textColor, Color? iconColor}) {
  return ValueListenableBuilder(
    valueListenable: playModeNotifier,
    builder: (context, playMode, _) {
      final l10n = AppLocalizations.of(context);

      return IconButton(
        color: iconColor,
        icon: ImageIcon(
          playMode == 0
              ? loopImage
              : playMode == 1
              ? shuffleImage
              : repeatImage,
          size: size,
        ),
        onPressed: () {
          showAnimationDialog(
            context: context,

            child: SizedBox(
              width: 300,
              height: 300,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: ListView(
                  children: [
                    ListTile(
                      title: Text(
                        l10n.loop,
                        style: TextStyle(color: textColor),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        audioHandler.changePlayMode(0);
                      },
                      trailing: playModeNotifier.value == 0
                          ? Icon(Icons.check, color: iconColor)
                          : null,
                    ),
                    ListTile(
                      title: Text(
                        l10n.shuffle,
                        style: TextStyle(color: textColor),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        audioHandler.changePlayMode(1);
                      },
                      trailing: playModeNotifier.value == 1
                          ? Icon(Icons.check, color: iconColor)
                          : null,
                    ),
                    ListTile(
                      title: Text(
                        l10n.repeat,
                        style: TextStyle(color: textColor),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        audioHandler.changePlayMode(2);
                      },
                      trailing: playModeNotifier.value == 2
                          ? Icon(Icons.check, color: iconColor)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget rewindButton(double size, {Color? iconColor}) {
  return IconButton(
    color: iconColor,
    icon: ImageIcon(rewindImage, size: size),
    onPressed: () {
      if (playQueue.isEmpty) {
        return;
      }
      if (audioHandler.getPosition() > Duration(seconds: 15)) {
        audioHandler.seek(audioHandler.getPosition() - Duration(seconds: 15));
      } else {
        audioHandler.seek(Duration.zero);
      }
    },
  );
}

Widget skip2PreviousButton(double size, {Color? iconColor}) {
  return IconButton(
    color: iconColor,
    icon: ImageIcon(previousButtonImage, size: size),
    onPressed: () {
      audioHandler.skipToPrevious();
    },
  );
}

Widget playOrPauseButton(double size, {Color? iconColor}) {
  return IconButton(
    color: iconColor,
    icon: ValueListenableBuilder(
      valueListenable: isPlayingNotifier,
      builder: (_, isPlaying, _) {
        return Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: size,
        );
      },
    ),
    onPressed: () {
      if (playQueue.isEmpty) {
        return;
      }
      audioHandler.togglePlay();
    },
  );
}

Widget forwardButton(double size, {Color? iconColor}) {
  return IconButton(
    color: iconColor,
    icon: ImageIcon(forwardImage, size: size),
    onPressed: () {
      if (playQueue.isEmpty) {
        return;
      }
      if (audioHandler.getPosition() + Duration(seconds: 15) <
          currentSongNotifier.value!.duration!) {
        audioHandler.seek(audioHandler.getPosition() + Duration(seconds: 15));
      } else {
        audioHandler.seek(currentSongNotifier.value!.duration!);
      }
    },
  );
}

Widget skip2NextButton(double size, {Color? iconColor}) {
  return IconButton(
    color: iconColor,
    icon: ImageIcon(nextButtonImage, size: size),
    onPressed: () {
      audioHandler.skipToNext();
    },
  );
}

Widget showPlayQueueButton(double size, {Color? iconColor}) {
  return Builder(
    builder: (context) {
      return IconButton(
        color: iconColor,
        icon: ImageIcon(playQueueImage, size: size),
        onPressed: () {
          if (playQueue.isEmpty) {
            return;
          }
          if (isMobile) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) {
                return PlayQueueSheet();
              },
            );
          } else {
            displayPlayQueuePageNotifier.value = true;
          }
        },
      );
    },
  );
}
