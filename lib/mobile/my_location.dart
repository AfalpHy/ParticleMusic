import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class MyLocation extends StatelessWidget {
  final ItemScrollController itemScrollController;
  final ValueNotifier<bool> listIsScrollingNotifier;
  final ValueNotifier<List<AudioMetadata>> songListNotifer;
  final int offset;
  const MyLocation({
    super.key,
    required this.itemScrollController,
    required this.listIsScrollingNotifier,
    required this.songListNotifer,
    this.offset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (_, currentSong, _) {
        return ValueListenableBuilder(
          valueListenable: songListNotifer,
          builder: (context, songList, child) {
            return ValueListenableBuilder(
              valueListenable: listIsScrollingNotifier,
              builder: (context, isScrolling, child) {
                return isScrolling && songList.contains(currentSong)
                    ? Row(
                        children: [
                          Spacer(),
                          IconButton(
                            onPressed: () {
                              for (int i = 0; i < songList.length; i++) {
                                itemScrollController.scrollTo(
                                  index:
                                      songList.indexOf(currentSong!) + offset,
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.linear,
                                  alignment: 0.4,
                                );
                              }
                            },
                            icon: Icon(Icons.my_location_rounded, size: 20),
                          ),
                          SizedBox(width: 30),
                        ],
                      )
                    : SizedBox();
              },
            );
          },
        );
      },
    );
  }
}
