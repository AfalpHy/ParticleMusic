import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:path/path.dart' as p;
import 'package:smooth_corner/smooth_corner.dart';
import 'cover_art_widget.dart';

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

    update();
  }

  void deletePlaylist(int index) {
    final playlist = playlists[index];
    playlistsMap.remove(playlist.name);
    playlist.file.deleteSync();
    playlists.removeAt(index);

    update();
  }

  void clear() {
    playlists = [];
    playlistsMap = {};
  }

  void update() {
    file.writeAsString(jsonEncode(playlists.map((pl) => pl.name).toList()));
    changeNotifier.value++;
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
    return mySheet(Add2PlaylistPlane(songs: widget.songs));
  }
}

class Add2PlaylistPlane extends StatefulWidget {
  final List<AudioMetadata> songs;
  const Add2PlaylistPlane({super.key, required this.songs});

  @override
  State<StatefulWidget> createState() => _Add2PlaylistPlaneState();
}

class _Add2PlaylistPlaneState extends State<Add2PlaylistPlane> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: SmoothClipRRect(
            smoothness: 1,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              color: const Color.fromARGB(255, 245, 235, 245),
              child: ImageIcon(addImage, size: 40),
            ),
          ),
          title: Text('Create Playlist'),
          onTap: () async {
            if (await showCreatePlaylistDialog(context)) {
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
                leading: CoverArtWidget(
                  size: 40,
                  borderRadius: 4,
                  source: playlist.songs.isNotEmpty
                      ? getCoverArt(playlist.songs.first)
                      : null,
                ),
                title: Text(playlist.name),

                onTap: () {
                  for (var song in widget.songs) {
                    playlist.add([song]);
                  }
                  showCenterMessage(
                    context,
                    'Added to Playlist',
                    duration: 1500,
                  );
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

Future<bool> showCreatePlaylistDialog(BuildContext context) async {
  final controller = TextEditingController();

  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Create Playlist'),
        shape: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: "Playlist Name",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // cancel
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text), // submit
            child: const Text('Complete'),
          ),
        ],
      );
    },
  );

  if (result != null && result != '') {
    playlistsManager.createPlaylist(result);
    return true;
  }
  return false;
}

void showAddPlaylistDialog(
  BuildContext context,
  List<AudioMetadata> songs,
) async {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        child: SizedBox(
          height: 500,
          width: 500,
          child: Column(
            children: [
              SizedBox(height: 10),
              Expanded(child: Add2PlaylistPlane(songs: songs)),
            ],
          ),
        ),
      );
    },
  );
}
