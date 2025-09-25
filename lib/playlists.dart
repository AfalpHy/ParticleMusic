import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/song_list_tile.dart';
import 'package:path/path.dart' as p;

late File favoriteFile;

class Playlist {
  String name;
  List<AudioMetadata> songs = [];

  Playlist({required this.name});
}

List<Playlist> playlists = [];
Map<String, Playlist> playlistMap = {};
Map<AudioMetadata, ValueNotifier<bool>> songIsFavorite = {};
ValueNotifier<int> favoriteChangeNotifier = ValueNotifier(0);

void changeFavoriteState(AudioMetadata song) {
  final favorite = playlistMap['Favorite']!;
  final isFavorite = songIsFavorite[song]!;
  if (isFavorite.value) {
    favorite.songs.remove(song);
  } else {
    favorite.songs.insert(0, song);
  }
  favoriteFile.writeAsStringSync(
    jsonEncode(favorite.songs.map((s) => p.basename(s.file.path)).toList()),
  );
  isFavorite.value = !isFavorite.value;
  favoriteChangeNotifier.value++;
}

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

class PlaylistSongList extends StatelessWidget {
  final List<AudioMetadata> source;
  final ValueNotifier<void> notifier;
  const PlaylistSongList({
    super.key,
    required this.source,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (_, _, _) {
        return ListView.builder(
          itemCount: source.length + 1,
          itemBuilder: (_, index) {
            if (index < source.length) {
              return SongListTile(index: index, source: source);
            } else {
              return SizedBox(height: 60);
            }
          },
        );
      },
    );
  }
}
