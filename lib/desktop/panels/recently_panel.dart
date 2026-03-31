import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/panels/local_navidrome_panel.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

class RecentlyPanel extends StatelessWidget {
  const RecentlyPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return LocalNavidromePanel(
      displayNavidromeNotifier: history.displayNavidromeRecentlyNotifier,
      localSongList: history.recentlySongList,
      navidromeSongList: history.navidromeRecentlySongList,
      recently: AppLocalizations.of(context).recently,
    );
  }
}
