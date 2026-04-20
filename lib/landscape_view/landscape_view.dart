import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/landscape_view/bottom_control.dart';
import 'package:particle_music/landscape_view/pages/landscape_lyrics_page.dart';
import 'package:particle_music/landscape_view/sidebar.dart';
import 'package:particle_music/layer/layers_manager.dart';

class LandscapeView extends StatelessWidget {
  const LandscapeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,

      children: [
        ValueListenableBuilder(
          valueListenable: mainPageThemeNotifier,
          builder: (context, value, child) {
            if (value != 0) {
              return SizedBox.shrink();
            }
            return ValueListenableBuilder(
              valueListenable: layersManager.updateNotifier,
              builder: (context, value, child) {
                return CoverArtWidget(
                  song: backgroundSong,
                  color: colorManager.getSpecificBgBaseColor(),
                );
              },
            );
          },
        ),
        ValueListenableBuilder(
          valueListenable: mainPageThemeNotifier,
          builder: (context, value, child) {
            if (value != 0) {
              return SizedBox.shrink();
            }
            final pageWidth = MediaQuery.widthOf(context);
            final pageHight = MediaQuery.heightOf(context);

            return ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: pageWidth * 0.03,
                  sigmaY: pageHight * 0.03,
                ),
                child: ValueListenableBuilder(
                  valueListenable: layersManager.updateNotifier,
                  builder: (context, value, child) {
                    return Container(
                      color: backgroundCoverArtColor.withAlpha(180),
                    );
                  },
                ),
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
                      valueListenable: panelColor.valueNotifier,
                      builder: (context, value, child) {
                        return Material(
                          color: value,
                          child: ValueListenableBuilder(
                            valueListenable: layersManager.updateNotifier,
                            builder: (context, value, child) {
                              return IndexedStack(
                                index: layersManager.layerStack.length - 1,
                                children: layersManager.layerStack,
                              );
                            },
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

        LandscapeLyricsPage(),
      ],
    );
  }
}
