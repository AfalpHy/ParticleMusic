import 'dart:math';

import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:smooth_corner/smooth_corner.dart';

class MySheet extends StatelessWidget {
  final Widget child;
  final double? height;

  const MySheet(this.child, {super.key, this.height});

  @override
  Widget build(BuildContext context) {
    return SmoothClipRRect(
      smoothness: 1,
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      child: Container(
        color: pageBackgroundColor,
        height: height ?? min(500, mobileHeight * 0.6),
        child: child,
      ),
    );
  }
}
