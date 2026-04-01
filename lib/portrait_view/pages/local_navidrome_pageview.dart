import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/portrait_view/pages/song_list_page.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/playlists.dart';

class LocalNavidromePageview extends StatelessWidget {
  final Playlist? playlist;
  final Artist? artist;
  final Album? album;
  final String? ranking;
  final String? recently;

  final ValueNotifier<bool> displayNavidromeNotifier;
  final List<MyAudioMetadata> localSongList;
  final List<MyAudioMetadata> navidromeSongList;

  const LocalNavidromePageview({
    super.key,
    this.playlist,
    this.artist,
    this.album,
    this.ranking,
    this.recently,

    required this.displayNavidromeNotifier,
    required this.localSongList,
    required this.navidromeSongList,
  });

  @override
  Widget build(BuildContext context) {
    if (playlist == null) {
      return pageView();
    }
    return ValueListenableBuilder(
      valueListenable: playlist!.updateNotifier,
      builder: (context, value, child) {
        return pageView();
      },
    );
  }

  Widget pageView() {
    int pageCnt = 0;
    if (localSongList.isNotEmpty) {
      pageCnt++;
    }
    if (navidromeSongList.isNotEmpty) {
      pageCnt++;
    }

    PageController pageController = PageController(
      initialPage: displayNavidromeNotifier.value && pageCnt == 2 ? 1 : 0,
    );

    return PageView(
      onPageChanged: (value) {
        displayNavidromeNotifier.value = !displayNavidromeNotifier.value;
        layersManager.updateBackground();
      },
      controller: pageController,
      children: [
        if (localSongList.isNotEmpty || navidromeSongList.isEmpty)
          SongListPage(
            key: UniqueKey(),
            playlist: playlist,
            artist: artist,
            album: album,
            ranking: ranking,
            recently: recently,
          ),
        if (navidromeSongList.isNotEmpty)
          SongListPage(
            key: UniqueKey(),
            playlist: playlist,
            artist: artist,
            album: album,
            ranking: ranking,
            recently: recently,
            isNavidrome: true,
          ),
      ],
    );
  }
}
