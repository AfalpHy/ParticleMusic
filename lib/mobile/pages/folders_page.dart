import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/mobile/pages/song_list_page.dart';
import 'package:particle_music/utils.dart';

class FoldersPage extends StatelessWidget {
  const FoldersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: commonColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: commonColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.folders),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: folderPathList.length,
        itemBuilder: (_, index) {
          final folder = folderPathList[index];
          final songList = folder2SongList[folder]!;
          return ListTile(
            leading: CoverArtWidget(
              size: 40,
              borderRadius: 4,
              song: getFirstSong(songList),
            ),
            title: Text(folder),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SongListPage(folder: folder)),
              );
            },
          );
        },
      ),
    );
  }
}
