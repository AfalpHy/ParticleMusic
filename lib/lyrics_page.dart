import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:marquee/marquee.dart';
import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'audio_handler.dart';
import 'play_queue_page.dart';
import 'art_widget.dart';
import 'playlists.dart';

class LyricsPage extends StatelessWidget {
  const LyricsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (_, currentSong, _) {
        return Scaffold(
          backgroundColor: artAverageColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: artAverageColor,
            scrolledUnderElevation: 0,
            title: currentSong == null
                ? null
                : Center(
                    child: Column(
                      children: [
                        AutoSizeText(
                          currentSong.title ?? 'Unknown Title',
                          maxLines: 1,
                          maxFontSize: 20,
                          style: TextStyle(fontWeight: FontWeight.bold),
                          overflowReplacement: SizedBox(
                            height: kToolbarHeight / 2, // finite height
                            width: double
                                .infinity, // takes whatever width AppBar gives
                            child: Marquee(
                              text: currentSong.title ?? 'Unknown Title',
                              scrollAxis: Axis.horizontal,
                              style: TextStyle(fontWeight: FontWeight.bold),
                              blankSpace: 20,
                              velocity: 30.0,
                              pauseAfterRound: const Duration(seconds: 1),
                              accelerationDuration: const Duration(
                                milliseconds: 500,
                              ),
                              accelerationCurve: Curves.linear,
                              decelerationDuration: const Duration(
                                milliseconds: 500,
                              ),
                              decelerationCurve: Curves.linear,
                            ),
                          ),
                        ),
                        AutoSizeText(
                          currentSong.artist ?? 'Unknown Artist',
                          maxLines: 1,
                          maxFontSize: 14,
                          overflowReplacement: SizedBox(
                            height: kToolbarHeight / 2, // finite height
                            width: double
                                .infinity, // takes whatever width AppBar gives
                            child: Marquee(
                              text: currentSong.artist ?? 'Unknown Artist',
                              scrollAxis: Axis.horizontal,
                              blankSpace: 20,
                              velocity: 30.0,
                              pauseAfterRound: const Duration(seconds: 1),
                              accelerationDuration: const Duration(
                                milliseconds: 500,
                              ),
                              accelerationCurve: Curves.linear,
                              decelerationDuration: const Duration(
                                milliseconds: 500,
                              ),
                              decelerationCurve: Curves.linear,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          body: Column(
            children: [
              const SizedBox(height: 10),
              Material(
                elevation: 15,
                color: artAverageColor,
                borderRadius: BorderRadius.circular(
                  MediaQuery.widthOf(context) * 0.84 / 20,
                ),
                child: ArtWidget(
                  size: MediaQuery.widthOf(context) * 0.84,
                  borderRadius: MediaQuery.widthOf(context) * 0.84 / 20,
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
                  child: LyricsListView(),
                ),
              ),

              Row(
                children: [
                  Spacer(),
                  FavoriteButton(),
                  SizedBox(width: 20),
                  Icon(Icons.more_vert),
                  SizedBox(width: 30),
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
                            icon: Icon(
                              playMode == 0
                                  ? Icons.loop_rounded
                                  : playMode == 1
                                  ? Icons.repeat_rounded
                                  : Icons.shuffle_rounded,
                              size: 30,
                            ),
                            onPressed: () {
                              audioHandler.switchPlayMode();
                            },
                          );
                        },
                      ),
                    ),

                    Expanded(
                      child: IconButton(
                        color: Colors.black,
                        icon: const Icon(Icons.skip_previous_rounded, size: 48),
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
                        icon: const Icon(Icons.skip_next_rounded, size: 48),
                        onPressed: audioHandler.skipToNext,
                      ),
                    ),
                    Expanded(
                      child: IconButton(
                        icon: Icon(
                          Icons.queue_music_rounded,
                          size: 30,
                          color: Colors.black,
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true, // allows full-height
                            builder: (context) {
                              return PlayQueuePage();
                            },
                          );
                        },
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
}

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key});

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
                changeFavoriteState(currentSong);
              },
              icon: Icon(
                isFavorite.value ? Icons.favorite : Icons.favorite_outline,
                color: isFavorite.value ? Colors.red : Colors.black,
              ),
            );
          },
        );
      },
    );
  }
}

class LyricsListView extends StatefulWidget {
  const LyricsListView({super.key});

  @override
  State<LyricsListView> createState() => LyricsListViewState();
}

class LyricsListViewState extends State<LyricsListView> {
  final ItemScrollController itemScrollController = ItemScrollController();
  ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(-1);
  StreamSubscription<Duration>? positionSub;
  bool userDragging = false;
  bool userDragged = false;

  Timer? timer;

  @override
  void initState() {
    super.initState();
    positionSub = audioHandler.player.positionStream.listen((position) {
      if (lyrics.isNotEmpty) {
        int tmp = currentIndexNotifier.value;
        currentIndexNotifier.value = lyrics.lastIndexWhere(
          (line) => position >= line.timestamp,
        );

        if (!userDragging &&
            currentIndexNotifier.value >= 0 &&
            (tmp != currentIndexNotifier.value || userDragged)) {
          userDragged = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              itemScrollController.scrollTo(
                index: currentIndexNotifier.value + 1,
                duration: Duration(milliseconds: 300), // smooth animation
                curve: Curves.linear,
                alignment: 0.4,
              );
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    // Stop listening when lyrics page is closed
    positionSub?.cancel();
    super.dispose();
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
              userDragged = true;
              if (timer != null) {
                timer!.cancel();
                timer = null;
              }
            } else {
              timer ??= Timer(const Duration(milliseconds: 1000), () {
                userDragging = false;
                timer = null;
              });
            }
            return false;
          },
          child: ScrollablePositionedList.builder(
            itemCount: lyrics.length + 2,
            itemScrollController: itemScrollController,
            itemBuilder: (context, index) {
              if (index == 0 || index == lyrics.length + 1) {
                return SizedBox(height: parentHeight / 2);
              }
              return LyricLineWidget(
                text: lyrics[index - 1].text,
                index: index - 1,
                currentIndexNotifier: currentIndexNotifier,
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

  const LyricLineWidget({
    super.key,
    required this.text,
    required this.index,
    required this.currentIndexNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 30),
      child: InkWell(
        borderRadius: BorderRadius.all(Radius.circular(10)),

        onTap: () {
          audioHandler.seek(lyrics[index].timestamp);
        },
        child: ValueListenableBuilder(
          valueListenable: currentIndexNotifier,
          builder: (context, value, child) {
            return Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: value == index ? 20 : 16,
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
                      inactiveTrackColor: Colors.grey.shade300,
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
                      onTapDown: (_) {
                        setState(() => isDragging = true);
                      },
                      onHorizontalDragStart: (_) {
                        setState(() => isDragging = true);
                      },
                      onHorizontalDragUpdate: (details) {
                        seekByTouch(
                          details.localPosition.dx,
                          context,
                          durationMs,
                        );
                      },
                      onHorizontalDragEnd: (_) async {
                        await audioHandler.player.seek(
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
                        await audioHandler.player.seek(
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
    setState(() {
      dragValue = relative * durationMs;
    });
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
