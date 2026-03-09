import 'package:flutter/material.dart';
import 'package:particle_music/desktop/panels/song_list_panel.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

class SingleAlbumPanel extends StatelessWidget {
  final String album;
  final textController = TextEditingController();
  SingleAlbumPanel({super.key, required this.album});

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
            album: album,
            textController: textController,
          ),
        ),
      ],
    );
  }
}
