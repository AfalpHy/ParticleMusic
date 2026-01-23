import 'package:flutter/material.dart';
import 'package:particle_music/desktop/panels/song_list_panel.dart';
import 'package:particle_music/history.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

class RecentlyPanel extends StatelessWidget {
  const RecentlyPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: recentlyChangeNotifier,
      builder: (_, _, _) {
        return SongListPanel(
          key: UniqueKey(),
          recently: AppLocalizations.of(context).recently,
        );
      },
    );
  }
}
