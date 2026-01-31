import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common_widgets/seekbar.dart';
import 'package:particle_music/desktop/desktop_lyrics.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';
import 'package:window_manager/window_manager.dart';

class MiniModePage extends StatelessWidget {
  final displayCoverNotifier = ValueNotifier(true);

  MiniModePage({super.key});
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.heightOf(context);

    if (height > 150) {
      displayCoverNotifier.value = true;
    } else {
      displayCoverNotifier.value = false;
    }
    return ValueListenableBuilder(
      valueListenable: displayCoverNotifier,
      builder: (context, value, child) {
        if (value) {
          return coverView();
        }
        return listTileView(context);
      },
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
                  return CoverArtWidget(song: currentSong);
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
                      height: 100,
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
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) => windowManager.startDragging(),

          child: ValueListenableBuilder(
            valueListenable: currentSongNotifier,
            builder: (context, currentSong, _) {
              return Material(
                color: currentCoverArtColor,
                child: Column(children: [topListTile(currentSong)]),
              );
            },
          ),
        ),

        topControls(),

        seekBar(),
        bottomControls(context),
      ],
    );
  }

  Widget topControls() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Spacer(),
          IconButton(
            onPressed: () async {
              await windowManager.hide();

              await windowManager.setMinimumSize(Size(1050, 700));
              await windowManager.resetMaximumSize();
              await windowManager.setResizable(true);
              await windowManager.setSize(Size(1050, 700));
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
    return ListTile(
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
    );
  }

  Widget centerListTile(MyAudioMetadata? currentSong) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 80,
      child: Material(
        color: Colors.transparent,
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
      ),
    );
  }

  Widget seekBar() {
    return Positioned(
      bottom: 45,
      left: 15,
      right: 15,
      child: Material(
        color: Colors.transparent,
        child: SeekBar(
          light: true,
          isMiniMode: true,
          widgetHeight: 50,
          seekBarHeight: 10,
        ),
      ),
    );
  }

  Widget bottomControls(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Positioned(
      bottom: 0,
      left: 15,
      right: 15,
      child: Material(
        color: Colors.transparent,
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
              color: Colors.grey.shade50,
              icon: const ImageIcon(previousButtonImage, size: 25),
              onPressed: () {
                audioHandler.skipToPrevious();
              },
            ),

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
          ],
        ),
      ),
    );
  }
}
