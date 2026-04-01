import 'package:flutter/material.dart';
import 'package:particle_music/landscape_view/panels/playlists_panel.dart';
import 'package:particle_music/portrait_view/pages/playlists_page.dart';

class PlaylistsLayer extends StatelessWidget {
  const PlaylistsLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return PlaylistsPage();
        } else {
          return PlaylistsPanel();
        }
      },
    );
  }
}
