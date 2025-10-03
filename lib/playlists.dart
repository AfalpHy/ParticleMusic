import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'art_widget.dart';

late File allPlaylistsFile;
List<Playlist> playlists = [];
Map<String, Playlist> playlistsMap = {};
ValueNotifier<int> playlistsChangeNotifier = ValueNotifier(0);

void newPlaylist(String name) {
  for (Playlist playlist in playlists) {
    // check whether the name exists
    if (name == playlist.name) {
      return;
    }
  }
  playlists.add(Playlist(name: name));

  allPlaylistsFile.writeAsString(
    jsonEncode(playlists.map((pl) => pl.name).toList()),
  );
  playlistsChangeNotifier.value++;
}

void deletePlaylist(int index) {
  playlists[index].delete();
  playlists.removeAt(index);
  allPlaylistsFile.writeAsString(
    jsonEncode(playlists.map((pl) => pl.name).toList()),
  );
  playlistsChangeNotifier.value++;
}

class Playlist {
  String name;
  List<AudioMetadata> songs = [];
  File file;
  ValueNotifier<int> changeNotifier = ValueNotifier(0);

  Playlist({required this.name})
    : file = File("${allPlaylistsFile.parent.path}/$name.json") {
    playlistsMap[name] = this;
    if (!file.existsSync()) {
      file.createSync();
    }
  }

  void add(AudioMetadata song) {
    if (songs.contains(song)) {
      return;
    }
    songs.insert(0, song);
    file.writeAsStringSync(
      jsonEncode(songs.map((s) => p.basename(s.file.path)).toList()),
    );
    changeNotifier.value++;
    if (name == 'Favorite') {
      songIsFavorite[song]!.value = true;
    }
  }

  void remove(AudioMetadata song) {
    songs.remove(song);
    file.writeAsStringSync(
      jsonEncode(songs.map((s) => p.basename(s.file.path)).toList()),
    );
    changeNotifier.value++;
    if (name == 'Favorite') {
      songIsFavorite[song]!.value = false;
    }
  }

  void delete() {
    file.deleteSync();
    playlistsMap.remove(name);
  }
}

Map<AudioMetadata, ValueNotifier<bool>> songIsFavorite = {};

void toggleFavoriteState(AudioMetadata song) {
  final favorite = playlistsMap['Favorite']!;
  final isFavorite = songIsFavorite[song]!;
  if (isFavorite.value) {
    favorite.remove(song);
  } else {
    favorite.add(song);
  }
}

class PlaylistsSheet extends StatefulWidget {
  final AudioMetadata song;
  const PlaylistsSheet({super.key, required this.song});

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
        color: Colors.white,
        child: Column(
          children: [
            ListTile(
              leading: Material(child: Icon(Icons.add, size: 40)),
              title: Text('Create Playlist'),
              onTap: () async {
                if (await showCreatePlaylistSheet(context)) {
                  setState(() {});
                }
              },
            ),
            Divider(thickness: 0.5, height: 1, color: Colors.grey.shade300),
            Expanded(
              child: ListView.builder(
                itemCount: playlists.length,
                itemBuilder: (_, index) {
                  final playlist = playlists[index];
                  return ListTile(
                    leading: ArtWidget(
                      size: 40,
                      borderRadius: 2,
                      source:
                          playlist.songs.isNotEmpty &&
                              playlist.songs.first.pictures.isNotEmpty
                          ? playlist.songs.first.pictures.first
                          : null,
                    ),
                    title: Text(playlist.name),

                    onTap: () {
                      playlist.add(widget.song);
                      Navigator.pop(context);
                    },
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

Future<bool> showCreatePlaylistSheet(BuildContext context) async {
  final controller = TextEditingController();
  final name = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) {
      return ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        child: Container(
          height: 500,
          color: Colors.white,
          child: SizedBox(
            height: 250, // fixed height
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start, // center vertically
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 30, 30, 0),
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Playlist Name",
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, controller.text); // close with value
                  },
                  child: const Text("Complete"),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  if (name != null && name != '') {
    newPlaylist(name);
    return true;
  }
  return false;
}
