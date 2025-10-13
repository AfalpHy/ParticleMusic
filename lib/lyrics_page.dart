import 'dart:ui';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'audio_handler.dart';
import 'play_queue_sheet.dart';
import 'art_widget.dart';
import 'playlists.dart';
import 'common.dart';

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
              ArtWidget(
                source: currentSong != null && currentSong.pictures.isNotEmpty
                    ? currentSong.pictures.first
                    : null,
              ),
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    color: artAverageColor.withAlpha(
                      128,
                    ), // semi-transparent tint
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
                                currentSong?.title ?? 'Unknown Title',
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
                                currentSong?.artist ?? 'Unknown Artist',
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
          child: ArtWidget(
            size: appWidth * 0.84,
            borderRadius: appWidth * 0.04,
            source: currentSong != null && currentSong.pictures.isNotEmpty
                ? currentSong.pictures.first
                : null,
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
                            leading: ArtWidget(
                              size: 50,
                              borderRadius: 5,
                              source: currentSong!.pictures.isNotEmpty
                                  ? currentSong.pictures.first
                                  : null,
                            ),
                            title: Text(
                              currentSong.title ?? "Unknown Title",
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              "${currentSong.artist ?? "Unknown Artist"} - ${currentSong.album ?? "Unknown Album"}",
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
                                  leading: Icon(
                                    Icons.playlist_add_rounded,
                                    size: 25,
                                  ),
                                  title: Text(
                                    'Add to Playlists',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
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
                                          songs: [currentSong],
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
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 40),

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
                            ? AssetImage("assets/images/loop.png")
                            : playMode == 1
                            ? AssetImage("assets/images/shuffle.png")
                            : AssetImage("assets/images/repeat.png"),
                        size: 35,
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
                  icon: const ImageIcon(
                    AssetImage("assets/images/previous_button.png"),
                    size: 35,
                  ),
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
                        size: 48,
                      );
                    },
                  ),
                  onPressed: () async => audioHandler.player.playing
                      ? await audioHandler.pause()
                      : await audioHandler.play(),
                ),
              ),
              Expanded(
                child: IconButton(
                  color: Colors.black,
                  icon: const ImageIcon(
                    AssetImage("assets/images/next_button.png"),
                    size: 35,
                  ),
                  onPressed: audioHandler.skipToNext,
                ),
              ),
              Expanded(
                child: IconButton(
                  icon: Icon(
                    Icons.playlist_play_rounded,
                    size: 35,
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
              onPressed: () async => audioHandler.player.playing
                  ? await audioHandler.pause()
                  : await audioHandler.play(),
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

class LyricsListView extends StatefulWidget {
  final bool expanded;
  const LyricsListView({super.key, required this.expanded});

  @override
  State<LyricsListView> createState() => LyricsListViewState();
}

class LyricsListViewState extends State<LyricsListView>
    with WidgetsBindingObserver {
  final ItemScrollController itemScrollController = ItemScrollController();
  final ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(-1);
  StreamSubscription<Duration>? positionSub;
  bool userDragging = false;
  bool userDragged = false;

  bool jump = true;
  Timer? timer;

  void scroll2CurrentIndex(Duration position) {
    if (audioHandler.player.processingState != ProcessingState.ready) {
      return;
    }
    int tmp = currentIndexNotifier.value;
    int current = lyrics.lastIndexWhere((line) => position >= line.timestamp);
    currentIndexNotifier.value = current;

    if (!userDragging && (tmp != current || userDragged)) {
      userDragged = false;
      if (jump) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          itemScrollController.jumpTo(
            index: current + 1,
            alignment: widget.expanded ? 0.35 : 0.4,
          );
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          itemScrollController.scrollTo(
            index: current + 1,
            duration: Duration(milliseconds: 300), // smooth animation
            curve: Curves.linear,
            alignment: widget.expanded ? 0.35 : 0.4,
          );
        });
      }
    }
    jump = false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    positionSub = audioHandler.player.positionStream.listen(
      (position) => scroll2CurrentIndex(position),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop listening when lyrics page is closed
    positionSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (positionSub == null) {
          jump = true;
          positionSub = audioHandler.player.positionStream.listen(
            (position) => scroll2CurrentIndex(position),
          );
        }
        break;
      case AppLifecycleState.paused:
        positionSub?.cancel();
        positionSub = null;
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentHeight = constraints.maxHeight; // height of the parent
        return NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction != ScrollDirection.idle) {
              userDragging = true;
              if (timer != null) {
                timer!.cancel();
                timer = null;
              }
            } else {
              timer ??= Timer(const Duration(milliseconds: 1000), () {
                userDragging = false;
                userDragged = true;
                timer = null;
              });
            }
            return false;
          },
          child: ScrollablePositionedList.builder(
            physics: ClampingScrollPhysics(),
            itemCount: lyrics.length + 2,
            itemScrollController: itemScrollController,
            itemBuilder: (context, index) {
              if (index == 0) {
                return SizedBox(
                  height: widget.expanded ? parentHeight / 3 : parentHeight / 2,
                );
              } else if (index == lyrics.length + 1) {
                return SizedBox(
                  height: widget.expanded
                      ? parentHeight / 1.5
                      : parentHeight / 2,
                );
              }
              return LyricLineWidget(
                text: lyrics[index - 1].text,
                index: index - 1,
                currentIndexNotifier: currentIndexNotifier,
                expanded: widget.expanded,
              );
            },
          ),
        );
      },
    );
  }
}

/// Each lyric line listens to currentIndexNotifier
class LyricLineWidget extends StatelessWidget {
  final String text;
  final int index;
  final ValueNotifier<int> currentIndexNotifier;
  final bool expanded;

  const LyricLineWidget({
    super.key,
    required this.text,
    required this.index,
    required this.currentIndexNotifier,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: expanded
          ? const EdgeInsets.fromLTRB(30, 10, 0, 10)
          : const EdgeInsets.symmetric(vertical: 5, horizontal: 50),
      child: InkWell(
        onTap: () {
          audioHandler.seek(lyrics[index].timestamp);
        },
        child: ValueListenableBuilder(
          valueListenable: currentIndexNotifier,
          builder: (context, value, child) {
            return Text(
              text,
              textAlign: expanded ? TextAlign.left : TextAlign.center,
              style: TextStyle(
                fontSize: value == index
                    ? (expanded ? 24 : 20)
                    : (expanded ? 20 : 16),
                fontWeight: value == index
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: value == index
                    ? Colors.black
                    : const Color.fromARGB(128, 0, 0, 0),
              ),
            );
          },
        ),
      ),
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
    return StreamBuilder<Duration?>(
      stream: audioHandler.player.durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        final durationMs = duration.inMilliseconds.toDouble();

        return StreamBuilder<Duration>(
          stream: audioHandler.player.positionStream,
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
                        seekByTouch(
                          details.localPosition.dx,
                          context,
                          durationMs,
                        );
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
                        seekByTouch(
                          details.localPosition.dx,
                          context,
                          durationMs,
                        );
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
