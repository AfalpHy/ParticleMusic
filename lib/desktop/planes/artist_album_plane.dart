import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
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

  final useBigPictureNotifier = ValueNotifier(true);

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

    return ValueListenableBuilder(
      valueListenable: useBigPictureNotifier,
      builder: (context, value, child) {
        int crossAxisCount;
        double coverArtWidth;
        if (value) {
          crossAxisCount = (planeWidth / 240).toInt();
          coverArtWidth = planeWidth / crossAxisCount - 40;
        } else {
          crossAxisCount = (planeWidth / 120).toInt();
          coverArtWidth = planeWidth / crossAxisCount - 30;
        }

        return Material(
          color: Color.fromARGB(255, 235, 240, 245),

          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
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
                            width: 120,
                            child: Column(
                              children: [
                                SizedBox(height: 20),
                                Row(
                                  children: [
                                    Spacer(),
                                    Text(value ? 'Large' : 'Small'),
                                    SizedBox(width: 10),
                                    FlutterSwitch(
                                      width: 45,
                                      height: 20,
                                      toggleSize: 15,
                                      activeColor: mainColor,
                                      inactiveColor: Colors.grey.shade300,
                                      value: value,
                                      onToggle: (value) async {
                                        useBigPictureNotifier.value = value;
                                      },
                                    ),
                                    Spacer(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),

                        child: Divider(
                          thickness: 1,
                          height: 1,
                          color: Colors.grey.shade300,
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
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: 1.05,
                                ),
                            itemCount: currentSongListMap.length,
                            itemBuilder: (context, index) {
                              final key = currentSongListMap.keys.elementAt(
                                index,
                              );
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
      },
    );
  }
}
