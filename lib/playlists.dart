import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:path/path.dart' as p;
import 'art_widget.dart';

late PlaylistsManager playlistsManager;

class PlaylistsManager {
  final File file;
  List<Playlist> playlists = [];
  Map<String, Playlist> playlistsMap = {};
  ValueNotifier<int> changeNotifier = ValueNotifier(0);

  PlaylistsManager(this.file) {
    if (!(file.existsSync())) {
      file.writeAsStringSync(jsonEncode(['Favorite']));
    }
  }

  Future<List<dynamic>> getAllPlaylists() async {
    return jsonDecode(await file.readAsString());
  }

  int length() {
    return playlists.length;
  }

  Playlist getPlaylistByIndex(int index) {
    assert(index >= 0 && index < playlists.length);
    return playlists[index];
  }

  Playlist? getPlaylistByName(String name) {
    return playlistsMap[name];
  }

  void addPlaylist(Playlist playlist) {
    playlists.add(playlist);
    playlistsMap[playlist.name] = playlist;
  }

  void createPlaylist(String name) {
    for (Playlist playlist in playlists) {
      // check whether the name exists
      if (name == playlist.name) {
        return;
      }
    }

    File playlistFile = File("${file.parent.path}/$name.json");
    addPlaylist(Playlist(name: name, file: playlistFile));

    file.writeAsString(jsonEncode(playlists.map((pl) => pl.name).toList()));
    changeNotifier.value++;
  }

  void deletePlaylist(int index) {
    final playlist = playlists[index];
    playlistsMap.remove(playlist.name);
    playlist.file.deleteSync();
    playlists.removeAt(index);
    file.writeAsString(jsonEncode(playlists.map((pl) => pl.name).toList()));
    changeNotifier.value++;
  }

  void clear() {
    playlists = [];
    playlistsMap = {};
  }
}

class Playlist {
  String name;
  List<AudioMetadata> songs = [];
  File file;
  ValueNotifier<int> changeNotifier = ValueNotifier(0);

  Playlist({required this.name, required this.file}) {
    if (!file.existsSync()) {
      file.createSync();
    }
  }

  void add(List<AudioMetadata> songs) {
    for (AudioMetadata song in songs) {
      if (this.songs.contains(song)) {
        continue;
      }
      this.songs.insert(0, song);
      if (name == 'Favorite') {
        songIsFavorite[song]!.value = true;
      }
    }
    update();
  }

  void remove(List<AudioMetadata> songs) {
    for (AudioMetadata song in songs) {
      this.songs.remove(song);
      if (name == 'Favorite') {
        songIsFavorite[song]!.value = false;
      }
    }
    update();
  }

  void update() {
    file.writeAsStringSync(
      jsonEncode(songs.map((s) => p.basename(s.file.path)).toList()),
    );
    changeNotifier.value++;
  }
}

Map<AudioMetadata, ValueNotifier<bool>> songIsFavorite = {};

void toggleFavoriteState(AudioMetadata song) {
  final favorite = playlistsManager.getPlaylistByName('Favorite')!;
  final isFavorite = songIsFavorite[song]!;
  if (isFavorite.value) {
    favorite.remove([song]);
  } else {
    favorite.add([song]);
  }
}

class PlaylistsSheet extends StatefulWidget {
  final List<AudioMetadata> songs;
  const PlaylistsSheet({super.key, required this.songs});

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
    return mySheet(
      Column(
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
              itemCount: playlistsManager.length(),
              itemBuilder: (_, index) {
                final playlist = playlistsManager.getPlaylistByIndex(index);
                return ListTile(
                  leading: ArtWidget(
                    size: 40,
                    borderRadius: 4,
                    source:
                        playlist.songs.isNotEmpty &&
                            playlist.songs.first.pictures.isNotEmpty
                        ? playlist.songs.first.pictures.first
                        : null,
                  ),
                  title: Text(playlist.name),

                  onTap: () {
                    for (var song in widget.songs) {
                      playlist.add([song]);
                    }
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
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
      return mySheet(
        SizedBox(
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
      );
    },
  );
  if (name != null && name != '') {
    playlistsManager.createPlaylist(name);
    return true;
  }
  return false;
}
