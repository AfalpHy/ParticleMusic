import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/lyrics.dart';

class DesktopLyricsWidget extends StatelessWidget {
  const DesktopLyricsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: updateDesktopLyricsNotifier,
      builder: (context, value, child) {
        if (desktopLyricLine == null) {
          return Text(
            'Particle Music',
            style: TextStyle(
              fontSize: isMobile ? 20 : 30,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 1,
                  color: Colors.black87,
                ),
              ],
            ),
          );
        }

        if (desktopLyricsIsKaraoke) {
          return KaraokeText(
            key: ValueKey(desktopLyricLine),
            line: desktopLyricLine!,
            position: desktopLyricsCurrentPosition,
            fontSize: isMobile ? 20 : 30,
            expanded: false,
            isDesktopLyrics: true,
          );
        } else {
          return Text(
            desktopLyricLine!.text,
            style: TextStyle(
              fontSize: isMobile ? 20 : 30,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 1,
                  color: Colors.black87,
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
