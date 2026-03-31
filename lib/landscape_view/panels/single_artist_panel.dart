import 'package:flutter/material.dart';
import 'package:particle_music/artist_album_manager.dart';
import 'package:particle_music/landscape_view/panels/local_navidrome_panel.dart';

class SingleArtistPanel extends StatelessWidget {
  final Artist artist;
  const SingleArtistPanel({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    return LocalNavidromePanel(
      displayNavidromeNotifier: artist.displayNavidromeNotifier,
      localSongList: artist.songList,
      navidromeSongList: artist.navidromeSongList,
      artist: artist,
    );
  }
}
