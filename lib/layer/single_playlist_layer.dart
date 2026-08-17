import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/widgets/switchable_song_list.dart';
import 'package:sylvakru/base/data/playlist.dart';

class SinglePlaylistLayer extends StatelessWidget {
  final Playlist playlist;
  final bool isRoot;

  const SinglePlaylistLayer({
    super.key,
    required this.playlist,
    required this.isRoot,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchableSongList(
      playlist: playlist,
      songListManager: playlist.songListManager,
      isRoot: isRoot,
    );
  }
}
