import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/song_list_scaffold.dart';

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
        centerTitle: true,
      ),
      body: ValueListenableBuilder(
        valueListenable: playlistsManager.changeNotifier,
        builder: (context, _, _) {
          return ListView.builder(
            itemCount: playlistsManager.length() + 1,
            itemBuilder: (_, index) {
              if (index < playlistsManager.length()) {
                final playlist = playlistsManager.getPlaylistByIndex(index);
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
                        borderRadius: 5,
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
                    final ValueNotifier<bool> needReorderNotifier =
                        ValueNotifier(false);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        // can't use this builder context for MediaQuery.of(context), otherwise search field will not work
                        builder: (_) => SongListScaffold(
                          songList: playlist.songs,
                          name: playlist.name,

                          moreSheet: (context) => moreSheet(
                            context,
                            index,
                            playlist.name,
                            needReorderNotifier,
                          ),
                          playlist: playlist,
                          needReorderNotifier: needReorderNotifier,
                        ),
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

  Widget moreSheet(
    BuildContext context,
    int index,
    String name,
    ValueNotifier<bool> needReorderNotifier,
  ) {
    return mySheet(
      Column(
        children: [
          ListTile(
            title: SizedBox(
              height: 40,
              width: MediaQuery.of(context).size.width * 0.9,
              child: Row(
                children: [
                  Text('Playlist: ', style: TextStyle(fontSize: 15)),
                  Expanded(
                    child: MyAutoSizeText(name, maxLines: 1, fontsize: 15),
                  ),
                ],
              ),
            ),
          ),
          Divider(thickness: 0.5, height: 1, color: Colors.grey.shade300),
          ListTile(
            leading: Icon(Icons.reorder, size: 25),
            title: Text(
              'Reorder',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () {
              needReorderNotifier.value = true;
              Navigator.pop(context);
            },
          ),
          name != 'Favorite'
              ? ListTile(
                  leading: Icon(Icons.delete_rounded, size: 25),
                  title: Text(
                    'Delete',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  visualDensity: const VisualDensity(
                    horizontal: 0,
                    vertical: -4,
                  ),
                  onTap: () {
                    playlistsManager.deletePlaylist(index);
                    Navigator.pop(context, true);
                  },
                )
              : SizedBox(),
        ],
      ),
    );
  }
}
