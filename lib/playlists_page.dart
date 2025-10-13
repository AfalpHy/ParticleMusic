import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:particle_music/art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/song_list_scaffold.dart';
import 'package:smooth_corner/smooth_corner.dart';

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
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => reorderPlaylistsScaffold(context),
                ),
              );
            },
            icon: const ImageIcon(AssetImage("assets/images/reorder.png")),
          ),
        ],
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
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SongListScaffold(
                          songList: playlist.songs,
                          name: playlist.name,

                          moreSheet: (context) =>
                              moreSheet(context, index, playlist),
                          playlist: playlist,
                        ),
                      ),
                    );
                  },
                );
              }

              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.fromLTRB(20, 5, 20, 0),
                    leading: SmoothClipRRect(
                      smoothness: 1,
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        color: const Color.fromARGB(255, 245, 235, 245),
                        child: ImageIcon(
                          AssetImage("assets/images/add.png"),
                          size: 50,
                        ),
                      ),
                    ),
                    title: Text('Create Playlist'),
                    onTap: () {
                      showCreatePlaylistSheet(context);
                    },
                  ),
                  SizedBox(height: 70),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget reorderPlaylistsScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ReorderableListView.builder(
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = playlistsManager.playlists.removeAt(oldIndex + 1);
          playlistsManager.playlists.insert(newIndex + 1, item);
          playlistsManager.update();
        },
        onReorderStart: (_) {
          HapticFeedback.heavyImpact();
        },
        onReorderEnd: (_) {
          HapticFeedback.heavyImpact();
        },
        proxyDecorator: (Widget child, int index, Animation<double> animation) {
          return Material(
            elevation: 0.1,
            color: Colors.grey.shade100, // background color while moving
            child: child,
          );
        },
        itemCount: playlistsManager.length() - 1,
        itemBuilder: (_, index) {
          final playlist = playlistsManager.getPlaylistByIndex(index + 1);
          return ListTile(
            key: ValueKey(index),
            contentPadding: EdgeInsets.fromLTRB(20, 0, 20, 0),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -1),

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
          );
        },
      ),
    );
  }

  Widget moreSheet(BuildContext context, int index, Playlist playlist) {
    return mySheet(
      Column(
        children: [
          ListTile(
            title: SizedBox(
              height: 40,
              width: appWidth * 0.9,
              child: Row(
                children: [
                  Text('Playlist: ', style: TextStyle(fontSize: 15)),
                  Expanded(
                    child: MyAutoSizeText(
                      playlist.name,
                      maxLines: 1,
                      textStyle: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(thickness: 0.5, height: 1, color: Colors.grey.shade300),
          ListTile(
            leading: const ImageIcon(
              AssetImage("assets/images/select.png"),
              color: Colors.black,
              size: 20,
            ),
            title: Text(
              'Select',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SelectableSongListScaffold(
                    songList: playlist.songs,
                    playlist: playlist,
                  ),
                ),
              );
            },
          ),
          playlist.name != 'Favorite'
              ? ListTile(
                  leading: Icon(Icons.delete_rounded),
                  title: Text(
                    'Delete',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  visualDensity: const VisualDensity(
                    horizontal: 0,
                    vertical: -4,
                  ),
                  onTap: () async {
                    if (await showConfirmDialog(context, 'Delete Action')) {
                      playlistsManager.deletePlaylist(index);
                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    }
                  },
                )
              : SizedBox(),
        ],
      ),
    );
  }
}
