import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/portrait_view/pages/albums_page.dart';
import 'package:particle_music/portrait_view/pages/artists_page.dart';
import 'package:particle_music/portrait_view/pages/folders_page.dart';
import 'package:particle_music/portrait_view/pages/ranking_page.dart';
import 'package:particle_music/portrait_view/pages/playlists_page.dart';
import 'package:particle_music/portrait_view/pages/recently_page.dart';
import 'package:particle_music/common_widgets/settings_list.dart';
import 'package:particle_music/portrait_view/pages/songs_page.dart';

final displayLibraryNotifier = ValueNotifier(true);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<StatefulWidget> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(
        backgroundColor: pageBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          "Particle Music",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: highlightTextColor,
          ),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: updateColorNotifier,
        builder: (context, value, child) {
          return ValueListenableBuilder(
            valueListenable: displayLibraryNotifier,
            builder: (context, value, child) {
              return value ? buildLibrary(context) : SettingsList(iconSize: 30);
            },
          );
        },
      ),
    );
  }

  Widget buildLibrary(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      physics: ClampingScrollPhysics(),
      children: [
        ListTile(
          leading: ImageIcon(playlistsImage, size: 35, color: iconColor),
          title: Text(l10n.playlists),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => PlaylistsPage()));
          },
        ),
        ListTile(
          leading: ImageIcon(artistImage, size: 35, color: iconColor),
          title: Text(l10n.artists),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => ArtistsPage()));
          },
        ),
        ListTile(
          leading: ImageIcon(albumImage, size: 35, color: iconColor),
          title: Text(l10n.albums),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => AlbumsPage()));
          },
        ),

        ListTile(
          leading: ImageIcon(folderImage, size: 35, color: iconColor),
          title: Text(l10n.folders),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => FoldersPage()));
          },
        ),

        ListTile(
          leading: ImageIcon(songsImage, size: 35, color: iconColor),
          title: Text(l10n.songs),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => SongsPage()));
          },
        ),

        ListTile(
          leading: ImageIcon(rankingImage, size: 35, color: iconColor),
          title: Text(l10n.ranking),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => RankingPage()));
          },
        ),

        ListTile(
          leading: ImageIcon(recentlyImage, size: 35, color: iconColor),
          title: Text(l10n.recently),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => RecentlyPage()));
          },
        ),
      ],
    );
  }
}
