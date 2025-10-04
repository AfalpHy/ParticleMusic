import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:smooth_corner/smooth_corner.dart';

late bool hasVibration;

class MyAutoSizeText extends AutoSizeText {
  final String content;
  final double fontsize;
  MyAutoSizeText(
    this.content, {
    super.key,
    super.maxLines,
    super.style,
    required this.fontsize,
  }) : super(
         content,
         minFontSize: fontsize,
         maxFontSize: fontsize,
         overflowReplacement: Marquee(
           text: content,
           style: TextStyle(fontSize: fontsize),
           scrollAxis: Axis.horizontal,
           blankSpace: 20,
           velocity: 30,
           pauseAfterRound: const Duration(seconds: 1),
           accelerationDuration: const Duration(milliseconds: 500),
           accelerationCurve: Curves.linear,
           decelerationDuration: const Duration(milliseconds: 500),
           decelerationCurve: Curves.linear,
         ),
       );
}

Widget mySheet(Widget child, {double height = 500, color = Colors.white}) {
  return SmoothClipRRect(
    smoothness: 1,
    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
    child: Container(height: height, color: color, child: child),
  );
}
