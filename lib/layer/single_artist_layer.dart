import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/widgets/switchable_song_list.dart';

class SingleArtistLayer extends StatelessWidget {
  final Artist artist;
  const SingleArtistLayer({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    return SwitchableSongList(
      songListManager: artist.songListManager,
      artist: artist,
      isRoot: false,
    );
  }
}
