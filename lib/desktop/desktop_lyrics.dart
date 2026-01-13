import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/desktop/extensions/window_controller_extension.dart';
import 'package:particle_music/lyrics.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:window_manager/window_manager.dart';

final ValueNotifier<bool> lyricsIsTransparentNotifier = ValueNotifier(false);

String? lyricsWindowId;
bool lyricsWindowVisible = false;

final ValueNotifier<LyricLine?> lyricLineNotifier = ValueNotifier(null);
final ValueNotifier<Duration> currentPositionNotifier = ValueNotifier(
  Duration.zero,
);
bool desktopLyricsIsKaraoke = false;

Future<void> initDesktopLyrics() async {
  final controller = await WindowController.create(
    WindowConfiguration(hiddenAtLaunch: true, arguments: 'desktop_lyrics'),
  );
  lyricsWindowId = controller.windowId;
}

class DesktopLyrics extends StatelessWidget {
  const DesktopLyrics({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: Platform.isWindows
          ? ThemeData(fontFamily: 'Microsoft YaHei')
          : null,

      home: ValueListenableBuilder(
        valueListenable: lyricsIsTransparentNotifier,
        builder: (context, value, child) {
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
                lyricsIsTransparentNotifier.value = false;
              },
              onExit: (_) {
                if (isDragging) {
                  return;
                }
                lyricsIsTransparentNotifier.value = true;
              },
              child: Material(
                color: value ? Colors.transparent : Colors.black45,
                shape: SmoothRectangleBorder(
                  smoothness: 1,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: ValueListenableBuilder(
                        valueListenable: lyricLineNotifier,
                        builder: (context, lyricline, child) {
                          if (lyricline == null) {
                            return Text(
                              'Particle Music',
                              style: TextStyle(
                                color: Colors.grey.shade300,
                                fontSize: 30,
                              ),
                            );
                          }

                          if (desktopLyricsIsKaraoke) {
                            return ValueListenableBuilder(
                              valueListenable: currentPositionNotifier,
                              builder: (context, value, child) {
                                return KaraokeText(
                                  key: UniqueKey(),
                                  line: lyricline,
                                  position: value,
                                  fontSize: 30,
                                  expanded: false,
                                );
                              },
                            );
                          } else {
                            return Text(
                              lyricline.text,
                              style: TextStyle(
                                fontSize: 30,
                                color: Colors.grey.shade300,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    if (!value)
                      Row(
                        children: [
                          Spacer(),
                          IconButton(
                            onPressed: () async {
                              final controllers =
                                  await WindowController.getAll();
                              for (final controller in controllers) {
                                if (controller.arguments.isEmpty) {
                                  controller.hideDesktopLyrics();
                                }
                              }
                              windowManager.hide();
                            },
                            icon: Icon(Icons.close),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
