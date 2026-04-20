import 'package:flutter/material.dart';
import 'package:particle_music/color_manager.dart';

class MyDivider extends StatelessWidget {
  final MyColor color;
  final double? width;
  final double? height;

  final double? thickness;
  final double? indent;
  final double? endIndent;
  final BorderRadiusGeometry? radius;
  final bool vertical;
  const MyDivider({
    super.key,
    required this.color,
    this.width,
    this.height,
    this.thickness,
    this.indent,
    this.endIndent,
    this.radius,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: color.valueNotifier,
      builder: (context, value, child) {
        return vertical
            ? VerticalDivider(
                width: width,
                thickness: thickness,
                indent: indent,
                endIndent: endIndent,
                radius: radius,
                color: value,
              )
            : Divider(
                height: height,
                thickness: thickness,
                indent: indent,
                endIndent: endIndent,
                radius: radius,
                color: value,
              );
      },
    );
  }
}
