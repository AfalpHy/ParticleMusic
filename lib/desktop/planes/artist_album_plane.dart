import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/plane_manager.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/metadata.dart';
import 'package:smooth_corner/smooth_corner.dart';

class ArtistAlbumPlane extends StatefulWidget {
  final bool isArtist;

  const ArtistAlbumPlane({super.key, required this.isArtist});

  @override
  State<StatefulWidget> createState() => ArtistAlbumPlaneState();
}

class ArtistAlbumPlaneState extends State<ArtistAlbumPlane> {
  late bool isArtist;
  late Widget searchField;
  late Map<String, List<AudioMetadata>> songListMap;
  late ValueNotifier<Map<String, List<AudioMetadata>>> songListMapNotifier;

  @override
  void initState() {
    super.initState();
    isArtist = widget.isArtist;
    songListMap = isArtist ? artist2SongList : album2SongList;
    songListMapNotifier = ValueNotifier(songListMap);

    searchField = titleSearchField(
      'Search ${isArtist ? 'Artists' : 'Albums'}',
      textController: TextEditingController(),
      onChanged: (value) {
        songListMapNotifier.value = Map.fromEntries(
          songListMap.entries.where(
            (e) => (e.key.toLowerCase().contains(value.toLowerCase())),
          ),
        );
      },
    );
    titleSearchFieldStack.add(searchField);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateTitleSearchField.value++;
    });
  }

  @override
  void dispose() {
    titleSearchFieldStack.remove(searchField);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateTitleSearchField.value++;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planeWidth = (MediaQuery.widthOf(context) - 300);
    final crossAxisCount = (planeWidth / 180).toInt();
    final coverArtWidth = planeWidth / crossAxisCount - 60;

    return Material(
      color: Color.fromARGB(255, 235, 240, 245),

      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Material(
                      color: Colors.white54,
                      shape: SmoothRectangleBorder(
                        smoothness: 1,
                        borderRadius: BorderRadius.circular(10),
                      ),

                      child: ListTile(
                        leading: isArtist
                            ? const ImageIcon(
                                artistImage,
                                size: 50,
                                color: mainColor,
                              )
                            : const ImageIcon(
                                albumImage,
                                size: 50,
                                color: mainColor,
                              ),
                        title: Text(
                          isArtist ? 'Artists' : 'Albums',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: ValueListenableBuilder(
                          valueListenable: songListMapNotifier,
                          builder: (context, currentSongListMap, child) {
                            return Text(
                              '${currentSongListMap.length} in total',
                              style: TextStyle(fontSize: 12),
                            );
                          },
                        ),
                        trailing: SizedBox(
                          width: 100,
                          child: Row(children: [
                         
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 15)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),

                  sliver: ValueListenableBuilder(
                    valueListenable: songListMapNotifier,
                    builder: (context, currentSongListMap, child) {
                      return SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 1.16,
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
                                  child: ValueListenableBuilder(
                                    valueListenable:
                                        songIsUpdated[songList!.first]!,
                                    builder: (_, _, _) {
                                      return CoverArtWidget(
                                        size: coverArtWidth,
                                        borderRadius: 10,
                                        source: getCoverArt(songList.first),
                                      );
                                    },
                                  ),
                                  onTap: () {
                                    planeManager.pushPlane(
                                      isArtist ? 3 : 4,
                                      title: key,
                                    );
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
        ],
      ),
    );
  }
}
