import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/portrait_view/pages/local_navidrome_pageview.dart';

class SongsPage extends StatelessWidget {
  const SongsPage({super.key});

  @override
  Widget build(BuildContext _) {
    return LocalNavidromePageview(
      displayNavidromeNotifier: library.displayNavidromeNotifier,
      localSongList: library.songList,
      navidromeSongList: library.navidromeSongList,
    );
  }
}
