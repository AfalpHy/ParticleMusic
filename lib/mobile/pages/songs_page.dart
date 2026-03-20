import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/mobile/pages/local_navidrome_pageview.dart';

class SongsPage extends StatelessWidget {
  const SongsPage({super.key});

  @override
  Widget build(BuildContext _) {
    return LocalNavidromePageview(
      displayNavidromeNotifier: displayNavidromeSongsNotifier,
      localSongList: librarySongList,
      navidromeSongList: navidromeSongList,
    );
  }
}
