import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

class MyAutoSizeText extends AutoSizeText {
  final String content;

  final TextStyle textStyle;
  MyAutoSizeText(
    this.content, {
    super.key,
    super.maxLines,
    required this.textStyle,
  }) : super(
         content,
         style: textStyle,
         minFontSize: textStyle.fontSize ?? 12,
         maxFontSize: textStyle.fontSize ?? double.infinity,
         overflowReplacement: Marquee(
           text: content,
           style: textStyle,
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
