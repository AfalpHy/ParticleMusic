import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/panels/song_list_panel.dart';
import 'package:particle_music/folder_manager.dart';
import 'package:smooth_corner/smooth_corner.dart';

class FoldersPanel extends StatelessWidget {
  final ValueNotifier<Folder> currentFolderNotifier;
  const FoldersPanel({super.key, required this.currentFolderNotifier});

  @override
  Widget build(BuildContext context) {
    currentFolderNotifier.value = folderManager.folderList.first;
    return ValueListenableBuilder(
      valueListenable: currentFolderNotifier,
      builder: (context, currentFolder, child) {
        return SongListPanel(
          key: ValueKey(currentFolder),
          folder: currentFolder,
          foldersWidget: SizedBox(
            width: 200,

            child: ListView.builder(
              itemCount: folderManager.folderList.length,
              itemBuilder: (_, index) {
                final folder = folderManager.folderList[index];
                return SmoothClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ValueListenableBuilder(
                    valueListenable: updateColorNotifier,
                    builder: (_, value, child) {
                      return ValueListenableBuilder(
                        valueListenable: currentFolderNotifier,
                        builder: (_, currentFolder, _) {
                          return Material(
                            color: currentFolder == folder
                                ? selectedItemColor
                                : Colors.transparent,
                            child: child,
                          );
                        },
                      );
                    },
                    child: ListTile(
                      title: Text(folder.path, style: TextStyle(fontSize: 12)),
                      onTap: () async {
                        currentFolderNotifier.value = folder;
                        await panelManager.updateBackground();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
