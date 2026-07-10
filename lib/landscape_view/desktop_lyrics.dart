import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';

import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/lyric.dart';
import 'package:sylvakru/base/widgets/lyric_list_view.dart';
import 'package:sylvakru/base/extensions/window_controller_extension.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:window_manager/window_manager.dart';

// Null until [initDesktopLyrics] has successfully created the secondary
// window. Kept nullable rather than late so a failed/unsupported
// creation (e.g. sandboxed Linux environments without multi-window
// support) degrades to "feature silently unavailable" instead of a
// startup crash.
WindowController? lyricsWindowController;
bool lyricsWindowVisible = false;

Duration desktopLyricsCurrentPosition = Duration.zero;

LyricLine? currentLyricLine;
bool currentLyricLineIsKaraoke = false;
final updateDesktopLyricsNotifier = ValueNotifier(0);

Future<void> initDesktopLyrics() async {
  try {
    lyricsWindowController = await WindowController.create(
      WindowConfiguration(hiddenAtLaunch: true, arguments: 'desktop_lyrics'),
    );
  } catch (e) {
    // Desktop lyrics is a nice-to-have, not core playback: never let its
    // setup take the whole app down with it.
    logger.output('failed to create desktop lyrics window: $e');
    lyricsWindowController = null;
  }
}

class DesktopLyrics extends StatelessWidget {
  final ValueNotifier<bool> _isTransparentNotifier = ValueNotifier(false);

  DesktopLyrics({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: Platform.isWindows
          ? ThemeData(fontFamily: 'Microsoft YaHei')
          : null,

      home: ValueListenableBuilder(
        valueListenable: _isTransparentNotifier,
        builder: (context, isTransparent, child) {
          bool isDragging = false;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (details) async {
              isDragging = true;
              await windowManager.startDragging();
              isDragging = false;
            },
            child: MouseRegion(
              onEnter: (_) {
                _isTransparentNotifier.value = false;
              },
              onExit: (_) {
                if (isDragging) {
                  return;
                }
                _isTransparentNotifier.value = true;
              },
              child: Material(
                color: isTransparent ? Colors.transparent : Colors.black45,
                shape: SmoothRectangleBorder(
                  smoothness: 1,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 50,
                        child: isTransparent ? null : controlsRow(),
                      ),
                      content(),
                      Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget content() {
    return ValueListenableBuilder(
      valueListenable: updateDesktopLyricsNotifier,
      builder: (context, value, child) {
        if (currentLyricLine == null) {
          return Text(
            'Sylvakru',
            style: TextStyle(
              fontSize: isMobile ? 20 : 30,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 1,
                  color: Colors.black87,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: .center,
          children: [
            if (currentLyricLineIsKaraoke)
              ValueListenableBuilder(
                valueListenable: updateLyricsNotifier,
                builder: (context, value, child) {
                  return KaraokeText(
                    key: UniqueKey(),
                    line: currentLyricLine!,
                    position: desktopLyricsCurrentPosition,
                    fontSize: isMobile ? 20 : 30,
                    expanded: false,
                    isDesktopLyrics: true,
                  );
                },
              )
            else
              Text(
                currentLyricLine!.text,

                style: TextStyle(
                  fontSize: isMobile ? 20 : 30,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 1,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
            for (final translate in currentLyricLine!.translates)
              Text(
                translate,

                style: TextStyle(
                  fontSize: isMobile ? 14 : 24,
                  color: Colors.white.withAlpha(128),
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 1,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget controlsRow() {
    return Row(
      children: [
        Spacer(),
        IconButton(
          color: Colors.grey.shade50,

          // Click-through is deliberately not persisted across restarts:
          // this window's isolate can't safely touch the main window's
          // config file (see the multi-isolate note above), and locking
          // silently on launch with no visible unlock affordance would be
          // an easy way for a user to strand themselves. The tray menu's
          // "Unlock Desktop Lyrics" item is the escape hatch if this button
          // becomes unreachable after locking.
          onPressed: () async {
            await windowManager.setIgnoreMouseEvents(true);
          },
          icon: Icon(Icons.lock_rounded, size: 20),
        ),
        IconButton(
          color: Colors.grey.shade50,
          icon: const ImageIcon(previousButtonImage, size: 25),
          onPressed: () async {
            final controllers = await WindowController.getAll();
            for (final controller in controllers) {
              if (controller.arguments.isEmpty) {
                controller.skipToPrevious();
              }
            }
          },
        ),
        IconButton(
          color: Colors.grey.shade50,
          icon: ValueListenableBuilder(
            valueListenable: isPlayingNotifier,
            builder: (_, isPlaying, _) {
              return Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 30,
              );
            },
          ),
          onPressed: () async {
            final controllers = await WindowController.getAll();
            for (final controller in controllers) {
              if (controller.arguments.isEmpty) {
                controller.togglePlay();
              }
            }
          },
        ),
        IconButton(
          color: Colors.grey.shade50,
          icon: const ImageIcon(nextButtonImage, size: 25),
          onPressed: () async {
            final controllers = await WindowController.getAll();
            for (final controller in controllers) {
              if (controller.arguments.isEmpty) {
                controller.skipToNext();
              }
            }
          },
        ),
        IconButton(
          color: Colors.grey.shade50,

          onPressed: () async {
            final controllers = await WindowController.getAll();
            for (final controller in controllers) {
              if (controller.arguments.isEmpty) {
                controller.hideDesktopLyrics();
              }
            }
            windowManager.hide();
          },
          icon: Icon(Icons.close),
        ),
        Spacer(),
      ],
    );
  }
}
