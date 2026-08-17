import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/widgets/full_width_track_shape.dart';

class VolumeBar extends StatelessWidget {
  final Color activeColor;

  const VolumeBar({super.key, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        trackShape: const FullWidthTrackShape(),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 0),
        overlayColor: Colors.transparent,
        activeTrackColor: activeColor,
        inactiveTrackColor: Colors.black12,
      ),
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            double step = 0.02;

            double newValue;

            if (event.scrollDelta.dy < 0) {
              newValue = volumeNotifier.value + step;
            } else {
              newValue = volumeNotifier.value - step;
            }

            newValue = newValue.clamp(0.0, 1.0);

            volumeNotifier.value = newValue;
            audioHandler.setVolume(newValue);
            audioHandler.savePlayState();
          }
        },
        child: ValueListenableBuilder(
          valueListenable: volumeNotifier,
          builder: (context, value, child) {
            return ExcludeFocus(
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
    );
  }
}
