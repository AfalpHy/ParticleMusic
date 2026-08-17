import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/widgets/switchable_song_list.dart';

class RecentlyLayer extends StatelessWidget {
  const RecentlyLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return SwitchableSongList(
      songListManager: history.recentlySongListManager,
      isRecently: true,
    );
  }
}
