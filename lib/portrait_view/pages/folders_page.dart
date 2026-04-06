import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/portrait_view/custom_appbar_leading.dart';
import 'package:particle_music/utils.dart';

class FoldersPage extends StatelessWidget {
  const FoldersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: customAppBarLeading(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.folders),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: library.folderList.length,
        itemBuilder: (_, index) {
          final folder = library.folderList[index];
          return ListTile(
            leading: ValueListenableBuilder(
              valueListenable: folder.updateNotifier,
              builder: (context, value, child) {
                return CoverArtWidget(
                  size: 40,
                  borderRadius: 4,
                  song: getFirstSong(folder.songList),
                );
              },
            ),
            title: Text(folder.path),
            onTap: () {
              layersManager.pushLayer('folders', content: folder.path);
            },
          );
        },
      ),
    );
  }
}
