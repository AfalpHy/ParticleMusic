import 'dart:async';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:particle_music/art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/my_location.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/song_list_tile.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:searchfield/searchfield.dart';

class PlaylistsScaffold extends StatelessWidget {
  const PlaylistsScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text("Playlists"),
      ),
      body: ValueListenableBuilder(
        valueListenable: playlistsChangeNotifier,
        builder: (context, _, _) {
          return ListView.builder(
            itemCount: playlists.length + 1,
            itemBuilder: (_, index) {
              if (index < playlists.length) {
                final playlist = playlists[index];
                return ListTile(
                  contentPadding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                  visualDensity: const VisualDensity(
                    horizontal: 0,
                    vertical: -1,
                  ),

                  leading: ValueListenableBuilder(
                    valueListenable: playlist.changeNotifier,
                    builder: (_, _, _) {
                      return ArtWidget(
                        size: 50,
                        borderRadius: 3,
                        source:
                            playlist.songs.isNotEmpty &&
                                playlist.songs.first.pictures.isNotEmpty
                            ? playlist.songs.first.pictures.first
                            : null,
                      );
                    },
                  ),
                  title: AutoSizeText(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    minFontSize: 15,
                    maxFontSize: 15,
                  ),
                  subtitle: ValueListenableBuilder(
                    valueListenable: playlist.changeNotifier,
                    builder: (_, _, _) {
                      return Text("${playlist.songs.length} songs");
                    },
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SinglePlaylistScaffold(index: index),
                      ),
                    );
                  },
                );
              }

              return ListTile(
                contentPadding: EdgeInsets.fromLTRB(20, 0, 0, 0),
                leading: Material(
                  borderRadius: BorderRadius.circular(3),
                  child: Icon(Icons.add, size: 50),
                ),
                title: Text('Create Playlist'),
                onTap: () {
                  showCreatePlaylistSheet(context);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class SinglePlaylistScaffold extends StatelessWidget {
  final int index;
  final listIsScrollingNotifier = ValueNotifier(false);
  final songListNotifer = ValueNotifier<List<AudioMetadata>>([]);

  final itemScrollController = ItemScrollController();

  final Playlist playlist;

  SinglePlaylistScaffold({super.key, required this.index})
    : playlist = playlists[index] {
    songListNotifer.value = playlist.songs;
  }

  @override
  Widget build(BuildContext context) {
    Timer? timer;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: appBar(context),
      body: Stack(
        children: [
          NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction != ScrollDirection.idle) {
                listIsScrollingNotifier.value = true;
                if (timer != null) {
                  timer!.cancel();
                  timer = null;
                }
              } else {
                if (listIsScrollingNotifier.value) {
                  timer ??= Timer(const Duration(milliseconds: 3000), () {
                    listIsScrollingNotifier.value = false;
                    timer = null;
                  });
                }
              }
              return false;
            },
            child: ValueListenableBuilder(
              valueListenable: songListNotifer,
              builder: (context, songList, child) {
                return ScrollablePositionedList.builder(
                  itemScrollController: itemScrollController,
                  itemCount: songList.length + 2,
                  itemBuilder: (context, index) {
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
                                  title: AutoSizeText(
                                    playlist.name,
                                    maxLines: 1,
                                    minFontSize: 20,
                                    maxFontSize: 20,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
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
                    }

                    if (index < songList.length + 1) {
                      return SongListTile(
                        index: index - 1,
                        source: songList,
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
              listIsScrollingNotifier: listIsScrollingNotifier,
              songListNotifer: songListNotifer,
              offset: 1,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget appBar(BuildContext context) {
    final textController = TextEditingController();
    final ValueNotifier<bool> isSearch = ValueNotifier(false);
    return AppBar(
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
                          isSearch.value = false;
                          songListNotifer.value = playlist.songs;
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
                      songListNotifer.value = playlist.songs
                          .where(
                            (song) =>
                                (value.isEmpty) ||
                                (song.title?.toLowerCase().contains(
                                      value.toLowerCase(),
                                    ) ??
                                    false) ||
                                (song.artist?.toLowerCase().contains(
                                      value.toLowerCase(),
                                    ) ??
                                    false) ||
                                (song.album?.toLowerCase().contains(
                                      value.toLowerCase(),
                                    ) ??
                                    false),
                          )
                          .toList();
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
              isScrollControlled: true,
              useRootNavigator: true,
              builder: (context) {
                return ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                  child: Container(
                    height: 500,
                    color: Colors.white,
                    child: Column(
                      children: [
                        ListTile(
                          title: SizedBox(
                            height: 40,
                            width: MediaQuery.of(context).size.width * 0.9,
                            child: Row(
                              children: [
                                Text(
                                  'Playlist: ',
                                  style: TextStyle(fontSize: 15),
                                ),
                                Expanded(
                                  child: MyAutoSizeText(
                                    playlist.name,
                                    maxLines: 1,
                                    minFontSize: 15,
                                    maxFontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
              if (value == true && context.mounted) {
                Navigator.pop(context);
              }
            });
          },
        ),
      ],
    );
  }
}
