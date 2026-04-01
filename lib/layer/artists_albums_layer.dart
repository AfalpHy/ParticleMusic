import 'package:flutter/material.dart';
import 'package:particle_music/landscape_view/panels/artists_albums_panel.dart';
import 'package:particle_music/portrait_view/pages/albums_page.dart';
import 'package:particle_music/portrait_view/pages/artists_page.dart';

class ArtistsAlbumsLayer extends StatelessWidget {
  final bool isArtist;

  const ArtistsAlbumsLayer({super.key, required this.isArtist});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return isArtist ? ArtistsPage() : AlbumsPage();
        } else {
          return ArtistsAlbumsPanel(isArtist: isArtist);
        }
      },
    );
  }
}
