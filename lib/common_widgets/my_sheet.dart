import 'package:flutter/material.dart';
import 'package:smooth_corner/smooth_corner.dart';

class MySheet extends StatelessWidget {
  final Widget child;
  final double height;

  const MySheet(this.child, {super.key, this.height = 500});

  @override
  Widget build(BuildContext context) {
    return SmoothClipRRect(
      smoothness: 1,
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      child: Container(
        height: height,
        color: Colors.grey.shade100,
        child: child,
      ),
    );
  }
}
