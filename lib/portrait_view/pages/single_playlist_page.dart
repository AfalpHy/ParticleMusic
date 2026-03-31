import 'package:flutter/material.dart';
import 'package:particle_music/portrait_view/pages/local_navidrome_pageview.dart';
import 'package:particle_music/playlists.dart';

class SinglePlaylistPage extends StatelessWidget {
  final Playlist playlist;
  const SinglePlaylistPage({super.key, required this.playlist});
  @override
  Widget build(BuildContext context) {
    return LocalNavidromePageview(
      displayNavidromeNotifier: playlist.displayNavidromeNotifier,
      localSongList: playlist.songList,
      navidromeSongList: playlist.navidromeSongList,
      playlist: playlist,
    );
  }
}
