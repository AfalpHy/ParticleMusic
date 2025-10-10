import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/song_list_scaffold.dart';
import 'package:searchfield/searchfield.dart';
import 'package:smooth_corner/smooth_corner.dart';

Map<String, List<AudioMetadata>> artist2SongList = {};
Map<String, List<AudioMetadata>> album2SongList = {};

class ArtistAlbumScaffold extends StatelessWidget {
  final bool isArtist;
  const ArtistAlbumScaffold({super.key, required this.isArtist});

  @override
  Widget build(BuildContext context) {
    final songListMap = isArtist ? artist2SongList : album2SongList;
    final songListMapNotifer = ValueNotifier(songListMap);
    final textController = TextEditingController();
    final ValueNotifier<bool> isSearch = ValueNotifier(false);
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(isArtist ? "Artists" : "Albums"),
        centerTitle: true,
        actions: [
          ValueListenableBuilder(
            valueListenable: isSearch,
            builder: (context, value, child) {
              if (value) {
                return Expanded(
                  child: Row(
                    children: [
                      SizedBox(width: 20),
                      Expanded(
                        child: SizedBox(
                          height: 35,
                          child: SearchField(
                            autofocus: true,
                            controller: textController,
                            suggestions: [],
                            searchInputDecoration: SearchInputDecoration(
                              hintText:
                                  'Search ${isArtist ? "Artists" : "Albums"}',
                              prefixIcon: Icon(Icons.search),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  isSearch.value = false;
                                  songListMapNotifer.value = songListMap;
                                  textController.clear();
                                  FocusScope.of(context).unfocus();
                                },
                                icon: Icon(Icons.clear),
                                padding: EdgeInsets.zero,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSearchTextChanged: (value) {
                              songListMapNotifer.value = Map.fromEntries(
                                songListMap.entries.where(
                                  (e) => (e.key.toLowerCase().contains(
                                    value.toLowerCase(),
                                  )),
                                ),
                              );

                              return null;
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: 20),
                    ],
                  ),
                );
              }
              return IconButton(
                onPressed: () {
                  isSearch.value = true;
                },
                icon: Icon(Icons.search),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: songListMapNotifer,
        builder: (context, currentSongListMap, child) {
          return GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.88,
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
                      borderRadius: BorderRadius.circular(
                        MediaQuery.widthOf(context) * 0.4 / 15,
                      ),
                    ),
                    child: InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: ArtWidget(
                        size: MediaQuery.widthOf(context) * 0.4,
                        borderRadius: MediaQuery.widthOf(context) * 0.4 / 15,
                        source: songList!.first.pictures.isNotEmpty
                            ? songList.first.pictures.first
                            : null,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SongListScaffold(
                              songList: songList,
                              name: key,
                              moreSheet: (context) =>
                                  moreSheet(context, key, songList),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          key,
                          style: TextStyle(overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      SizedBox(width: 10),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget moreSheet(
    BuildContext context,
    String name,
    List<AudioMetadata> songList,
  ) {
    return mySheet(
      Column(
        children: [
          ListTile(
            title: SizedBox(
              height: 40,
              width: MediaQuery.of(context).size.width * 0.9,
              child: Row(
                children: [
                  Text(
                    (isArtist ? 'Artist: ' : 'Album: '),
                    style: TextStyle(fontSize: 15),
                  ),
                  Expanded(
                    child: MyAutoSizeText(
                      name,
                      maxLines: 1,
                      textStyle: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(thickness: 0.5, height: 1, color: Colors.grey.shade300),
          ListTile(
            leading: Icon(Icons.reorder_rounded),
            title: Text(
              'Select',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      MultifunctionalSongListScaffold(songList: songList),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
