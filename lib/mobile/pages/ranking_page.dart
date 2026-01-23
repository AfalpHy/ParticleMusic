import 'package:flutter/material.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/mobile/pages/song_list_page.dart';

class RankingPage extends StatelessWidget {
  const RankingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SongListPage(
      key: UniqueKey(),
      ranking: AppLocalizations.of(context).ranking,
    );
  }
}
