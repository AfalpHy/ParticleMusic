import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/desktop_lyrics_widget.dart';
import 'package:particle_music/utils.dart';

class OverlayLyrics extends StatefulWidget {
  const OverlayLyrics({super.key});

  @override
  State<StatefulWidget> createState() => _OverlayLyricsState();
}

class _OverlayLyricsState extends State<OverlayLyrics> {
  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is int) {
        verticalDesktopLrcNotifier.value = data == 1;
        return;
      }
      if (data is bool) {
        isPlayingNotifier.value = data;
        return;
      }
      getLyricFromMap(data);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: verticalDesktopLrcNotifier,
      builder: (context, value, child) {
        return Material(
          color: Colors.transparent,
          child: RotatedBox(
            quarterTurns: value ? 1 : 0,
            child: Center(child: DesktopLyricsWidget()),
          ),
        );
      },
    );
  }
}
