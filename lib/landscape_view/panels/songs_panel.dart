import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/landscape_view/panels/local_navidrome_panel.dart';

class SongsPanel extends StatelessWidget {
  const SongsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return LocalNavidromePanel(
      displayNavidromeNotifier: library.displayNavidromeNotifier,
      localSongList: library.songList,
      navidromeSongList: library.navidromeSongList,
    );
  }
}
