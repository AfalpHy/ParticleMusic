import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/mobile/pages/local_navidrome_pageview.dart';

class RecentlyPage extends StatelessWidget {
  const RecentlyPage({super.key});
  @override
  Widget build(BuildContext context) {
    return LocalNavidromePageview(
      displayNavidromeNotifier: history.displayNavidromeRecentlyNotifier,
      localSongList: history.recentlySongList,
      navidromeSongList: history.navidromeRecentlySongList,
      recently: AppLocalizations.of(context).recently,
    );
  }
}
