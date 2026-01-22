import 'package:flutter/material.dart';
import 'package:particle_music/desktop/panels/song_list_panel.dart';
import 'package:particle_music/history.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

class HistoryPanel extends StatelessWidget {
  const HistoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: historyChangeNotifier,
      builder: (_, _, _) {
        return SongListPanel(
          key: UniqueKey(),
          history: AppLocalizations.of(context).history,
        );
      },
    );
  }
}
