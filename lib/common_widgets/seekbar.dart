import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/full_width_track_shape.dart';
import 'package:particle_music/utils.dart';

class SeekBar extends StatefulWidget {
  final bool light;
  const SeekBar({super.key, this.light = false});
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
        double sliderValue = dragValue ?? position.inMilliseconds.toDouble();
        if (playQueue.isEmpty) {
          sliderValue = 0;
        }
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
                      style: TextStyle(
                        color: widget.light ? Colors.grey.shade50 : null,
                        fontSize: isMobile ? null : 12.5,
                      ),
                    ),
                    Text(
                      formatDuration(duration),
                      style: TextStyle(
                        color: widget.light ? Colors.grey.shade50 : null,
                        fontSize: isMobile ? null : 12.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Slider visuals
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbColor: widget.light ? Colors.grey.shade50 : Colors.black,
                  trackHeight: isDragging ? 4 : 2,
                  trackShape: const FullWidthTrackShape(),
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 0),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: widget.light
                      ? Colors.grey.shade50
                      : Colors.black,
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
                    if (dragValue != null) {
                      await audioHandler.seek(
                        Duration(milliseconds: dragValue!.toInt()),
                      );
                    }
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
