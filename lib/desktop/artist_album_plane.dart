import 'package:flutter/material.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/load_library.dart';
import 'package:smooth_corner/smooth_corner.dart';

class ArtistAlbumPlane extends StatelessWidget {
  final bool isArtist;

  final void Function(String title) switchPlane;

  const ArtistAlbumPlane({
    super.key,
    required this.isArtist,
    required this.switchPlane,
  });

  @override
  Widget build(BuildContext context) {
    final songListMap = isArtist ? artist2SongList : album2SongList;
    final songListMapNotifer = ValueNotifier(songListMap);
    final planeWidth = (MediaQuery.widthOf(context) - 220);
    final crossAxisCount = (planeWidth / 200).toInt();
    final coverArtWidth = planeWidth / crossAxisCount - 50;

    return Expanded(
      child: Material(
        color: Color.fromARGB(255, 235, 240, 245),

        child: Column(
          children: [
            TitleBar(),

            Expanded(
              child: ValueListenableBuilder(
                valueListenable: songListMapNotifer,
                builder: (context, currentSongListMap, child) {
                  return GridView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 1.08,
                    ),
                    itemCount: currentSongListMap.length,
                    itemBuilder: (context, index) {
                      final key = currentSongListMap.keys.elementAt(index);
                      final songList = currentSongListMap[key];
                      return Column(
                        children: [
                          Material(
                            elevation: 1,
                            shape: SmoothRectangleBorder(
                              smoothness: 1,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: InkWell(
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              child: CoverArtWidget(
                                size: coverArtWidth,
                                borderRadius: 10,
                                source: getCoverArt(songList!.first),
                              ),
                              onTap: () {
                                switchPlane(key);
                              },
                            ),
                          ),
                          SizedBox(
                            width: coverArtWidth - 20,
                            child: Center(
                              child: Text(
                                key,
                                style: TextStyle(
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
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
    );
  }
}
