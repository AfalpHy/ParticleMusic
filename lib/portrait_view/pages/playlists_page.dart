import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/playlist_widgets.dart';
import 'package:particle_music/portrait_view/pages/single_playlist_page.dart';
import 'package:particle_music/common_widgets/my_sheet.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

class PlaylistsPage extends StatelessWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(
        iconTheme: IconThemeData(color: iconColor),
        backgroundColor: pageBackgroundColor,
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
        valueListenable: playlistsManager.updateNotifier,
        builder: (context, _, _) {
          return ListView.builder(
            itemCount: playlistsManager.playlists.length + 1,
            itemBuilder: (_, index) {
              if (index < playlistsManager.playlists.length) {
                final playlist = playlistsManager.getPlaylistByIndex(index);
                return ListTile(
                  contentPadding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                  visualDensity: const VisualDensity(
                    horizontal: 0,
                    vertical: -1,
                  ),

                  leading: ValueListenableBuilder(
                    valueListenable: playlist.updateNotifier,
                    builder: (_, _, _) {
                      return ValueListenableBuilder(
                        valueListenable: playlist.displayNavidromeNotifier,
                        builder: (context, value, child) {
                          return CoverArtWidget(
                            size: 50,
                            borderRadius: 5,
                            song: playlist.getDisplaySong(),
                          );
                        },
                      );
                    },
                  ),
                  title: AutoSizeText(
                    index == 0 ? l10n.favorites : playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    minFontSize: 15,
                    maxFontSize: 15,
                  ),
                  subtitle: ValueListenableBuilder(
                    valueListenable: playlist.updateNotifier,
                    builder: (_, _, _) {
                      return Text(l10n.songsCount(playlist.getTotalCount()));
                    },
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) {
                          return SinglePlaylistPage(playlist: playlist);
                        },
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
                      child: Material(
                        elevation: 1,
                        color: Colors.grey,
                        child: ImageIcon(addImage, size: 50, color: iconColor),
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

    return MySheet(
      Column(
        children: [
          ListTile(
            leading: SmoothClipRRect(
              smoothness: 1,
              borderRadius: BorderRadius.circular(5),
              child: Material(
                elevation: 1,
                color: Colors.grey,
                child: ImageIcon(addImage, size: 50, color: iconColor),
              ),
            ),
            title: Text(l10n.createPlaylist),
            visualDensity: const VisualDensity(horizontal: 0, vertical: 4),
            onTap: () {
              showCreatePlaylistSheet(context);
            },
          ),
          Divider(thickness: 0.5, height: 1, color: dividerColor),
          ListTile(
            leading: ImageIcon(reorderImage, color: iconColor),
            title: Text(
              l10n.reorder,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(
                context,
                rootNavigator: true,
              ).push(MaterialPageRoute(builder: (_) => reorderPlaylistsPage()));
            },
          ),
        ],
      ),
    );
  }

  Widget reorderPlaylistsPage() {
    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(
        backgroundColor: pageBackgroundColor,
        scrolledUnderElevation: 0,
      ),
      body: reorderablePlaylistsView(),
    );
  }
}
