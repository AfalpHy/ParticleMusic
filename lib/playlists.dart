import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/song_list_tile.dart';
import 'package:path/path.dart' as p;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:searchfield/searchfield.dart';
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
        color: Colors.white,
        child: Column(
          children: [
            ListTile(
              leading: Material(child: Icon(Icons.add, size: 40)),
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
                        color: Colors.white,
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
                  if (name != null && name != '') {
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

class PlaylistSongList extends StatelessWidget {
  final Playlist playlist;
  final ValueNotifier<void> notifier;
  final String searchQuery;
  const PlaylistSongList({
    super.key,
    required this.playlist,
    required this.notifier,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<bool> listIsScrolling = ValueNotifier(false);
    final ItemScrollController itemScrollController = ItemScrollController();
    Timer? timer;
    filteredSongs = playlist.songs
        .where(
          (song) =>
              (searchQuery.isEmpty) ||
              (song.title?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                  false) ||
              (song.artist?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                  false) ||
              (song.album?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                  false),
        )
        .toList();
    return Stack(
      children: [
        NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction != ScrollDirection.idle) {
              if (playQueue.isNotEmpty) {
                listIsScrolling.value = true;
                if (timer != null) {
                  timer!.cancel();
                  timer = null;
                }
              }
            } else {
              if (listIsScrolling.value) {
                timer ??= Timer(const Duration(milliseconds: 3000), () {
                  listIsScrolling.value = false;
                  timer = null;
                });
              }
            }
            return false;
          },
          child: ValueListenableBuilder(
            valueListenable: notifier,
            builder: (_, _, _) {
              return ScrollablePositionedList.builder(
                itemScrollController: itemScrollController,
                itemCount: filteredSongs.length + 2,
                itemBuilder: (_, index) {
                  if (index == 0) {
                    return Column(
                      children: [
                        SizedBox(height: 10),
                        Row(
                          children: [
                            SizedBox(width: 20),

                            Material(
                              elevation: 5,
                              borderRadius: BorderRadius.circular(6),
                              child: ArtWidget(
                                size: 120,
                                borderRadius: 6,
                                source:
                                    (playlist.songs.isNotEmpty &&
                                        playlist
                                            .songs
                                            .first
                                            .pictures
                                            .isNotEmpty)
                                    ? playlist.songs.first.pictures.first
                                    : null,
                              ),
                            ),

                            Expanded(
                              child: ListTile(
                                title: Text(
                                  playlist.name,
                                  style: TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  "${playlist.songs.length} songs",
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                      ],
                    );
                  } else if (index < filteredSongs.length + 1) {
                    return SongListTile(
                      index: index - 1,
                      source: filteredSongs,
                      playlist: playlist,
                    );
                  } else {
                    return SizedBox(height: 90);
                  }
                },
              );
            },
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 120,
          child: MyLocation(
            itemScrollController: itemScrollController,
            listIsScrolling: listIsScrolling,
            offset: 1,
          ),
        ),
      ],
    );
  }
}

class MyLocation extends StatelessWidget {
  final ItemScrollController itemScrollController;
  final ValueNotifier<bool> listIsScrolling;
  final int offset;
  const MyLocation({
    super.key,
    required this.itemScrollController,
    required this.listIsScrolling,
    this.offset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (_, currentSong, _) {
        return ValueListenableBuilder(
          valueListenable: listIsScrolling,
          builder: (context, isScrolling, child) {
            return isScrolling && filteredSongs.contains(currentSong)
                ? Row(
                    children: [
                      Spacer(),
                      IconButton(
                        onPressed: () {
                          if (currentSongNotifier.value != null) {
                            for (int i = 0; i < filteredSongs.length; i++) {
                              if (filteredSongs[i] == currentSong) {
                                itemScrollController.scrollTo(
                                  index: i + offset,
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.linear,
                                  alignment: 0.4,
                                );
                              }
                            }
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
  }
}

class PlaylistScaffold extends StatelessWidget {
  final int index;
  final ValueNotifier<bool> isSearch = ValueNotifier(false);
  final ValueNotifier<String> searchQuery = ValueNotifier('');
  PlaylistScaffold({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final playlist = playlists[index];
    TextEditingController textController = TextEditingController();
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        actions: [
          SizedBox(width: 50),
          ValueListenableBuilder(
            valueListenable: isSearch,
            builder: (context, value, child) {
              if (value) {
                return Expanded(
                  child: SizedBox(
                    height: 40,
                    child: SearchField(
                      autofocus: true,
                      controller: textController,
                      suggestions: [],
                      searchInputDecoration: SearchInputDecoration(
                        hintText: 'Search songs',
                        prefixIcon: Icon(Icons.search),
                        suffixIcon: IconButton(
                          onPressed: () {
                            searchQuery.value = '';
                            isSearch.value = false;
                            textController.clear();
                            FocusScope.of(context).unfocus();
                          },
                          icon: Icon(Icons.clear),
                          padding: EdgeInsets.zero,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSearchTextChanged: (value) {
                        searchQuery.value = value;
                        return null;
                      },
                    ),
                  ),
                );
              }
              return IconButton(
                onPressed: () {
                  isSearch.value = true;
                },
                icon: Icon(Icons.search),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true, // allows full-height
                useRootNavigator: true,
                builder: (context) {
                  return ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    child: Container(
                      height: 500,
                      color: Colors.white,
                      child: Column(
                        children: [
                          ListTile(title: Text("Playlist: ${playlist.name}")),
                          Divider(
                            thickness: 0.5,
                            height: 1,
                            color: Colors.grey.shade300,
                          ),
                          playlist.name != 'Favorite'
                              ? ListTile(
                                  leading: Icon(Icons.delete_rounded, size: 25),
                                  title: Text(
                                    'Delete',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  visualDensity: const VisualDensity(
                                    horizontal: 0,
                                    vertical: -4,
                                  ),
                                  onTap: () {
                                    deletePlaylist(index);
                                    Navigator.pop(context, true);
                                  },
                                )
                              : SizedBox(),
                        ],
                      ),
                    ),
                  );
                },
              ).then((value) {
                if (value == true) {
                  Navigator.pop(context);
                }
              });
            },
          ),
        ],
      ),

      body: ValueListenableBuilder(
        valueListenable: searchQuery,
        builder: (context, value, child) {
          return PlaylistSongList(
            playlist: playlist,
            notifier: playlist.changeNotifier,
            searchQuery: value,
          );
        },
      ),
    );
  }
}
