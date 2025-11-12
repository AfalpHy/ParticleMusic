import 'package:flutter/material.dart';
import 'package:particle_music/desktop/planes/song_list_plane.dart';
import 'package:particle_music/load_library.dart';
import 'package:smooth_corner/smooth_corner.dart';

class FoldersPlane extends StatelessWidget {
  const FoldersPlane({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: foldersChangeNotifier,
      builder: (_, _, _) {
        final currentFolderNotifier = ValueNotifier('');
        if (folderPaths.isNotEmpty) {
          currentFolderNotifier.value = folderPaths.first;
        }
        return Material(
          color: Color.fromARGB(255, 235, 240, 245),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable: currentFolderNotifier,
                        builder: (context, currentFolder, child) {
                          final songList = folder2SongList[currentFolder];
                          if (songList == null) {
                            return SizedBox.shrink();
                          }
                          return SongListPlane(
                            key: ValueKey(currentFolder),
                            folder: currentFolder,
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 5),

                    VerticalDivider(
                      thickness: 0.5,
                      width: 1,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(width: 10),

                    SizedBox(
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
                                      overflow: TextOverflow.ellipsis,
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
                    SizedBox(width: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
