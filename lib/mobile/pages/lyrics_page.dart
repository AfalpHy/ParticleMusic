import 'dart:ui';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/lyrics.dart';
import 'package:particle_music/mobile/play_queue_sheet.dart';
import 'package:particle_music/playlists.dart';
import 'package:smooth_corner/smooth_corner.dart';

final ValueNotifier<bool> filterBackgroundNotifier = ValueNotifier(true);

class LyricsPage extends StatelessWidget {
  const LyricsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (context, currentSong, child) {
        return Material(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CoverArtWidget(source: getCoverArt(currentSong)),
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: ValueListenableBuilder(
                    valueListenable: filterBackgroundNotifier,
                    builder: (context, value, child) {
                      return value
                          ? Container(
                              color: artAverageColor.withAlpha(
                                128,
                              ), // semi-transparent tint
                            )
                          : Container(
                              color: artAverageColor, // semi-transparent tint
                            );
                    },
                  ),
                ),
              ),
              Column(
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
                              child: MyAutoSizeText(
                                getTitle(currentSong),
                                maxLines: 1,
                                textStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),

                            SizedBox(
                              height: 24,
                              child: MyAutoSizeText(
                                getArtist(currentSong),
                                maxLines: 1,
                                textStyle: TextStyle(fontSize: 14),
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
            ],
          ),
        );
      },
    );
  }

  Widget artPage(BuildContext context, AudioMetadata? currentSong) {
    return Column(
      children: [
        Material(
          elevation: 15,
          shape: SmoothRectangleBorder(
            smoothness: 1,
            borderRadius: BorderRadius.circular(appWidth * 0.04),
          ),
          child: CoverArtWidget(
            size: appWidth * 0.84,
            borderRadius: appWidth * 0.04,
            source: getCoverArt(currentSong),
          ),
        ),

        const SizedBox(height: 30),

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
                stops: [0.0, 0.1, 0.8, 1.0], // adjust fade height
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            // use key to force update
            child: LyricsListView(key: ValueKey(currentSong), expanded: false),
          ),
        ),

        Row(
          children: [
            SizedBox(width: 25),
            IconButton(
              onPressed: () {
                filterBackgroundNotifier.value =
                    !filterBackgroundNotifier.value;
              },
              icon: Icon(Icons.filter, color: Colors.black),
            ),
            Spacer(),

            FavoriteButton(),
            IconButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) {
                    return mySheet(
                      Column(
                        children: [
                          ListTile(
                            leading: CoverArtWidget(
                              size: 50,
                              borderRadius: 5,
                              source: getCoverArt(currentSong),
                            ),
                            title: Text(
                              getTitle(currentSong),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              "${getArtist(currentSong)} - ${getAlbum(currentSong)}",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          Divider(
                            color: Colors.grey.shade300,
                            thickness: 0.5,
                            height: 1,
                          ),

                          Expanded(
                            child: ListView(
                              physics: const ClampingScrollPhysics(),
                              children: [
                                ListTile(
                                  leading: const ImageIcon(
                                    playlistAddImage,
                                    color: Colors.black,
                                  ),
                                  title: Text(
                                    'Add to Playlists',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  visualDensity: const VisualDensity(
                                    horizontal: 0,
                                    vertical: -4,
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);

                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) {
                                        return PlaylistsSheet(
                                          songs: [currentSong!],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              icon: Icon(Icons.more_vert, color: Colors.black),
            ),
            SizedBox(width: 25),
          ],
        ),
        SeekBar(),

        // -------- Play Controls --------
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 10, 40),

          child: Row(
            children: [
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: playModeNotifier,
                  builder: (_, playMode, _) {
                    return IconButton(
                      color: Colors.black,
                      icon: ImageIcon(
                        playMode == 0
                            ? loopImage
                            : playMode == 1
                            ? shuffleImage
                            : repeatImage,
                        size: 32,
                      ),
                      onPressed: () {
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
              ),

              Expanded(
                child: IconButton(
                  color: Colors.black,
                  icon: const ImageIcon(previousButtonImage, size: 32),
                  onPressed: audioHandler.skipToPrevious,
                ),
              ),
              Expanded(
                child: IconButton(
                  color: Colors.black,
                  icon: ValueListenableBuilder(
                    valueListenable: isPlayingNotifier,
                    builder: (_, isPlaying, _) {
                      return Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 50,
                      );
                    },
                  ),
                  onPressed: () => audioHandler.togglePlay(),
                ),
              ),
              Expanded(
                child: IconButton(
                  color: Colors.black,
                  icon: const ImageIcon(nextButtonImage, size: 32),
                  onPressed: audioHandler.skipToNext,
                ),
              ),
              Expanded(
                child: IconButton(
                  icon: Icon(
                    Icons.playlist_play_rounded,
                    size: 32,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) {
                        return PlayQueueSheet();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget expandedLyricsPage(BuildContext context, AudioMetadata? currentSong) {
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
                        Colors.black, // fully visible
                        Colors.black, // fully visible
                        Colors.transparent, // fade out at bottom
                      ],
                      stops: [0.0, 0.1, 0.7, 1.0], // adjust fade height
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: LyricsListView(
                    key: ValueKey(currentSong),
                    expanded: true,
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
              color: Colors.black,
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
        final isFavorite = songIsFavorite[currentSong]!;
        return ValueListenableBuilder(
          valueListenable: isFavorite,
          builder: (_, value, _) {
            return IconButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                toggleFavoriteState(currentSong);
              },
              icon: Icon(
                isFavorite.value ? Icons.favorite : Icons.favorite_outline,
                color: isFavorite.value ? Colors.red : Colors.black,
                size: size,
              ),
            );
          },
        );
      },
    );
  }
}

class SeekBar extends StatefulWidget {
  const SeekBar({super.key});
  @override
  State<SeekBar> createState() => SeekBarState();
}

class SeekBarState extends State<SeekBar> {
  double? dragValue;
  bool isDragging = false; // track if user is touching the thumb

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final duration = currentSongNotifier.value?.duration ?? Duration.zero;
    final durationMs = duration.inMilliseconds.toDouble();

    return StreamBuilder<Duration>(
      stream: audioHandler.getPositionStream(),
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final sliderValue = dragValue ?? position.inMilliseconds.toDouble();

        return SizedBox(
          height: 60, // expand gesture area for easier touch
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Duration labels
              Positioned(
                left: 30,
                right: 30,
                bottom: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatDuration(
                        Duration(milliseconds: sliderValue.toInt()),
                      ),
                    ),
                    Text(formatDuration(duration)),
                  ],
                ),
              ),

              // Slider visuals
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbColor: Colors.black,
                  trackHeight: isDragging ? 4 : 2,
                  trackShape: const FullWidthTrackShape(),
                  thumbShape: isDragging
                      ? RoundSliderThumbShape(enabledThumbRadius: 8)
                      : RoundSliderThumbShape(enabledThumbRadius: 4),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: Colors.black,
                  inactiveTrackColor: Colors.black12,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Slider(
                    min: 0.0,
                    max: durationMs,
                    value: sliderValue.clamp(0.0, durationMs),
                    onChanged: (value) {},
                  ),
                ),
              ),

              // Full-track GestureDetector to capture touches anywhere on the track
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: (_) {
                    setState(() => isDragging = false);
                  },
                  onTapDown: (_) {
                    setState(() => isDragging = true);
                  },
                  onHorizontalDragUpdate: (details) {
                    seekByTouch(details.localPosition.dx, context, durationMs);
                    setState(() {});
                  },
                  onHorizontalDragEnd: (_) async {
                    await audioHandler.seek(
                      Duration(milliseconds: dragValue!.toInt()),
                    );
                    setState(() {
                      dragValue = null;
                      isDragging = false;
                    });
                  },
                  onTapUp: (details) async {
                    seekByTouch(details.localPosition.dx, context, durationMs);
                    await audioHandler.seek(
                      Duration(milliseconds: dragValue!.toInt()),
                    );
                    setState(() {
                      dragValue = null;
                      isDragging = false;
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Map horizontal touch to slider value
  void seekByTouch(double dx, BuildContext context, double durationMs) {
    final box = context.findRenderObject() as RenderBox;

    double relative = (dx - 30) / (box.size.width - 60);
    relative = relative.clamp(0.0, 1.0);
    dragValue = relative * durationMs;
  }
}

/// Full-width rounded track
class FullWidthTrackShape extends SliderTrackShape {
  const FullWidthTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4.0;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackLeft = offset.dx;
    final trackWidth = parentBox.size.width;

    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final radius = Radius.circular(trackRect.height / 2);

    final activeTrackRect = RRect.fromLTRBR(
      trackRect.left,
      trackRect.top,
      thumbCenter.dx,
      trackRect.bottom,
      radius,
    );

    final inactiveTrackRect = RRect.fromLTRBR(
      thumbCenter.dx,
      trackRect.top,
      trackRect.right,
      trackRect.bottom,
      radius,
    );

    final activePaint = Paint()
      ..color = sliderTheme.activeTrackColor!
      ..style = PaintingStyle.fill;

    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor!
      ..style = PaintingStyle.fill;

    context.canvas.drawRRect(activeTrackRect, activePaint);
    context.canvas.drawRRect(inactiveTrackRect, inactivePaint);
  }
}
