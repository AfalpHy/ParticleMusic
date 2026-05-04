import 'package:flutter/material.dart';
import 'package:particle_music/common_widgets/local_navidrome_base.dart';
import 'package:particle_music/playlists.dart';

class SinglePlaylistPanel extends StatelessWidget {
  final Playlist playlist;

  const SinglePlaylistPanel({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return LocalNavidromeBase(
      displayNavidromeNotifier: playlist.displayNavidromeNotifier,
      localSongList: playlist.songList,
      navidromeSongList: playlist.navidromeSongList,
      playlist: playlist,
      isPanel: true,
    );
  }
}
