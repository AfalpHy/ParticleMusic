import 'package:flutter/material.dart';
import 'package:particle_music/artist_album_manager.dart';
import 'package:particle_music/landscape_view/panels/local_navidrome_panel.dart';

class SingleAlbumPanel extends StatelessWidget {
  final Album album;
  const SingleAlbumPanel({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    return LocalNavidromePanel(
      displayNavidromeNotifier: album.displayNavidromeNotifier,
      localSongList: album.songList,
      navidromeSongList: album.navidromeSongList,
      album: album,
    );
  }
}
