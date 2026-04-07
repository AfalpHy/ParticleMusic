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

        return Column(
          crossAxisAlignment: .center,
          children: [
            if (desktopLyricsIsKaraoke)
              ValueListenableBuilder(
                valueListenable: updateLyricsNotifier,
                builder: (context, value, child) {
                  return KaraokeText(
                    key: UniqueKey(),
                    line: desktopLyricLine!,
                    position: desktopLyricsCurrentPosition,
                    fontSize: isMobile ? 20 : 30,
                    expanded: false,
                    isDesktopLyrics: true,
                  );
                },
              )
            else
              Text(
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
              ),
            for (final translate in desktopLyricLine!.translates)
              Text(
                translate,

                style: TextStyle(
                  fontSize: isMobile ? 14 : 24,
                  color: Colors.white.withAlpha(128),
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 1,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
