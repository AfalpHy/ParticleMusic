import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/panels/song_list_panel.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:smooth_corner/smooth_corner.dart';

class FoldersPanel extends StatelessWidget {
  final ValueNotifier<String> currentFolderNotifier;
  const FoldersPanel({super.key, required this.currentFolderNotifier});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (currentFolderNotifier.value == '') {
      currentFolderNotifier.value = l10n.folder;
    }
    return ValueListenableBuilder(
      valueListenable: folderChangeNotifier,
      builder: (_, _, _) {
        if (folderPathList.isNotEmpty) {
          currentFolderNotifier.value = folderPathList.first;
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
                  itemCount: folderPathList.length,
                  itemBuilder: (_, index) {
                    final folder = folderPathList[index];
                    return SmoothClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ValueListenableBuilder(
                        valueListenable: colorChangeNotifier,
                        builder: (_, value, child) {
                          return ValueListenableBuilder(
                            valueListenable: currentFolderNotifier,
                            builder: (_, currentFolder, _) {
                              return ValueListenableBuilder(
                                valueListenable: updateBackgroundNotifier,
                                builder: (_, _, _) {
                                  final highLightColor =
                                      enableCustomColorNotifier.value
                                      ? selectedItemColor
                                      : backgroundColor.withAlpha(75);
                                  return Material(
                                    color: currentFolder == folder
                                        ? highLightColor
                                        : Colors.transparent,
                                    child: child,
                                  );
                                },
                              );
                            },
                          );
                        },
                        child: ListTile(
                          title: Text(folder, style: TextStyle(fontSize: 12)),
                          onTap: () async {
                            currentFolderNotifier.value = folder;
                            panelManager.updateBackground();
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
      },
    );
  }
}
