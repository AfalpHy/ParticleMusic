import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/landscape_view/panels/single_artist_panel.dart';
import 'package:particle_music/portrait_view/pages/single_artist_page.dart';

class SingleArtistLayer extends StatelessWidget {
  final Artist artist;
  const SingleArtistLayer({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return SingleArtistPage(artist: artist);
        } else {
          return SingleArtistPanel(artist: artist);
        }
      },
    );
  }
}
