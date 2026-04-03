import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/portrait_view/pages/song_list_page.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/playlists.dart';

class LocalNavidromePage extends StatelessWidget {
  final Playlist? playlist;
  final Artist? artist;
  final Album? album;
  final String? ranking;
  final String? recently;

  final ValueNotifier<bool> displayNavidromeNotifier;
  final List<MyAudioMetadata> localSongList;
  final List<MyAudioMetadata> navidromeSongList;

  const LocalNavidromePage({
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
    return ValueListenableBuilder(
      valueListenable: displayNavidromeNotifier,
      builder: (context, value, child) {
        return SongListPage(
          key: UniqueKey(),
          playlist: playlist,
          artist: artist,
          album: album,
          ranking: ranking,
          recently: recently,
          isNavidrome: value,

          switchCallBack:
              localSongList.isNotEmpty && navidromeSongList.isNotEmpty
              ? () {
                  displayNavidromeNotifier.value =
                      !displayNavidromeNotifier.value;
                  layersManager.updateBackground();
                }
              : null,
        );
      },
    );
  }
}
