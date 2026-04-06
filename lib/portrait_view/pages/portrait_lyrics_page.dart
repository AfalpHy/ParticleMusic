import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common_widgets/buttons.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/my_auto_size_text.dart';
import 'package:particle_music/common_widgets/playlist_widgets.dart';
import 'package:particle_music/portrait_view/sleep_timer.dart';
import 'package:particle_music/common_widgets/my_sheet.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/common_widgets/lyrics.dart';
import 'package:particle_music/common_widgets/play_queue_sheet.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/common_widgets/seekbar.dart';
import 'package:particle_music/utils.dart';

class PortraitLyricsPage extends StatefulWidget {
  const PortraitLyricsPage({super.key});

  @override
  State<PortraitLyricsPage> createState() => _PortraitLyricsPageState();
}

class _PortraitLyricsPageState extends State<PortraitLyricsPage> {
  late double dragOffset;

  int _animationDuration = 0;

  void closeOrReset() {
    if (displayLyricsPageNotifier.value) {
      _resetSheet();
    } else {
      _closeSheet();
    }
  }

  @override
  void initState() {
    super.initState();
    if (displayLyricsPageNotifier.value) {
      dragOffset = 0;
    } else {
      dragOffset = 1;
    }
    displayLyricsPageNotifier.addListener(closeOrReset);
  }

  @override
  void dispose() {
    displayLyricsPageNotifier.removeListener(closeOrReset);
    super.dispose();
  }

  void _resetSheet() {
    setState(() {
      _animationDuration = 300;
      dragOffset = 0.0;
    });
  }

  void _closeSheet() {
    setState(() {
      _animationDuration = 250;
      dragOffset = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _animationDuration = 0;
          dragOffset += details.delta.dy / screenHeight;
          dragOffset = dragOffset.clamp(0.0, 1.0);
        });
      },

      onVerticalDragEnd: (details) {
        double velocity = details.primaryVelocity ?? 0;

        if (dragOffset > 0.25 || velocity > 500) {
          displayLyricsPageNotifier.value = false;
        } else {
          _resetSheet();
        }
      },

