import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/mobile/pages/song_list_page.dart';
import 'package:smooth_corner/smooth_corner.dart';

class PlaylistsPage extends StatelessWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.playlists),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              tryVibrate();

              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useRootNavigator: true,
                builder: (context) {
                  return playlistsMoreSheet(context);
                },
              );
            },
            icon: Icon(Icons.more_vert),
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
                      return CoverArtWidget(
                        size: 50,
                        borderRadius: 5,
                        source: playlist.songs.isNotEmpty
                            ? getCoverArt(playlist.songs.first)
                            : null,
                      );
                    },
                  ),
                  title: AutoSizeText(
                    index == 0 ? l10n.favorite : playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    minFontSize: 15,
                    maxFontSize: 15,
                  ),
                  subtitle: ValueListenableBuilder(
                    valueListenable: playlist.changeNotifier,
                    builder: (_, _, _) {
                      return Text(l10n.songsCount(playlist.songs.length));
                    },
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SongListPage(playlist: playlist),
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
                        color: Colors.grey.shade200,
                        child: ImageIcon(addImage, size: 50),
                      ),
                    ),
                    title: Text(l10n.createPlaylist),
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

  Widget playlistsMoreSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return mySheet(
      Column(
        children: [
          ListTile(
            leading: SmoothClipRRect(
              smoothness: 1,
              borderRadius: BorderRadius.circular(5),
              child: Container(
                color: Colors.grey.shade200,
                child: ImageIcon(addImage, size: 50),
              ),
            ),
            title: Text(l10n.createPlaylist),
            visualDensity: const VisualDensity(horizontal: 0, vertical: 4),
            onTap: () {
              showCreatePlaylistSheet(context);
            },
          ),
          Divider(thickness: 0.5, height: 1, color: Colors.grey.shade300),
          ListTile(
            leading: const ImageIcon(reorderImage, color: Colors.black),
            title: Text(
              l10n.reorder,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (context) => reorderPlaylistsPage(context),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget reorderPlaylistsPage(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        scrolledUnderElevation: 0,
      ),
      body: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = playlistsManager.playlists.removeAt(oldIndex + 1);
          playlistsManager.playlists.insert(newIndex + 1, item);
          playlistsManager.update();
        },
        onReorderStart: (_) {
          tryVibrate();
        },
        onReorderEnd: (_) {
          tryVibrate();
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
          return Row(
            key: ValueKey(index),
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.fromLTRB(20, 0, 0, 0),
                  visualDensity: const VisualDensity(
                    horizontal: 0,
                    vertical: -1,
                  ),

                  leading: CoverArtWidget(
                    size: 50,
                    borderRadius: 5,
                    source: playlist.songs.isNotEmpty
                        ? getCoverArt(playlist.songs.first)
                        : null,
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
                      return Text(
                        AppLocalizations.of(
                          context,
                        ).songsCount(playlist.songs.length),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                height: 60,
                child: ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    // must set color to make area valid
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        SizedBox(width: 10),
                        const ImageIcon(reorderImage),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        footer: SizedBox(height: 80),
      ),
    );
  }
}
