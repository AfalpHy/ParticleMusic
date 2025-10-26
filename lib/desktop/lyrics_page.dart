import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/lyrics.dart';

class LyricsPage extends StatelessWidget {
  final ValueNotifier<bool> displayLyricsPageNotifier;

  const LyricsPage({super.key, required this.displayLyricsPageNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: displayLyricsPageNotifier,
      builder: (context, display, _) {
        return AnimatedSlide(
          offset: display ? Offset.zero : const Offset(0, 1),
          duration: const Duration(milliseconds: 300),
          curve: Curves.linear,
          child: ValueListenableBuilder(
            valueListenable: currentSongNotifier,
            builder: (context, currentSong, child) {
              return Material(
                color: coverArtAverageColor,
                child: Stack(
                  children: [
                    Row(
                      children: [
                        SizedBox(width: MediaQuery.widthOf(context) * 0.15),
                        InkWell(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          onTap: () {
                            displayLyricsPageNotifier.value = false;
                          },
                          child: CoverArtWidget(
                            size: MediaQuery.widthOf(context) * 0.3,
                            borderRadius: MediaQuery.widthOf(context) * 0.015,
                            source: getCoverArt(currentSong),
                          ),
                        ),
                        SizedBox(width: MediaQuery.widthOf(context) * 0.05),
                        SizedBox(
                          width: MediaQuery.widthOf(context) * 0.4,
                          child: Column(
                            children: [
                              SizedBox(height: 100),
                              Expanded(
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent, // fade out at top
                                        Colors.black, // fully visible
                                        Colors.black, // fully visible
                                        Colors
                                            .transparent, // fade out at bottom
                                      ],
                                      stops: [
                                        0.0,
                                        0.1,
                                        0.9,
                                        1.0,
                                      ], // adjust fade height
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  // use key to force update
                                  child: ScrollConfiguration(
                                    behavior: ScrollConfiguration.of(
                                      context,
                                    ).copyWith(scrollbars: false),
                                    child: LyricsListView(
                                      key: ValueKey(currentSong),
                                      expanded: true,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 75),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(left: 0, right: 0, top: 0, child: TitleBar()),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
