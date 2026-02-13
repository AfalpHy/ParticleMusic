import 'package:flutter/material.dart';
import 'package:particle_music/desktop/panels/song_list_panel.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

class RankingRanel extends StatelessWidget {
  const RankingRanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SongListPanel(
      key: UniqueKey(),
      ranking: AppLocalizations.of(context).ranking,
    );
  }
}
