import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';

class SeekBar extends StatefulWidget {
  const SeekBar({super.key});
  @override
  State<SeekBar> createState() => SeekBarState();
}

class SeekBarState extends State<SeekBar> {
  double? dragValue;
  bool isDragging = false; // track if user is touching the thumb
  final double horizontalPadding = isMobile ? 30 : 45;

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
          height: isMobile ? 60 : 10, // expand gesture area for easier touch
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Duration labels
              Positioned(
                left: isMobile ? horizontalPadding : 0,
                right: isMobile ? horizontalPadding : 0,
                bottom: isMobile ? 0 : 2,
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
                      ? RoundSliderThumbShape(enabledThumbRadius: 4)
                      : RoundSliderThumbShape(enabledThumbRadius: 0),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: Colors.black,
                  inactiveTrackColor: Colors.black12,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
                    if (currentSongNotifier.value == null) {
                      return;
                    }
                    setState(() => isDragging = true);
                  },
                  onHorizontalDragUpdate: (details) {
                    if (currentSongNotifier.value == null) {
                      return;
                    }
                    seekByTouch(details.localPosition.dx, context, durationMs);
                    setState(() {
                      isDragging = true;
                    });
                  },
                  onHorizontalDragEnd: (_) async {
                    if (currentSongNotifier.value == null) {
                      return;
                    }
                    await audioHandler.seek(
                      Duration(milliseconds: dragValue!.toInt()),
                    );
                    setState(() {
                      dragValue = null;
                      isDragging = false;
                    });
                  },
                  onTapUp: (details) async {
                    if (currentSongNotifier.value == null) {
                      return;
                    }
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

    double relative =
        (dx - horizontalPadding) / (box.size.width - horizontalPadding * 2);
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
