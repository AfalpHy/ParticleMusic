import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/my_audio_metadata.dart';

class MyLocation extends StatelessWidget {
  final ScrollController scrollController;
  final ValueNotifier<bool> listIsScrollingNotifier;
  final ValueNotifier<List<MyAudioMetadata>> currentSongListNotifier;
  final double offset;
  const MyLocation({
    super.key,
    required this.scrollController,
    required this.listIsScrollingNotifier,
    required this.currentSongListNotifier,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        currentSongNotifier,
        currentSongListNotifier,
        listIsScrollingNotifier,
      ]),
      builder: (_, _) {
        if (currentSongNotifier.value == null ||
            !listIsScrollingNotifier.value) {
          return SizedBox.shrink();
        }
        final index = currentSongListNotifier.value.indexOf(
          currentSongNotifier.value!,
        );
        if (index == -1) {
          return SizedBox.shrink();
        }

        return IconButton(
          onPressed: () {
            final position = scrollController.position;
            final maxScrollExtent = position.maxScrollExtent;
            final minScrollExtent = position.minScrollExtent;
            scrollController.animateTo(
              (60 * index + offset).clamp(minScrollExtent, maxScrollExtent),
              duration: Duration(milliseconds: 300),
              curve: Curves.linear,
            );
          },
          icon: ImageIcon(location),
        );
      },
    );
  }
}
