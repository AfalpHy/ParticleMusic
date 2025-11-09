import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/playlists.dart';

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
              TitleBar(hintText: 'Search folders'),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 200,
                      child: ListView.builder(
                        itemCount: folderPaths.length,
                        itemBuilder: (_, index) {
                          return ListTile(
                            title: Text(
                              folderPaths[index],
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12),
                            ),
                            onTap: () {
                              currentFolderNotifier.value = folderPaths[index];
                            },
                          );
                        },
                      ),
                    ),
                    VerticalDivider(
                      thickness: 0.5,
                      width: 1,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable: currentFolderNotifier,
                        builder: (context, currentFolder, child) {
                          final songList = folder2SongList[currentFolder];
                          if (songList == null) {
                            return SizedBox.shrink();
                          }
                          return ListView.builder(
                            itemCount: songList.length,
                            itemBuilder: (_, index) {
                              final song = songList[index];
                              return Row(
                                children: [
                                  Expanded(
                                    child: ListTile(
                                      contentPadding: EdgeInsets.fromLTRB(
                                        0,
                                        0,
                                        0,
                                        0,
                                      ),
                                      visualDensity: const VisualDensity(
                                        horizontal: 0,
                                        vertical: -4,
                                      ),
                                      leading: CoverArtWidget(
                                        size: 40,
                                        borderRadius: 4,
                                        source: getCoverArt(song),
                                      ),
                                      title: ValueListenableBuilder(
                                        valueListenable: currentSongNotifier,
                                        builder: (_, currentSong, _) {
                                          return Text(
                                            getTitle(song),
                                            overflow: TextOverflow.ellipsis,
                                            style: song == currentSong
                                                ? TextStyle(
                                                    color: Color.fromARGB(
                                                      255,
                                                      75,
                                                      200,
                                                      200,
                                                    ),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  )
                                                : TextStyle(fontSize: 15),
                                          );
                                        },
                                      ),
                                      subtitle: Text(
                                        '${getArtist(song)} - ${getAlbum(song)}',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),

                                  SizedBox(width: 30),

                                  SizedBox(width: 20),
                                  SizedBox(
                                    width: 80,
                                    child: Align(
                                      alignment: AlignmentGeometry.centerLeft,
                                      child: IconButton(
                                        onPressed: () {
                                          toggleFavoriteState(song);
                                        },
                                        icon: ValueListenableBuilder(
                                          valueListenable:
                                              songIsFavorite[song]!,
                                          builder: (context, value, child) {
                                            return value
                                                ? Icon(
                                                    Icons.favorite_rounded,
                                                    color: Colors.red,
                                                    size: 20,
                                                  )
                                                : Icon(
                                                    Icons.favorite_outline,
                                                    size: 20,
                                                  );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),

                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      formatDuration(getDuration(song)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
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
