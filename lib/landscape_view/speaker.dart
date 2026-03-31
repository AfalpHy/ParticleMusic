import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';

double? _volumeTmp;

class Speaker extends StatelessWidget {
  final Color color;
  const Speaker({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: volumeNotifier,
      builder: (_, value, _) {
        if (value == 0) {
          return IconButton(
            color: color,
            onPressed: () {
              if (_volumeTmp != null) {
                volumeNotifier.value = _volumeTmp!;
                audioHandler.setVolume(_volumeTmp!);
                audioHandler.savePlayState();
              }
            },
            icon: ImageIcon(speakerOffImage, size: 25),
          );
        }
        _volumeTmp = null;

        return IconButton(
          color: color,
          onPressed: () {
            _volumeTmp = volumeNotifier.value;
            volumeNotifier.value = 0;
            audioHandler.setVolume(0);
            audioHandler.savePlayState();
          },
          icon: ImageIcon(speakerImage, size: 25),
        );
      },
    );
  }
}
