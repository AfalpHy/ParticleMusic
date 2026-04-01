import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/play_queue_sheet.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/utils.dart';

Widget playModeButton(double size, {Color? iconColor}) {
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
