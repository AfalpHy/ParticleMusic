import 'package:flutter/material.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/utils/format_duration.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/widgets/full_width_track_shape.dart';

class SeekBar extends StatefulWidget {
  final Color? color;
  final bool isMiniMode;
  final double widgetHeight;
  final double seekBarHeight;

  const SeekBar({
    super.key,
    this.color,
    this.isMiniMode = false,
    required this.widgetHeight,
    required this.seekBarHeight,
  });
  @override
  State<SeekBar> createState() => SeekBarState();
}

class SeekBarState extends State<SeekBar> {
  double? dragValue;
  bool isDragging = false; // track if user is touching the thumb
  double horizontalPadding = 0;

  @override
  Widget build(BuildContext context) {
    horizontalPadding = 0;
    if (!isTooNarrow(context) && !widget.isMiniMode) {
      horizontalPadding = 45;
    }

    return StreamBuilder(
      stream: audioHandler.getDurationStream(),
      builder: (context, asyncSnapshot) {
        Duration duration = getDuration(currentSongNotifier.value);
        if (duration <= Duration.zero) {
          duration = audioHandler.getCurrentDuration();
        }
        final durationMs = duration.inMilliseconds.toDouble();

        return StreamBuilder<Duration>(
          stream: audioHandler.getPositionStream(),
          builder: (context, snapshot) {
            final position = snapshot.data ?? audioHandler.getPosition();
            double sliderValue =
                dragValue ?? position.inMilliseconds.toDouble();
            if (playQueue.isEmpty) {
              sliderValue = 0;
            }
            return SizedBox(
              height: widget.widgetHeight,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Duration labels
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: isMobile ? 0 : 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatDuration(
                            Duration(milliseconds: sliderValue.toInt()),
                          ),
                          style: TextStyle(
                            color: widget.color,
                            fontSize: isMobile
                                ? null
                                : widget.isMiniMode
                                ? 10.5
                                : 12.5,
                          ),
                        ),
                        Text(
                          formatDuration(duration),
                          style: TextStyle(
                            color: widget.color,
                            fontSize: isMobile
                                ? null
                                : widget.isMiniMode
                                ? 10.5
                                : 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Slider visuals
                  SizedBox(
                    height: widget.seekBarHeight,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbColor: widget.color ?? seekBarColor.value,
                        trackHeight: isDragging ? 4 : 2,
                        trackShape: const FullWidthTrackShape(),
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: 0,
                        ),
                        overlayShape: SliderComponentShape.noOverlay,
                        activeTrackColor: widget.color ?? seekBarColor.value,
                        inactiveTrackColor: Colors.black12,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: ExcludeFocus(
                          child: Slider(
                            min: 0.0,
                            max: durationMs,
                            value: sliderValue.clamp(0.0, durationMs),
                            onChanged: (value) {},
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Full-track GestureDetector to capture touches anywhere on the track
                  Positioned.fill(
                    top: (widget.widgetHeight - widget.seekBarHeight) / 2,
                    bottom: (widget.widgetHeight - widget.seekBarHeight) / 2,
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
                        seekByTouch(
                          details.localPosition.dx,
                          context,
                          durationMs,
                        );
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

    double relative =
        (dx - horizontalPadding) / (box.size.width - horizontalPadding * 2);
    relative = relative.clamp(0.0, 1.0);
    dragValue = relative * durationMs;
  }
}
