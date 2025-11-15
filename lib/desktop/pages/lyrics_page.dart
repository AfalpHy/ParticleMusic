import 'dart:math';
import 'dart:ui';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/desktop/pages/play_queue_page.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/full_width_track_shape.dart';
import 'package:particle_music/lyrics.dart';
import 'package:particle_music/seekbar.dart';

final ValueNotifier<bool> displayLyricsPageNotifier = ValueNotifier(false);

class LyricsPage extends StatefulWidget {
  const LyricsPage({super.key});

  @override
  State<LyricsPage> createState() => LyricsPageState();
}

class LyricsPageState extends State<LyricsPage> {
  @override
  void initState() {
    super.initState();
  }

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
              final pageWidth = MediaQuery.widthOf(context);
              final pageHight = MediaQuery.heightOf(context);
              final coverArtSize = min(pageWidth * 0.3, pageHight * 0.6);

              return Material(
                color: coverArtAverageColor,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverArtWidget(source: getCoverArt(currentSong)),
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: pageWidth * 0.03,
                          sigmaY: pageHight * 0.03,
                        ),
                        child: Container(color: coverArtFilterColor),
                      ),
                    ),
                    Row(
                      children: [
                        Spacer(),
                        Column(
                          children: [
                            SizedBox(height: pageHight * 0.1),
                            Spacer(),
                            CoverArtWidget(
                              size: coverArtSize,
                              borderRadius: coverArtSize * 0.025,
                              source: getCoverArt(currentSong),
                            ),
                            playControls(
                              coverArtSize,
                              pageHight,
                              currentSong,
                              context,
                            ),
                            Spacer(),
                          ],
                        ),
                        SizedBox(width: pageWidth * 0.07),
                        SizedBox(
                          width: pageWidth * 0.44,
                          child: Column(
                            children: [
                              SizedBox(height: 75),
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
                                        0.05,
                                        0.95,
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
                            ],
                          ),
                        ),
                        SizedBox(width: pageWidth * 0.05),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: TitleBar(isMainPage: false),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget playControls(
    double width,
    double pageHight,
    AudioMetadata? currentSong,
    BuildContext context,
  ) {
    return Column(
      children: [
        SizedBox(height: pageHight * 0.025),
        SizedBox(
          width: width - 30,

          height: 36,
          child: Center(
            child: MyAutoSizeText(
              key: UniqueKey(),
              getTitle(currentSong),
              maxLines: 1,
              textStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.grey.shade50,
              ),
            ),
          ),
        ),

        SizedBox(
          width: width - 30,

          height: 28,
          child: Center(
            child: MyAutoSizeText(
              key: UniqueKey(),
              '${getArtist(currentSong)} - ${getAlbum(currentSong)}',
              maxLines: 1,
              textStyle: TextStyle(fontSize: 14, color: Colors.grey.shade100),
            ),
          ),
        ),
        SizedBox(height: pageHight * 0.02),

        SizedBox(width: width - 15, height: 20, child: SeekBar(light: true)),

        SizedBox(
          width: width,
          child: Row(
            children: [
              ValueListenableBuilder(
                valueListenable: playModeNotifier,
                builder: (_, playMode, _) {
                  return IconButton(
                    color: Colors.grey.shade50,
                    icon: ImageIcon(
                      playMode == 0
                          ? loopImage
                          : playMode == 1
                          ? shuffleImage
                          : repeatImage,
                      size: 25,
                    ),
                    onPressed: () {
                      if (playQueue.isEmpty) {
                        return;
                      }
                      if (playModeNotifier.value != 2) {
                        audioHandler.switchPlayMode();
                        switch (playModeNotifier.value) {
                          case 0:
                            showCenterMessage(context, "loop");
                            break;
                          default:
                            showCenterMessage(context, "shuffle");
                            break;
                        }
                      }
                    },
                    onLongPress: () {
                      if (playQueue.isEmpty) {
                        return;
                      }
                      audioHandler.toggleRepeat();
                      switch (playModeNotifier.value) {
                        case 0:
                          showCenterMessage(context, "loop");
                          break;
                        case 1:
                          showCenterMessage(context, "shuffle");
                          break;
                        default:
                          showCenterMessage(context, "repeat");
                          break;
                      }
                    },
                  );
                },
              ),
              Spacer(),
              IconButton(
                color: Colors.grey.shade50,
                icon: const ImageIcon(previousButtonImage, size: 25),
                onPressed: () {
                  if (playQueue.isEmpty) {
                    return;
                  }
                  audioHandler.skipToPrevious();
                },
              ),

              IconButton(
                color: Colors.grey.shade50,
                icon: ValueListenableBuilder(
                  valueListenable: isPlayingNotifier,
                  builder: (_, isPlaying, _) {
                    return Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 35,
                    );
                  },
                ),
                onPressed: () {
                  if (playQueue.isEmpty) {
                    return;
                  }
                  audioHandler.togglePlay();
                },
              ),
              IconButton(
                color: Colors.grey.shade50,
                icon: const ImageIcon(nextButtonImage, size: 25),
                onPressed: () {
                  if (playQueue.isEmpty) {
                    return;
                  }

                  audioHandler.skipToNext();
                },
              ),
              Spacer(),
              IconButton(
                color: Colors.grey.shade50,
                icon: Icon(Icons.playlist_play_rounded, size: 25),
                onPressed: () {
                  if (playQueue.isEmpty) {
                    return;
                  }
                  displayPlayQueuePageNotifier.value = true;
                },
              ),
            ],
          ),
        ),
        SizedBox(
          width: width,
          child: Row(
            children: [
              Spacer(),
              SizedBox(
                width: 40,
                child: IconButton(
                  icon: Icon(Icons.volume_down_rounded),
                  color: Colors.grey.shade50,
                  onPressed: () {},
                ),
              ),
              SizedBox(
                width: width * 0.5,
                child: ValueListenableBuilder(
                  valueListenable: volumeNotifier,
                  builder: (context, value, child) {
                    return SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        trackShape: const FullWidthTrackShape(),
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: 0,
                        ), // smaller thumb
                        overlayColor: Colors.transparent,
                        activeTrackColor: Colors.grey.shade50,
                        inactiveTrackColor: Colors.black12,
                        thumbColor: Colors.grey.shade50,
                      ),
                      child: Slider(
                        value: value,
                        min: 0,
                        max: 1,
                        onChanged: (value) {
                          volumeNotifier.value = value;
                          audioHandler.setVolume(value);
                        },
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: 40),
              Spacer(),
            ],
          ),
        ),
      ],
    );
  }
}
