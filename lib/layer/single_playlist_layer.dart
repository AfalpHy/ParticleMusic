import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/landscape_view/panels/single_playlist_panel.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/portrait_view/pages/single_playlist_page.dart';

class SinglePlaylistLayer extends StatelessWidget {
  final Playlist playlist;

  const SinglePlaylistLayer({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (isMobile && orientation == Orientation.portrait) {
          return SinglePlaylistPage(playlist: playlist);
        } else {
          return SinglePlaylistPanel(playlist: playlist);
        }
      },
    );
  }
}
