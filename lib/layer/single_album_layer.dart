import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/widgets/switchable_song_list.dart';

class SingleAlbumLayer extends StatelessWidget {
  final Album album;
  const SingleAlbumLayer({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    return SwitchableSongList(
      songListManager: album.songListManager,
      album: album,
      isRoot: false,
    );
  }
}
