import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/mobile/pages/local_navidrome_pageview.dart';

class RankingPage extends StatelessWidget {
  const RankingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LocalNavidromePageview(
      displayNavidromeNotifier: historyManager.displayNavidromeRankingNotifier,
      localSongList: historyManager.rankingSongList,
      navidromeSongList: historyManager.navidromeRankingSongList,
      ranking: AppLocalizations.of(context).ranking,
    );
  }
}
