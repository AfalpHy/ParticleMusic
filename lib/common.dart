import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

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
