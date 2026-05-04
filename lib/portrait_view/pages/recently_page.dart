import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/local_navidrome_base.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

class RecentlyPage extends StatelessWidget {
  const RecentlyPage({super.key});
  @override
  Widget build(BuildContext context) {
    return LocalNavidromeBase(
      displayNavidromeNotifier: history.displayNavidromeRecentlyNotifier,
      localSongList: history.recentlySongList,
      navidromeSongList: history.navidromeRecentlySongList,
      recently: AppLocalizations.of(context).recently,
      isPanel: false,
    );
  }
}
