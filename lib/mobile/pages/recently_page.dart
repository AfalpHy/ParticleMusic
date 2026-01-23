import 'package:flutter/material.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/mobile/pages/song_list_page.dart';

class RecentlyPage extends StatelessWidget {
  const RecentlyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SongListPage(
      key: UniqueKey(),
      recently: AppLocalizations.of(context).recently,
    );
  }
}
