import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/playlists.dart';
import 'package:smooth_corner/smooth_corner.dart';

class SongListPlane extends StatelessWidget {
  final ValueNotifier<List<AudioMetadata>> currentSongListNotifier;
  final ValueNotifier<Playlist?> currentPlaylistNotifier;

  const SongListPlane({
    super.key,
    required this.currentSongListNotifier,
    required this.currentPlaylistNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final songListWidth = MediaQuery.widthOf(context);
    final albumWidth = songListWidth * 0.25;
    return Expanded(
      child: Material(
        color: Color.fromARGB(255, 235, 240, 245),
        child: Column(
          children: [
            TitleBar(),

            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: ValueListenableBuilder(
                      valueListenable: currentPlaylistNotifier,
                      builder: (context, playlist, _) {
                        if (playlist == null) {
                          return SizedBox.shrink();
                        }
                        return playlistHeader(playlist);
                      },
                    ),
                  ),

                  SliverToBoxAdapter(child: contentHeader(albumWidth)),

                  ValueListenableBuilder(
                    valueListenable: currentSongListNotifier,
                    builder: (context, currentSongList, child) {
                      return SliverPrototypeExtentList(
                        prototypeItem: ListTile(
                          contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 0),
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                          leading: CoverArtWidget(
                            size: 40,
                            borderRadius: 4,
                            source: null,
                          ),
                          title: Text('title'),
                          subtitle: Text('subtitle'),
                        ),
                        delegate: SliverChildBuilderDelegate(
                          childCount: currentSongList.length,
                          (context, index) {
                            return songListTile(
                              currentSongList,
                              index,
                              albumWidth,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget playlistHeader(Playlist playlist) {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: 30),
            Material(
              elevation: 5,
              shape: SmoothRectangleBorder(
                smoothness: 1,
                borderRadius: BorderRadius.circular(10),
              ),
              child: CoverArtWidget(
                size: 200,
                borderRadius: 10,
                source: playlist.songs.isNotEmpty
                    ? getCoverArt(playlist.songs.first)
                    : null,
              ),
            ),

            Expanded(
              child: ListTile(
                title: AutoSizeText(
                  playlist.name,
                  maxLines: 1,
                  minFontSize: 20,
                  maxFontSize: 20,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("${playlist.songs.length} songs"),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
      ],
    );
  }

  Widget contentHeader(double albumWidth) {
    return SizedBox(
      height: 50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Row(
          children: [
            SizedBox(width: 60, child: Center(child: Text('#'))),
            Expanded(child: Text('Title', overflow: TextOverflow.ellipsis)),
            SizedBox(width: 30),

            SizedBox(
              width: albumWidth,
              child: Text('Album', overflow: TextOverflow.ellipsis),
            ),
            SizedBox(width: 30),

            SizedBox(
              width: 80,
              child: Text('Duration', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget songListTile(
    List<AudioMetadata> currentSongList,
    int index,
    double albumWidth,
  ) {
    final song = currentSongList[index];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: SmoothClipRRect(
        smoothness: 1,
        borderRadius: BorderRadius.circular(15),
        child: Material(
          color: Color.fromARGB(255, 235, 240, 245),
          child: InkWell(
            onDoubleTap: () async {
              audioHandler.currentIndex = index;
              playQueue = List.from(currentSongList);
              if (playModeNotifier.value == 1 ||
                  (playModeNotifier.value == 2 &&
                      audioHandler.tmpPlayMode == 1)) {
                audioHandler.shuffle();
              }
              await audioHandler.load();
              await audioHandler.play();
            },

            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Center(
                    child: Text(
                      (index + 1).toString(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 0),
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
                                  color: Color.fromARGB(255, 75, 200, 200),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                )
                              : TextStyle(fontSize: 15),
                        );
                      },
                    ),
                    subtitle: Text(
                      getArtist(song),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ),
                SizedBox(width: 30),
                SizedBox(
                  width: albumWidth,
                  child: Text(getAlbum(song), overflow: TextOverflow.ellipsis),
                ),
                SizedBox(width: 30),

                SizedBox(
                  width: 80,
                  child: Text(
                    formatDuration(getDuration(song)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
