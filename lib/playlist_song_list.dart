import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/song_list_tile.dart';
import 'package:provider/provider.dart';

class PlaylistSongList extends StatefulWidget {
  final List<AudioMetadata> source;
  final ValueNotifier<int> notifier;
  const PlaylistSongList({
    super.key,
    required this.source,
    required this.notifier,
  });

  @override
  State<StatefulWidget> createState() => PlaylistSongListState();
}

class PlaylistSongListState extends State<PlaylistSongList> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.notifier,
      builder: (_, _, _) {
        return ListView.builder(
          itemCount: widget.source.length,
          itemBuilder: (_, index) {
            return Selector<MyAudioHandler, AudioMetadata?>(
              selector: (_, audioHandler) => audioHandler.currentSong,
              builder: (_, _, _) {
                return SongListTile(index: index, source: favorite);
              },
            );
          },
        );
      },
    );
  }
}
