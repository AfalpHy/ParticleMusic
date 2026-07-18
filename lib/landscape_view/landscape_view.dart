import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/landscape_view/bottom_control.dart';
import 'package:sylvakru/landscape_view/sidebar.dart';
import 'package:sylvakru/layer/layers_manager.dart';

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
            if (value != .vivid) {
              return SizedBox.shrink();
            }
            return ValueListenableBuilder(
              valueListenable: layersManager.backgroundChangeNotifier,
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
            if (value != .vivid) {
              return SizedBox.shrink();
            }
            final pageWidth = MediaQuery.widthOf(context);
            final pageHight = MediaQuery.heightOf(context);

            // Without this, this always-visible background blur has no
            // layer of its own, so every resize (e.g. un-maximizing) forces
            // the whole tree behind it to repaint in the same frame as the
            // blur recompute - unlike the identical effect on the lyrics
            // pages, which already isolates it this way.
            return RepaintBoundary(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: pageWidth * 0.03,
                  sigmaY: pageHight * 0.03,
                ),
                child: ValueListenableBuilder(
                  valueListenable: layersManager.backgroundChangeNotifier,
                  builder: (context, value, child) {
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeInOutCubic,
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
                        return Material(color: value, child: child);
                      },
                      child: ValueListenableBuilder(
                        valueListenable: layersManager.switchNotifier,
                        builder: (context, value, child) {
                          return Stack(
                            children: layersManager.rootLayerMap.values.map((
                              layer,
                            ) {
                              return Visibility(
                                visible: layer == layersManager.topRootLayer,
                                maintainState: true,
                                child: layer,
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            BottomControl(),
          ],
        ),
      ],
    );
  }
}
