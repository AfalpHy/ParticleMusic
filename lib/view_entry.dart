import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/landscape_view/landscape_view.dart';
import 'package:particle_music/landscape_view/pages/play_queue_page.dart';
import 'package:particle_music/mini_view/mini_view.dart';
import 'package:particle_music/portrait_view/portrait_view.dart';
import 'package:smooth_corner/smooth_corner.dart';

class ViewEntry extends StatelessWidget {
  const ViewEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: miniModeNotifier,
      builder: (context, miniMode, child) {
        if (miniMode) {
          return MiniView();
        }
        return Stack(
          children: [
            mainView(context),

            if (!isMobile)
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

            if (!isMobile)
              Positioned(
                top: 75,
                bottom: 100,
                right: 0,
                child: ValueListenableBuilder(
                  valueListenable: displayPlayQueuePageNotifier,
                  builder: (context, display, _) {
                    return ValueListenableBuilder(
                      valueListenable: currentSongNotifier,
                      builder: (context, value, child) {
                        return AnimatedSlide(
                          offset: display ? Offset.zero : Offset(1, 0),
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.linear,
                          child: Material(
                            elevation: 1,
                            color: colorManager.getSpecificBgBaseColor(),
                            shape: SmoothRectangleBorder(
                              smoothness: 1,
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(10),
                              ),
                            ),
                            clipBehavior: .antiAliasWithSaveLayer,
                            child: Container(
                              color: colorManager.getSpecificBgColor(),
                              width: max(
                                350,
                                MediaQuery.widthOf(context) * 0.2,
                              ),
                              child: PlayQueuePage(),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget mainView(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (isMobile && orientation == Orientation.portrait) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          return PortraitView();
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
          return LandscapeView();
        }
      },
    );
  }
}
