import 'dart:ui';

import 'package:flutter/material.dart';
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
          valueListenable: updateColorNotifier,
          builder: (context, value, child) {
            if (enableCustomColorNotifier.value || darkModeNotifier.value) {
              return SizedBox.shrink();
            }
            return CoverArtWidget(song: backgroundSong);
          },
        ),
        ValueListenableBuilder(
          valueListenable: updateColorNotifier,
          builder: (context, value, child) {
            if (enableCustomColorNotifier.value || darkModeNotifier.value) {
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
                child: Container(color: backgroundBaseColor.withAlpha(180)),
              ),
            );
          },
        ),
        ValueListenableBuilder(
          valueListenable: updateColorNotifier,
          builder: (context, value, child) {
            return Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Sidebar(),

                      Expanded(
                        child: Material(
                          color: panelColor,
                          child: IndexedStack(
                            index: layersManager.layerStack.length - 1,
                            children: layersManager.layerStack,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                BottomControl(),
              ],
            );
          },
        ),

        LandscapeLyricsPage(),
      ],
    );
  }
}
