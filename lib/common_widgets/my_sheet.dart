import 'dart:math';

import 'package:flutter/material.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:smooth_corner/smooth_corner.dart';

class MySheet extends StatelessWidget {
  final Widget child;
  final double? height;

  const MySheet(this.child, {super.key, this.height});

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: SmoothRectangleBorder(
        smoothness: 1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      color: displayLyricsPageNotifier.value
          ? lyricsPageBackgroundColor
          : backgroundBaseColor,
      clipBehavior: .antiAlias,
      child: Container(
        color: displayLyricsPageNotifier.value
            ? vividModePageBackgroundColor
            : pageBackgroundColor,
        height: height ?? min(500, MediaQuery.heightOf(context) * 0.6),
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
  }
}
