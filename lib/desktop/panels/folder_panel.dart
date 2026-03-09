import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/panels/song_list_panel.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/folder_manager.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:smooth_corner/smooth_corner.dart';

class FolderPanel extends StatelessWidget {
  final Folder folder;
  final textController = TextEditingController();

  FolderPanel({super.key, required this.folder});

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

              SizedBox(width: 5),

              ValueListenableBuilder(
                valueListenable: updateColorNotifier,
                builder: (context, value, child) {
                  return VerticalDivider(
                    thickness: 0.5,
                    width: 0.5,
                    color: dividerColor,
                  );
                },
              ),
              SizedBox(width: 10),

              SizedBox(
                width: 200,

                child: ListView.builder(
                  itemCount: folderManager.folderList.length,
                  itemBuilder: (_, index) {
                    final tmpFolder = folderManager.folderList[index];
                    return SmoothClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ValueListenableBuilder(
                        valueListenable: updateColorNotifier,
                        builder: (_, value, child) {
                          return Material(
                            color: tmpFolder == folder
                                ? selectedItemColor
                                : Colors.transparent,
                            child: child,
                          );
                        },
                        child: ListTile(
                          title: Text(
                            tmpFolder.path,
                            style: TextStyle(fontSize: 12),
                          ),
                          onTap: () async {
                            panelManager.pushPanel(
                              'folder',
                              content: tmpFolder.path,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),

              SizedBox(width: 10),
            ],
          ),
        ),
      ],
    );
  }
}
