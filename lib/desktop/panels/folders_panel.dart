import 'package:flutter/material.dart';
import 'package:particle_music/desktop/panels/song_list_panel.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/load_library.dart';
import 'package:smooth_corner/smooth_corner.dart';

class FoldersPanel extends StatelessWidget {
  const FoldersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder(
      valueListenable: foldersChangeNotifier,
      builder: (_, _, _) {
        final currentFolderNotifier = ValueNotifier(l10n.folder);
        if (folderPaths.isNotEmpty) {
          currentFolderNotifier.value = folderPaths.first;
        }
        return ValueListenableBuilder(
          valueListenable: currentFolderNotifier,
          builder: (context, currentFolder, child) {
            return SongListPanel(
              key: ValueKey(currentFolder),
              folder: currentFolder,
              foldersWidget: SizedBox(
                width: 200,

                child: ListView.builder(
                  itemCount: folderPaths.length,
                  itemBuilder: (_, index) {
                    final folder = folderPaths[index];
                    return SmoothClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ValueListenableBuilder(
                        valueListenable: currentFolderNotifier,
                        builder: (context, currentFolder, child) {
                          return Material(
                            color: currentFolder == folder
                                ? Colors.white
                                : Colors.transparent,
                            child: ListTile(
                              title: Text(
                                folder,
                                style: TextStyle(fontSize: 12),
                              ),
                              onTap: () {
                                currentFolderNotifier.value = folder;
                              },
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
