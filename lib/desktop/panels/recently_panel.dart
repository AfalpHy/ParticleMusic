import 'package:flutter/material.dart';
import 'package:particle_music/desktop/panels/song_list_panel.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

class RecentlyPanel extends StatelessWidget {
  final textController = TextEditingController();
  RecentlyPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        TitleBar(
          searchField: TitleSearchField(
            key: ValueKey(l10n.searchSongs),
            hintText: l10n.searchSongs,
            textController: textController,
          ),
        ),

        Expanded(
          child: SongListPanel(
            key: UniqueKey(),
            recently: AppLocalizations.of(context).recently,
            textController: textController,
          ),
        ),
      ],
    );
  }
}
