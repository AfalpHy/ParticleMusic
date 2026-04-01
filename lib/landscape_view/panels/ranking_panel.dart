import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/landscape_view/panels/local_navidrome_panel.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

class RankingPanel extends StatelessWidget {
  const RankingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return LocalNavidromePanel(
      displayNavidromeNotifier: history.displayNavidromeRankingNotifier,
      localSongList: history.rankingSongList,
      navidromeSongList: history.navidromeRankingSongList,
      ranking: AppLocalizations.of(context).ranking,
    );
  }
}
