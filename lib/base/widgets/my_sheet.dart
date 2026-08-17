import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:smooth_corner/smooth_corner.dart';

class MySheet extends StatelessWidget {
  final Widget child;
  final double? height;

  const MySheet(this.child, {super.key, this.height});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (context, _, _) {
        return Material(
          shape: SmoothRectangleBorder(
            smoothness: 1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          color: Color.alphaBlend(
            colorManager.getSpecificBgColor(),
            colorManager.getSpecificBgBaseColor(),
          ),
          clipBehavior: .antiAlias,
          child: SizedBox(
            height: min(height ?? 500, MediaQuery.heightOf(context) * 0.6),
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: true, // for mobile
              removeRight: true,
              removeBottom: true,
              removeTop: true,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
