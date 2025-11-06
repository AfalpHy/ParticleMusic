import 'dart:io';

import 'package:flutter/material.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:window_manager/window_manager.dart';

final ValueNotifier<bool> lyricsIsTransparentNotifier = ValueNotifier(false);

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
                      child: Text(
                        'desktop lyrics demo',
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 30,
                        ),
                      ),
                    ),
                    if (!value)
                      Row(
                        children: [
                          Spacer(),
                          IconButton(
                            onPressed: () async {
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
