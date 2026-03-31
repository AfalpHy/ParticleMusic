import 'package:flutter/material.dart';
import 'package:particle_music/landscape_view/panels/local_navidrome_panel.dart';
import 'package:particle_music/playlists.dart';

class SinglePlaylistPanel extends StatelessWidget {
  final Playlist playlist;

  const SinglePlaylistPanel({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return LocalNavidromePanel(
      displayNavidromeNotifier: playlist.displayNavidromeNotifier,
      localSongList: playlist.songList,
      navidromeSongList: playlist.navidromeSongList,
      playlist: playlist,
    );
  }
}
