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
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (_, currentSong, _) {
        if (currentSong == null) {
          return SizedBox.shrink();
        }
        return ValueListenableBuilder(
          valueListenable: currentSongListNotifier,
          builder: (_, currentSongList, _) {
            final index = currentSongList.indexOf(currentSong);
            return ValueListenableBuilder(
              valueListenable: listIsScrollingNotifier,
              builder: (_, isScrolling, _) {
                return isScrolling && index >= 0
                    ? IconButton(
                        color: iconColor,
                        onPressed: () {
                          scrollController.animateTo(
                            60 * index.toDouble() + offset,
                            duration: Duration(
                              milliseconds: 300,
                            ), // smooth animation
                            curve: Curves.linear,
                          );
                        },
                        icon: ImageIcon(location),
                      )
                    : SizedBox.shrink();
              },
            );
          },
        );
      },
    );
  }
}
