import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/song_list_tile.dart';
import 'package:path/path.dart' as p;
import 'art_widget.dart';

late File allPlaylistsFile;
List<Playlist> playlists = [];
Map<String, Playlist> playlistMap = {};
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
  File playlistFile;
  ValueNotifier<int> changeNotifier = ValueNotifier(0);

  Playlist({required this.name})
    : playlistFile = File("${allPlaylistsFile.parent.path}/$name.json") {
    playlistMap[name] = this;
    if (!playlistFile.existsSync()) {
      playlistFile.createSync();
    }
  }

  void add(AudioMetadata song) {
    if (songs.contains(song)) {
      return;
    }
    songs.insert(0, song);
    playlistFile.writeAsStringSync(
      jsonEncode(songs.map((s) => p.basename(s.file.path)).toList()),
    );
    changeNotifier.value++;
    if (name == 'Favorite') {
      songIsFavorite[song]!.value = true;
    }
  }

  void remove(AudioMetadata song) {
    songs.remove(song);
    playlistFile.writeAsStringSync(
      jsonEncode(songs.map((s) => p.basename(s.file.path)).toList()),
    );
    changeNotifier.value++;
    if (name == 'Favorite') {
      songIsFavorite[song]!.value = false;
    }
  }

  void delete() {
    playlistFile.deleteSync();
    playlistMap.remove(name);
  }
}

Map<AudioMetadata, ValueNotifier<bool>> songIsFavorite = {};

void toggleFavoriteState(AudioMetadata song) {
  final favorite = playlistMap['Favorite']!;
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
        color: Colors.grey.shade100,
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.add, size: 40),
              title: Text('New Playlist'),
              onTap: () {
                final controller = TextEditingController();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true, // allows full-height
                  builder: (_) {
                    return ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                      child: Container(
                        height: 500,
                        color: Colors.grey.shade100,
                        child: SizedBox(
                          height: 250, // fixed height
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.start, // center vertically
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  30,
                                  30,
                                  30,
                                  0,
                                ),
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
                                  Navigator.pop(
                                    context,
                                    controller.text,
                                  ); // close with value
                                },
                                child: const Text("Complete"),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ).then((name) {
                  if (name != '') {
                    newPlaylist(name);
                    setState(() {});
                  }
                });
              },
            ),
            Divider(thickness: 0.5, height: 1, color: Colors.grey.shade300),
            Expanded(
              child: ListView.builder(
                itemCount: playlists.length,
                itemBuilder: (_, index) {
                  final playlist = playlists[index];
                  return ListTile(
                    leading: (() {
                      if (playlist.songs.isNotEmpty) {
                        return ArtWidget(
                          size: 40,
                          borderRadius: 1,
                          source: playlist.songs.first.pictures.isEmpty
                              ? null
                              : playlist.songs.first.pictures.first,
                        );
                      }
                      return Icon(Icons.music_note, size: 40);
                    })(),
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
