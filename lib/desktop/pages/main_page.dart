import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/desktop/bottom_control.dart';
import 'package:particle_music/desktop/keyboard.dart';
import 'package:particle_music/desktop/plane_manager.dart';
import 'package:particle_music/desktop/pages/play_queue_page.dart';
import 'package:particle_music/desktop/sidebar.dart';
import 'package:particle_music/desktop/pages/lyrics_page.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class DesktopMainPage extends StatelessWidget with TrayListener {
  DesktopMainPage({super.key}) {
    HardwareKeyboard.instance.addHandler((event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey.keyLabel == 'Shift Left' ||
            event.logicalKey.keyLabel == 'Shift Right') {
          shiftIsPressed = true;
        }
        if (event.logicalKey.keyLabel == 'Control Left' ||
            event.logicalKey.keyLabel == 'Control Right') {
          ctrlIsPressed = true;
        }
      } else if (event is KeyUpEvent) {
        if (event.logicalKey.keyLabel == 'Shift Left' ||
            event.logicalKey.keyLabel == 'Shift Right') {
          shiftIsPressed = false;
        }
        if (event.logicalKey.keyLabel == 'Control Left' ||
            event.logicalKey.keyLabel == 'Control Right') {
          ctrlIsPressed = false;
        }
      }
      return false;
    });

    windowManager.addListener(MyWindowListener());
    trayManager.addListener(this);
  }

  @override
  void onTrayIconMouseDown() async {
    windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    // ignore: deprecated_member_use
    trayManager.popUpContextMenu(bringAppToFront: true);
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show') {
      await windowManager.show();
    } else if (menuItem.key == 'exit') {
      exit(0);
    } else if (menuItem.key == 'skipToPrevious') {
      if (playQueue.isNotEmpty) {
        await audioHandler.skipToPrevious();
      }
    } else if (menuItem.key == 'togglePlay') {
      if (playQueue.isNotEmpty) {
        await audioHandler.togglePlay();
      }
    } else if (menuItem.key == 'skipToNext') {
      if (playQueue.isNotEmpty) {
        await audioHandler.skipToNext();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Sidebar(),

                  Expanded(
                    child: Column(
                      children: [
                        TitleBar(isMainPage: true),
                        Expanded(
                          child: ValueListenableBuilder(
                            valueListenable: planeManager.updatePlane,
                            builder: (_, _, _) {
                              return IndexedStack(
                                index: planeManager.planeStack.length - 1,
                                children: planeManager.planeStack,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Material(child: BottomControl()),
          ],
        ),

        LyricsPage(),

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
                    width: max(350, MediaQuery.widthOf(context) * 0.25),
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
