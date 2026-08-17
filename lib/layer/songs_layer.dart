import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/widgets/switchable_song_list.dart';

class SongsLayer extends StatelessWidget {
  const SongsLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return SwitchableSongList(songListManager: library.songListManager);
  }
}
