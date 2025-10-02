import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

late bool hasVibration;

class MyAutoSizeText extends AutoSizeText {
  final String content;
  MyAutoSizeText(
    this.content, {
    super.key,
    super.maxLines,
    super.minFontSize,
    super.maxFontSize,
    super.style,
  }) : super(
         content,
         overflowReplacement: Marquee(
           text: content,
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
