import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/landscape_view/panels/song_list_panel.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/portrait_view/pages/song_list_page.dart';

class LocalNavidromeBase extends StatelessWidget {
  final Playlist? playlist;
  final Artist? artist;
  final Album? album;
  final String? ranking;

  final String? recently;

  final ValueNotifier<bool> displayNavidromeNotifier;
  final List<MyAudioMetadata> localSongList;
  final List<MyAudioMetadata> navidromeSongList;

  final bool isPanel;

  const LocalNavidromeBase({
    super.key,
    this.playlist,
    this.artist,
    this.album,
    this.ranking,
    this.recently,

    required this.displayNavidromeNotifier,
    required this.localSongList,
    required this.navidromeSongList,
    required this.isPanel,
  });

  Function()? get switchCallBack {
    return localSongList.isNotEmpty && navidromeSongList.isNotEmpty
        ? () {
            displayNavidromeNotifier.value = !displayNavidromeNotifier.value;
            layersManager.updateBackground();
          }
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: displayNavidromeNotifier,
      builder: (context, value, child) {
        return Stack(
          children: [
            if (localSongList.isNotEmpty || navidromeSongList.isEmpty)
              Visibility(
                visible: !value,
                maintainState: true,
                child: isPanel ? panel(false) : page(false),
              ),

            if (navidromeSongList.isNotEmpty)
              Visibility(
                visible: value,
                maintainState: true,
                child: isPanel ? panel(true) : page(true),
              ),
          ],
        );
      },
    );
  }

  Widget panel(bool isNavidrome) {
    return SongListPanel(
      playlist: playlist,
      artist: artist,
      album: album,
      ranking: ranking,
      recently: recently,
      isNavidrome: isNavidrome,

      switchCallBack: switchCallBack,
    );
  }

  Widget page(bool isNavidrome) {
    return SongListPage(
      playlist: playlist,
      artist: artist,
      album: album,
      ranking: ranking,
      recently: recently,
      isNavidrome: isNavidrome,

      switchCallBack: switchCallBack,
    );
  }
}
