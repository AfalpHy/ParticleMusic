import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/widgets/switchable_song_list.dart';

class RankingLayer extends StatelessWidget {
  const RankingLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return SwitchableSongList(
      songListManager: history.rankingSongListManager,
      isRanking: true,
    );
  }
}
