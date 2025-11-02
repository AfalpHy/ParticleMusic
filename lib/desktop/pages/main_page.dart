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
    // clear press state when focus lost
    appFocusNode.addListener(() {
      shiftIsPressed = false;
      ctrlIsPressed = false;
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
    return KeyboardListener(
      focusNode: appFocusNode,
      autofocus: true,
      onKeyEvent: (value) {
        if (value is KeyDownEvent || value is KeyRepeatEvent) {
          if (value.logicalKey.keyLabel == 'Shift Left' ||
              value.logicalKey.keyLabel == 'Shift Right') {
            shiftIsPressed = true;
          }
          if (value.logicalKey.keyLabel == 'Control Left' ||
              value.logicalKey.keyLabel == 'Control Right') {
            ctrlIsPressed = true;
          }
        } else if (value is KeyUpEvent) {
          if (value.logicalKey.keyLabel == 'Shift Left' ||
              value.logicalKey.keyLabel == 'Shift Right') {
            shiftIsPressed = false;
          }
          if (value.logicalKey.keyLabel == 'Control Left' ||
              value.logicalKey.keyLabel == 'Control Right') {
            ctrlIsPressed = false;
          }
        }
      },
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Sidebar(),

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
            top: 80,
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
                    elevation: 5,
                    color: Colors.grey.shade50,
                    shape: SmoothRectangleBorder(
                      smoothness: 1,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(15),
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
      ),
    );
  }
}
