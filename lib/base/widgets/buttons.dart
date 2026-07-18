import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/widgets/play_queue_sheet.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/pages/play_queue_page.dart';
import 'package:smooth_corner/smooth_corner.dart';

Widget playModeButton(double? size, {Color? iconColor}) {
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

          showAnimationDialog(
            context: context,

            child: SizedBox(
              width: 300,
              height: isMobile ? 190 : 170,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: ValueListenableBuilder(
                  valueListenable: currentSongNotifier,
                  builder: (context, value, child) {
                    final iconColor = colorManager.getSpecificIconColor();
                    final textColor = colorManager.getSpecificTextColor();
                    return Column(
                      children: [
                        ListTile(
                          leading: ImageIcon(loopImage, color: iconColor),
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
                          leading: ImageIcon(shuffleImage, color: iconColor),

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
                          leading: ImageIcon(repeatImage, color: iconColor),

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
                    );
                  },
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
    autofocus: viewModeNotifier.value == .bigPicture,
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
            Navigator.push(
              context,
              PageRouteBuilder(
                opaque: false,
                barrierColor: Colors.black.withAlpha(25),
                barrierDismissible: true,
                pageBuilder: (_, _, _) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 75, bottom: 100),
                      child: ValueListenableBuilder(
                        valueListenable: currentSongNotifier,
                        builder: (context, value, child) {
                          return Material(
                            elevation: 1,
                            color: Color.alphaBlend(
                              colorManager.getSpecificBgColor(),
                              colorManager.getSpecificBgBaseColor(),
                            ),
                            shape: SmoothRectangleBorder(
                              smoothness: 1,
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(10),
                              ),
                            ),
                            clipBehavior: Clip.antiAliasWithSaveLayer,
                            child: SizedBox(
                              width: max(
                                350,
                                MediaQuery.widthOf(context) * 0.2,
                              ),
                              child: PlayQueuePage(),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                transitionsBuilder: (_, animation, _, child) {
                  return SlideTransition(
                    position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                        .animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: child,
                  );
                },
              ),
            );
          }
        },
      );
    },
  );
}
