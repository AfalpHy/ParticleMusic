import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common_widgets/seekbar.dart';
import 'package:particle_music/desktop/desktop_lyrics.dart';
import 'package:particle_music/desktop/pages/play_queue_page.dart';
import 'package:particle_music/full_width_track_shape.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/lyrics.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';
import 'package:window_manager/window_manager.dart';

final _lyricsOrPlayQueueNotifier = ValueNotifier(true);

class MiniModePage extends StatelessWidget {
  final displayCoverNotifier = ValueNotifier(true);

  MiniModePage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.widthOf(context);
    final height = MediaQuery.heightOf(context);
    if (height > 150) {
      displayCoverNotifier.value = true;
    } else {
      displayCoverNotifier.value = false;
    }
    return Column(
      children: [
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: currentSongNotifier,
            builder: (context, value, child) {
              return Material(
                color: currentCoverArtColor,
                child: ValueListenableBuilder(
                  valueListenable: displayCoverNotifier,
                  builder: (context, displayCover, child) {
                    if (displayCover) {
                      return coverView();
                    }
                    return listTileView(context);
                  },
                ),
              );
            },
          ),
        ),
        if (height > width)
          Material(
            color: Colors.grey,
            child: SizedBox(
              width: width,
              height: height - width,
              child: Stack(
                children: [
                  ValueListenableBuilder(
                    valueListenable: currentSongNotifier,
                    builder: (context, value, child) {
                      return Container(
                        color: currentCoverArtColor.withAlpha(180),
                      );
                    },
                  ),

                  ValueListenableBuilder(
                    valueListenable: _lyricsOrPlayQueueNotifier,
                    builder: (context, value, child) {
                      if (value) {
                        return ValueListenableBuilder(
                          valueListenable: currentSongNotifier,
                          builder: (context, currentSong, child) {
                            return ScrollConfiguration(
                              behavior: ScrollConfiguration.of(
                                context,
                              ).copyWith(scrollbars: false),
                              child: currentSong == null
                                  ? SizedBox()
                                  : LyricsListView(
                                      key: ValueKey(currentSong),
                                      expanded: false,
                                      lyrics: currentSong.parsedLyrics!.lyrics,
                                      isKaraoke:
                                          currentSong.parsedLyrics!.isKaraoke,
                                    ),
                            );
                          },
                        );
                      }
                      return height - width > 60 ? PlayQueuePage() : SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget coverView() {
    bool isDragging = false;
    final displayOthersNotifier = ValueNotifier(true);
    Timer? timer = Timer(const Duration(milliseconds: 1000), () {
      displayOthersNotifier.value = false;
    });
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) async {
        isDragging = true;
        await windowManager.startDragging();
        isDragging = false;
      },

      child: MouseRegion(
        onEnter: (event) {
          displayOthersNotifier.value = true;
          timer?.cancel();
          timer = null;
        },
        onExit: (event) async {
          if (isDragging) {
            return;
          }
          timer ??= Timer(const Duration(milliseconds: 1000), () {
            displayOthersNotifier.value = false;
          });
        },
        child: ValueListenableBuilder(
          valueListenable: currentSongNotifier,
          builder: (context, currentSong, child) {
            return ValueListenableBuilder(
              valueListenable: displayOthersNotifier,
              builder: (context, displayOthers, child) {
                if (!displayOthers) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [CoverArtWidget(song: currentSong)],
                  );
                }
                return Stack(
                  fit: StackFit.expand,

                  children: [
                    CoverArtWidget(song: currentSong),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 50,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  currentCoverArtColor.withAlpha(0),

                                  currentCoverArtColor.withAlpha(180),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 135,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  currentCoverArtColor.withAlpha(0),
                                  currentCoverArtColor.withAlpha(180),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    topControls(),
                    centerListTile(currentSong),
                    seekBar(),
                    bottomControls(context),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget listTileView(BuildContext context) {
    bool isDragging = false;
    final displayTopControlsNotifier = ValueNotifier(true);
    Timer? timer;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) async {
        isDragging = true;
        await windowManager.startDragging();
        isDragging = false;
      },

      child: MouseRegion(
        onEnter: (event) {
          displayTopControlsNotifier.value = true;
          timer?.cancel();
          timer = null;
        },
        onExit: (event) async {
          if (isDragging) {
            return;
          }
          timer ??= Timer(const Duration(milliseconds: 1000), () {
            displayTopControlsNotifier.value = false;
          });
        },
        child: Stack(
          children: [
            ValueListenableBuilder(
              valueListenable: displayTopControlsNotifier,
              builder: (context, value, child) {
                if (value) {
                  return topControls();
                }
                return ValueListenableBuilder(
                  valueListenable: currentSongNotifier,
                  builder: (context, currentSong, child) {
                    return topListTile(currentSong);
                  },
                );
              },
            ),

            seekBar(),
            bottomControls(context),
          ],
        ),
      ),
    );
  }

  Widget topControls() {
    return Positioned(
      top: 5,
      left: 10,
      right: 10,
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.volume_down, color: Colors.grey.shade50),
          ),
          SizedBox(
            height: 20,
            width: 120,
            child: ValueListenableBuilder(
              valueListenable: volumeNotifier,
              builder: (context, value, child) {
                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    trackShape: const FullWidthTrackShape(),
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 0),
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
                    onChangeEnd: (value) {
                      audioHandler.savePlayState();
                    },
                  ),
                );
              },
            ),
          ),
          Spacer(),
          IconButton(
            onPressed: () async {
              await windowManager.hide();

              if (!Platform.isLinux) {
                await windowManager.resetMaximumSize();
              }
              if (Platform.isWindows) {
                await windowManager.setMinimumSize(Size(1050 + 16, 700 + 9));
                await windowManager.setSize(Size(1050 + 16, 700 + 9));
              } else {
                await windowManager.setMinimumSize(Size(1050, 700));
                await windowManager.setSize(Size(1050, 700));
              }
              miniModeNotifier.value = false;
              await Future.delayed(Duration(milliseconds: 200));
              await windowManager.show();
            },
            icon: ImageIcon(miniModeImage, color: Colors.grey.shade50),
          ),
          IconButton(
            onPressed: () {
              windowManager.minimize();
            },
            icon: ImageIcon(minimizeImage, color: Colors.grey.shade50),
          ),

          IconButton(
            onPressed: () {
              windowManager.close();
            },
            icon: ImageIcon(closeImage, color: Colors.grey.shade50),
          ),
        ],
      ),
    );
  }

  Widget topListTile(MyAudioMetadata? currentSong) {
    return Positioned(
      top: 5,
      left: 0,
      right: 0,
      child: ListTile(
        leading: CoverArtWidget(song: currentSong, size: 40, borderRadius: 4),
        title: Text(
          getTitle(currentSong),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            overflow: .ellipsis,
            color: Colors.grey.shade50,
          ),
        ),
        subtitle: Text(
          "${getArtist(currentSong)} - ${getAlbum(currentSong)}",
          style: TextStyle(
            fontSize: 12,
            overflow: .ellipsis,
            color: Colors.grey.shade50,
          ),
        ),
      ),
    );
  }

  Widget centerListTile(MyAudioMetadata? currentSong) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 70,
      child: ListTile(
        title: Text(
          getTitle(currentSong),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            overflow: .ellipsis,
            color: Colors.grey.shade50,
          ),
        ),
        subtitle: Text(
          "${getArtist(currentSong)} - ${getAlbum(currentSong)}",
          style: TextStyle(
            fontSize: 12,
            overflow: .ellipsis,
            color: Colors.grey.shade50,
          ),
        ),
      ),
    );
  }

  Widget seekBar() {
    return Positioned(
      bottom: 45,
      left: 15,
      right: 15,
      child: SeekBar(
        light: true,
        isMiniMode: true,
        widgetHeight: 50,
        seekBarHeight: 10,
      ),
    );
  }

  Widget bottomControls(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Positioned(
      bottom: 0,
      left: 10,
      right: 10,
      child: Row(
        children: [
          Spacer(),
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
                        showCenterMessage(context, l10n.loop);
                        break;
                      default:
                        showCenterMessage(context, l10n.shuffle);
                        break;
                    }
                  }
                },
                onLongPress: () {
                  audioHandler.toggleRepeat();
                  switch (playModeNotifier.value) {
                    case 0:
                      showCenterMessage(context, l10n.loop);
                      break;
                    case 1:
                      showCenterMessage(context, l10n.shuffle);
                      break;
                    default:
                      showCenterMessage(context, l10n.repeat);
                      break;
                  }
                },
              );
            },
          ),
          Spacer(),

          IconButton(
            onPressed: () async {
              _lyricsOrPlayQueueNotifier.value = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                final size = await windowManager.getSize();
                if (size.height <= size.width) {
                  windowManager.setSize(Size(size.width, size.width + 300));
                }
              });
            },
            icon: ImageIcon(lyricsImage),
            color: Colors.grey.shade50,
          ),
          Spacer(),

          IconButton(
            color: Colors.grey.shade50,
            icon: const ImageIcon(previousButtonImage, size: 25),
            onPressed: () {
              audioHandler.skipToPrevious();
            },
          ),
          Spacer(),

          IconButton(
            color: Colors.grey.shade50,
            icon: ValueListenableBuilder(
              valueListenable: isPlayingNotifier,
              builder: (_, isPlaying, _) {
                return Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 35,
                );
              },
            ),
            onPressed: () {
              audioHandler.togglePlay();
            },
          ),
          Spacer(),

          IconButton(
            color: Colors.grey.shade50,
            icon: const ImageIcon(nextButtonImage, size: 25),
            onPressed: () {
              audioHandler.skipToNext();
            },
          ),
          Spacer(),

          IconButton(
            onPressed: () async {
              _lyricsOrPlayQueueNotifier.value = false;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                final size = await windowManager.getSize();
                if (size.height <= size.width) {
                  if (Platform.isWindows) {
                    windowManager.setSize(
                      Size(size.width, size.width + 316 - 7),
                    );
                  } else {
                    windowManager.setSize(Size(size.width, size.width + 316));
                  }
                }
              });
            },
            icon: Icon(Icons.playlist_play_rounded, size: 25),
            color: Colors.grey.shade50,
          ),
          Spacer(),

          IconButton(
            onPressed: () async {
              if (lyricsWindowVisible) {
                await lyricsWindowController!.hide();
              } else {
                await updateDesktopLyrics();
                await lyricsWindowController!.show();
              }
              lyricsWindowVisible = !lyricsWindowVisible;
            },
            icon: Icon(Icons.lyrics_rounded, size: 20),
            color: Colors.grey.shade50,
          ),
          Spacer(),
        ],
      ),
    );
  }
}
