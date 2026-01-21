import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/desktop/bottom_control.dart';
import 'package:particle_music/desktop/panels/panel_manager.dart';
import 'package:particle_music/desktop/pages/play_queue_page.dart';
import 'package:particle_music/desktop/sidebar.dart';
import 'package:particle_music/desktop/pages/lyrics_page.dart';
import 'package:smooth_corner/smooth_corner.dart';

ValueNotifier<int> updateBackgroundNotifier = ValueNotifier(0);
AudioMetadata? backgroundSong;
Color backgroundColor = Colors.grey;

class DesktopMainPage extends StatelessWidget {
  const DesktopMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,

      children: [
        ValueListenableBuilder(
          valueListenable: updateBackgroundNotifier,
          builder: (context, value, child) {
            return CoverArtWidget(source: getCoverArt(backgroundSong));
          },
        ),
        ValueListenableBuilder(
          valueListenable: updateBackgroundNotifier,
          builder: (context, value, child) {
            final pageWidth = MediaQuery.widthOf(context);
            final pageHight = MediaQuery.heightOf(context);

            return ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: pageWidth * 0.03,
                  sigmaY: pageHight * 0.03,
                ),
                child: Container(color: backgroundColor.withAlpha(180)),
              ),
            );
          },
        ),
        Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Sidebar(),

                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: panelManager.updatePanel,
                      builder: (_, _, _) {
                        return Material(
                          color: panelColor,
                          child: IndexedStack(
                            index: panelManager.panelStack.length - 1,
                            children: panelManager.panelStack,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            BottomControl(),
          ],
        ),

        ValueListenableBuilder(
          valueListenable: displayLyricsPageNotifier,
          builder: (context, value, child) {
            if (!value) {
              immersiveModeTimer?.cancel();
              immersiveModeTimer = null;
            } else {
              immersiveModeTimer = Timer(
                const Duration(milliseconds: 5000),
                () {
                  immersiveModeNotifier.value = true;
                  immersiveModeTimer = null;
                },
              );
            }
            return IgnorePointer(
              ignoring: !value,
              child: ValueListenableBuilder(
                valueListenable: immersiveModeNotifier,
                builder: (context, value, child) {
                  return MouseRegion(
                    cursor: value ? SystemMouseCursors.none : MouseCursor.defer,
                    onHover: (event) {
                      immersiveModeNotifier.value = false;
                      immersiveModeTimer?.cancel();
                      immersiveModeTimer = Timer(
                        const Duration(milliseconds: 5000),
                        () {
                          immersiveModeNotifier.value = true;
                          immersiveModeTimer = null;
                        },
                      );
                    },
                    child: child,
                  );
                },
                child: LyricsPage(),
              ),
            );
          },
        ),

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
          top: 75,
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
                  elevation: 1,
                  color: Colors.grey.shade50,
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(10),
                    ),
                  ),

                  child: SizedBox(
                    width: max(350, MediaQuery.widthOf(context) * 0.2),
                    child: PlayQueuePage(),
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
