import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/song_list_tile.dart';
import 'package:provider/provider.dart';

class Playlist {
  String name;
  List<AudioMetadata> songs;

  Playlist({required this.name, required this.songs});
}

List<Playlist> playlists = [];

class PlaylistsSheet extends StatefulWidget {
  const PlaylistsSheet({super.key});

  @override
  State<StatefulWidget> createState() => PlaylistsSheetState();
}

class PlaylistsSheetState extends State<PlaylistsSheet> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      child: Container(
        height: 500,
        color: Colors.grey.shade100,
        child: Column(
          children: [
            ListTile(leading: Icon(Icons.add), title: Text('New Playlist')),
            Expanded(
              child: ListView.builder(
                itemCount: playlists.length,
                itemBuilder: (_, index) {
                  final playlist = playlists[index];
                  return ListTile(
                    leading: Icon(Icons.music_note),
                    title: Text(playlist.name),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          itemCount: widget.source.length + 1,
          itemBuilder: (_, index) {
            if (index < widget.source.length) {
              return Selector<MyAudioHandler, AudioMetadata?>(
                selector: (_, audioHandler) => audioHandler.currentSong,
                builder: (_, _, _) {
                  return SongListTile(index: index, source: favorite);
                },
              );
            } else {
              return SizedBox(height: 50);
            }
          },
        );
      },
    );
  }
}