      child: AnimatedContainer(
        duration: Duration(milliseconds: _animationDuration),
        curve: Curves.easeOutCubic,

        transform: Matrix4.translationValues(0, dragOffset * screenHeight, 0),
        child: content(context),
      ),
    );
  }

  Widget content(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (context, currentSong, child) {
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
                  return CoverArtWidget(
                    song: currentSong,
                    color: colorManager
                        .getSpecificLyricsPageCoverArtBaseColor(),
                  );
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
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        color: lyricsPageBackgroundBaseColor.withAlpha(180),
                      ),
                    ),
                  );
                },
              ),
              Container(
                color: lyricsPageBackgroundColor,
                child: Column(
                  children: [
                    SizedBox(height: 60),
                    Row(
                      children: [
                        SizedBox(width: 30),
                        Expanded(
                          child: Column(
                            children: [
                              SizedBox(
                                height: 30,
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
                                height: 24,
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
                            ],
                          ),
                        ),
                        SizedBox(width: 30),
                      ],
                    ),
                    SizedBox(height: 10),

                    Expanded(
                      child: PageView(
                        children: [
                          artPage(context, currentSong),
                          expandedLyricsPage(context, currentSong),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget artPage(BuildContext context, MyAudioMetadata? currentSong) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        ValueListenableBuilder(
          valueListenable: updateColorNotifier,
          builder: (context, value, child) {
            return CoverArtWidget(
              size: mobileWidth * 0.84,
              borderRadius: mobileWidth * 0.04,
              song: currentSong,
              elevation: 15,
              color: colorManager.getSpecificLyricsPageCoverArtBaseColor(),
            );
          },
        ),

        const SizedBox(height: 30),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent, // fade out at top
                    Colors.grey.shade50, // fully visible
                    Colors.grey.shade50, // fully visible
                    Colors.transparent, // fade out at bottom
                  ],
                  stops: [0.0, 0.1, 0.8, 1.0], // adjust fade height
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              // use key to force update
              child: currentSong == null
                  ? SizedBox()
                  : LyricsListView(
                      key: ValueKey(currentSong),
                      expanded: false,
                      lyrics: currentSong.parsedLyrics!.lyrics,
                      isKaraoke: currentSong.parsedLyrics!.isKaraoke,
                    ),
            ),
          ),
        ),

        Row(
          children: [
            SizedBox(width: 25),
            FavoriteButton(),
            Spacer(),
            IconButton(
              color: lyricsPageForegroundColor,
              onPressed: () {
                lyricsFontSizeOffset += 2;
                lyricsFontSizeOffsetChangeNotifier.value++;
                settingManager.saveSetting();
              },
              icon: Icon(Icons.text_increase_rounded),
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
              icon: Icon(Icons.text_decrease_rounded),
            ),

            IconButton(
              onPressed: () {
                tryVibrate();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) {
                    return MySheet(
                      Column(
                        children: [
                          SizedBox(height: 5),

                          ListTile(
                            leading: CoverArtWidget(
                              size: 50,
                              borderRadius: 5,
                              song: currentSong,
                            ),
                            title: Text(
                              getTitle(currentSong),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: lyricsPageForegroundColor,
                              ),
                            ),
                            subtitle: Text(
                              "${getArtist(currentSong)} - ${getAlbum(currentSong)}",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: lyricsPageForegroundColor,
                              ),
                            ),
                          ),

                          SizedBox(height: 5),
                          Divider(
                            color: lyricsPageDividerColor,
                            thickness: 0.5,
                            height: 1,
                          ),
                          SizedBox(height: 5),

                          Expanded(
                            child: ListView(
                              physics: const ClampingScrollPhysics(),
                              children: [
                                ListTile(
                                  leading: Icon(
                                    Icons.add_rounded,
                                    color: lyricsPageForegroundColor,
                                  ),
                                  title: Text(
                                    l10n.add2Playlist,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: lyricsPageForegroundColor,
                                    ),
                                  ),
                                  visualDensity: const VisualDensity(
                                    horizontal: 0,
                                    vertical: -4,
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);

                                    showAddPlaylistSheet(context, [
                                      currentSong!,
                                    ]);
                                  },
                                ),
                                sleepTimerListTile(context, l10n, false),
                                pauseAfterCTListTile(context, l10n),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              icon: Icon(Icons.more_vert, color: lyricsPageForegroundColor),
            ),
            SizedBox(width: 25),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: SeekBar(
            color: lyricsPageForegroundColor,
            widgetHeight: 60,
            seekBarHeight: 40,
          ),
        ),

        // -------- Play Controls --------
        Row(
          children: [
            SizedBox(width: 25),

            playModeButton(32, iconColor: lyricsPageForegroundColor),

            Spacer(),

            skip2PreviousButton(32, iconColor: lyricsPageForegroundColor),

            Spacer(),

            playOrPauseButton(50, iconColor: lyricsPageForegroundColor),

            Spacer(),

            skip2NextButton(32, iconColor: lyricsPageForegroundColor),

            Spacer(),

            IconButton(
              color: lyricsPageForegroundColor,

              icon: const ImageIcon(playQueueImage, size: 32),

              onPressed: () {
                tryVibrate();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) {
                    return PlayQueueSheet();
                  },
                );
              },
            ),
            SizedBox(width: 25),
          ],
        ),

        SizedBox(height: 40),
      ],
    );
  }

  Widget expandedLyricsPage(
    BuildContext context,
    MyAudioMetadata? currentSong,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent, // fade out at top
                        Colors.grey.shade50, // fully visible
                        Colors.grey.shade50, // fully visible
                        Colors.transparent, // fade out at bottom
                      ],
                      stops: [0.0, 0.1, 0.7, 1.0], // adjust fade height
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: currentSong == null
                      ? SizedBox()
                      : LyricsListView(
                          key: ValueKey(currentSong),
                          expanded: true,
                          lyrics: currentSong.parsedLyrics!.lyrics,
                          isKaraoke: currentSong.parsedLyrics!.isKaraoke,
                        ),
                ),
              ),
              SizedBox(height: 50),
            ],
          ),
        ),
        Column(
          children: [
            Spacer(),
            IconButton(
              color: lyricsPageForegroundColor,
              icon: ValueListenableBuilder(
                valueListenable: isPlayingNotifier,
                builder: (_, isPlaying, _) {
                  return Icon(
                    isPlaying
                        ? Icons.pause_circle_rounded
                        : Icons.play_circle_rounded,
                    size: 48,
                  );
                },
              ),
              onPressed: () => audioHandler.togglePlay(),
            ),
            SizedBox(height: 30),
          ],
        ),
        SizedBox(width: 20),
      ],
    );
  }
}

class FavoriteButton extends StatelessWidget {
  final double? size;
  const FavoriteButton({super.key, this.size});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (_, currentSong, _) {
        if (currentSong == null) return SizedBox();
        return ValueListenableBuilder(
          valueListenable: currentSong.isFavoriteNotifier,
          builder: (_, value, _) {
            return IconButton(
              onPressed: () {
                tryVibrate();
                toggleFavoriteState(currentSong);
              },
              icon: Icon(
                value ? Icons.favorite : Icons.favorite_outline,
                color: value ? Colors.red : lyricsPageForegroundColor,
                size: size,
              ),
            );
          },
        );
      },
    );
  }
}
