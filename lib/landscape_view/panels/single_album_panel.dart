import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/common_widgets/local_navidrome_base.dart';

class SingleAlbumPanel extends StatelessWidget {
  final Album album;
  const SingleAlbumPanel({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    return LocalNavidromeBase(
      displayNavidromeNotifier: album.displayNavidromeNotifier,
      localSongList: album.songList,
      navidromeSongList: album.navidromeSongList,
      album: album,
      isPanel: true,
    );
  }
}
