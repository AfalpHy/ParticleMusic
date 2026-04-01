import 'package:flutter/material.dart';
import 'package:particle_music/landscape_view/panels/song_list_panel.dart';
import 'package:particle_music/landscape_view/title_bar.dart';
import 'package:particle_music/folder.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

class SingleFolderPanel extends StatelessWidget {
  final Folder folder;
  final textController = TextEditingController();

  SingleFolderPanel({super.key, required this.folder});

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
          child: Row(
            children: [
              Expanded(
                child: SongListPanel(
                  folder: folder,
                  textController: textController,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
