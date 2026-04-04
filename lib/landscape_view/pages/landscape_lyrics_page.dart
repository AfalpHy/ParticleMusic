import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/buttons.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common_widgets/my_auto_size_text.dart';
import 'package:particle_music/landscape_view/speaker.dart';
import 'package:particle_music/landscape_view/title_bar.dart';
import 'package:particle_music/landscape_view/volume_bar.dart';
import 'package:particle_music/common_widgets/lyrics.dart';
import 'package:particle_music/common_widgets/seekbar.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';

class LandscapeLyricsPage extends StatefulWidget {
  const LandscapeLyricsPage({super.key});

  @override
  State<LandscapeLyricsPage> createState() => _LandscapeLyricsPageState();
}

class _LandscapeLyricsPageState extends State<LandscapeLyricsPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: displayLyricsPageNotifier,
      builder: (context, display, child) {
        if (!display) {
          immersiveModeTimer?.cancel();
          immersiveModeTimer = null;
        } else if (!isMobile) {
          immersiveModeTimer = Timer(const Duration(milliseconds: 5000), () {
            immersiveModeNotifier.value = true;
            immersiveModeTimer = null;
          });
        }
        return IgnorePointer(
          ignoring: !display,
          child: ValueListenableBuilder(
            valueListenable: immersiveModeNotifier,
            builder: (context, value, child) {
              return MouseRegion(
                cursor: value ? SystemMouseCursors.none : MouseCursor.defer,
                onHover: (event) {
                  immersiveModeNotifier.value = false;
                  immersiveModeTimer?.cancel();
                  immersiveModeTimer = Timer(
                    const Duration(milliseconds: 5000),
                    () {
                      immersiveModeNotifier.value = true;
                      immersiveModeTimer = null;
                    },
                  );
                },
                child: child,
              );
            },
            child: AnimatedSlide(
              offset: display ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.linear,
              child: content(),
            ),
          ),
        );
      },
    );
  }

  Widget content() {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (context, currentSong, child) {
        final pageWidth = MediaQuery.widthOf(context);
        final pageHight = MediaQuery.heightOf(context);
        final coverArtSize = min(pageWidth * 0.3, pageHight * 0.6);

        return Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ValueListenableBuilder(
                valueListenable: updateColorNotifier,
                builder: (context, value, child) {
                  if (lyricsPageThemeNotifier.value != 0) {
                    return SizedBox.shrink();
                  }
                  return CoverArtWidget(song: currentSong);
                },
              ),
              ValueListenableBuilder(
                valueListenable: updateColorNotifier,
                builder: (context, value, child) {
                  if (lyricsPageThemeNotifier.value != 0) {
                    return SizedBox.shrink();
                  }
                  return ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: pageWidth * 0.03,
                        sigmaY: pageHight * 0.03,
                      ),
                      child: Container(
                        color: lyricsPageBackgroundBaseColor.withAlpha(180),
                      ),
                    ),
                  );
                },
              ),
              Container(
                color: lyricsPageBackgroundColor,
                child: Row(
                  children: [
                    Spacer(),
                    Column(
                      children: [
                        SizedBox(height: pageHight * 0.1),
                        Spacer(),
                        CoverArtWidget(
                          size: coverArtSize,
                          borderRadius: coverArtSize * 0.025,
                          song: currentSong,
                        ),
                        if (pageHight > 600) ...[
                          message(coverArtSize, pageHight, currentSong),
                          playControls(coverArtSize, pageHight, currentSong),
                        ],

                        Spacer(),
                        SizedBox(height: pageHight * 0.05),
                      ],
                    ),
                    SizedBox(width: pageWidth * 0.05),
                    SizedBox(
                      width: pageWidth * 0.45,
                      child: Column(
                        children: [
                          SizedBox(height: pageHight * 0.1),
                          if (pageHight <= 600)
                            message(pageWidth * 0.35, pageHight, currentSong),

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
                                    Colors.transparent, // fade out at bottom
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
                                child: currentSong == null
                                    ? SizedBox()
                                    : LyricsListView(
                                        key: ValueKey(currentSong),
                                        expanded: isMobile ? false : true,
                                        lyrics:
                                            currentSong.parsedLyrics!.lyrics,
                                        isKaraoke:
                                            currentSong.parsedLyrics!.isKaraoke,
                                      ),
                              ),
                            ),
                          ),

                          if (pageHight <= 600) ...[
                            playControls(
                              pageWidth * 0.4,
                              pageHight,
                              currentSong,
                            ),
                            SizedBox(height: 20),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: pageWidth * 0.05),
                  ],
                ),
              ),

              Positioned(
                right: 60,
                bottom: 100,
                child: ValueListenableBuilder(
                  valueListenable: immersiveModeNotifier,
                  builder: (context, value, child) {
                    List<Widget> children = [
                      IconButton(
                        color: lyricsPageForegroundColor,
                        onPressed: () {
                          lyricsFontSizeOffset += 2;
                          lyricsFontSizeOffsetChangeNotifier.value++;
                          settingManager.saveSetting();
                        },
                        icon: Icon(Icons.text_increase_rounded, size: 20),
                      ),
                      IconButton(
                        color: lyricsPageForegroundColor,
                        onPressed: () {
                          if (lyricsFontSizeOffset < -2) {
                            return;
                          }
                          lyricsFontSizeOffset -= 2;
                          lyricsFontSizeOffsetChangeNotifier.value++;
                          settingManager.saveSetting();
                        },
                        icon: Icon(Icons.text_decrease_rounded, size: 18),
                      ),
                    ];
                    return Offstage(
                      offstage: value,
                      child: pageHight <= 600
                          ? Column(children: children)
                          : Row(children: children),
                    );
                  },
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: ValueListenableBuilder<bool>(
                  valueListenable: immersiveModeNotifier,
                  builder: (context, value, child) {
                    return Offstage(offstage: value, child: child);
                  },
                  child: TitleBar(isMainPage: false),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget message(double width, double pageHight, MyAudioMetadata? currentSong) {
    return Column(
      children: [
        SizedBox(height: pageHight * 0.01),
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
                color: lyricsPageHighlightTextColor,
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
              textStyle: TextStyle(
                fontSize: 14,
                color: lyricsPageForegroundColor,
              ),
            ),
          ),
        ),

        SizedBox(height: pageHight * 0.01),
      ],
    );
  }

  Widget playControls(
    double width,
    double pageHight,
    MyAudioMetadata? currentSong,
  ) {
    return Column(
      children: [
        SizedBox(
          width: width - 15,
          child: SeekBar(
            color: lyricsPageForegroundColor,
            widgetHeight: 20,
            seekBarHeight: 10,
          ),
        ),

        SizedBox(
          width: width,
          child: Row(
            children: [
              playModeButton(25, iconColor: lyricsPageForegroundColor),
              Spacer(),

              skip2PreviousButton(25, iconColor: lyricsPageForegroundColor),

              playOrPauseButton(35, iconColor: lyricsPageForegroundColor),

              skip2NextButton(25, iconColor: lyricsPageForegroundColor),

              Spacer(),
              showPlayQueueButton(25, iconColor: lyricsPageForegroundColor),
            ],
          ),
        ),
        if (!isMobile)
          SizedBox(
            width: width,
            child: Row(
              children: [
                Spacer(),

                SizedBox(
                  width: 40,
                  child: Speaker(color: lyricsPageForegroundColor),
                ),
                SizedBox(
                  height: 10,
                  width: width * 0.5,
                  child: VolumeBar(activeColor: lyricsPageForegroundColor),
                ),
                SizedBox(
                  width: 40,
                  child: IconButton(
                    onPressed: () async {
                      if (lyricsWindowVisible) {
                        await lyricsWindowController!.hide();
                      } else {
                        await updateDesktopLyrics();
                        await lyricsWindowController!.show();
                      }
                      lyricsWindowVisible = !lyricsWindowVisible;
                    },
                    icon: const ImageIcon(desktopLyricsImage, size: 25),

                    color: lyricsPageForegroundColor,
                  ),
                ),
                Spacer(),
              ],
            ),
          ),
        SizedBox(height: pageHight * 0.02),
      ],
    );
  }
}
