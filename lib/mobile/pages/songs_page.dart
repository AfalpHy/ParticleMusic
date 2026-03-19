import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/mobile/pages/song_list_page.dart';

class SongsPage extends StatelessWidget {
  const SongsPage({super.key});

  @override
  Widget build(BuildContext _) {
    int pageCnt = 0;
    if (librarySongList.isNotEmpty) {
      pageCnt++;
    }
    if (navidromeSongList.isNotEmpty) {
      pageCnt++;
    }

    PageController pageController = PageController(
      initialPage: displayNavidromeSongsNotifier.value && pageCnt == 2 ? 1 : 0,
    );

    return PageView(
      onPageChanged: (value) {
        displayNavidromeSongsNotifier.value =
            !displayNavidromeSongsNotifier.value;
      },
      controller: pageController,
      children: [
        if (librarySongList.isNotEmpty || navidromeSongList.isEmpty)
          SongListPage(),
        if (navidromeSongList.isNotEmpty) SongListPage(isNavidrome: true),
      ],
    );
  }
}
