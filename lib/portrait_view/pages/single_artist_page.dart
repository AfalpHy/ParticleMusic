import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/portrait_view/pages/local_navidrome_page.dart';

class SingleArtistPage extends StatelessWidget {
  final Artist artist;
  const SingleArtistPage({super.key, required this.artist});
  @override
  Widget build(BuildContext context) {
    return LocalNavidromePage(
      displayNavidromeNotifier: artist.displayNavidromeNotifier,
      localSongList: artist.songList,
      navidromeSongList: artist.navidromeSongList,
      artist: artist,
    );
  }
}
