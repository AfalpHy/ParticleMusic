import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/landscape_view/landscape_view.dart';
import 'package:particle_music/mini_view/mini_view.dart';
import 'package:particle_music/portrait_view/portrait_view.dart';

class ViewEntry extends StatelessWidget {
  const ViewEntry({super.key});

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      mobileWidth = MediaQuery.widthOf(context);
      mobileHeight = MediaQuery.heightOf(context);
      shortestSide = MediaQuery.of(context).size.shortestSide;

      if (mobileWidth < mobileHeight) {
        isLandscape = false;
        return PortraitView();
      }
    }
    isLandscape = true;
    return ValueListenableBuilder(
      valueListenable: miniModeNotifier,
      builder: (context, miniMode, child) {
        if (miniMode) {
          return MiniView();
        }
        return LandscapeView();
      },
    );
  }
}
