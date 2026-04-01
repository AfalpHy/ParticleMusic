import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/portrait_view/pages/local_navidrome_pageview.dart';

class SingleAlbumPage extends StatelessWidget {
  final Album album;
  const SingleAlbumPage({super.key, required this.album});
  @override
  Widget build(BuildContext context) {
    return LocalNavidromePageview(
      displayNavidromeNotifier: album.displayNavidromeNotifier,
      localSongList: album.songList,
      navidromeSongList: album.navidromeSongList,
      album: album,
    );
  }
}
