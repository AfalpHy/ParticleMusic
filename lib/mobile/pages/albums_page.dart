import 'package:flutter/material.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/mobile/pages/song_list_page.dart';
import 'package:searchfield/searchfield.dart';
import 'package:smooth_corner/smooth_corner.dart';

class AlbumsPage extends StatelessWidget {
  const AlbumsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final songListMapNotifier = ValueNotifier(album2SongList);
    final textController = TextEditingController();
    final ValueNotifier<bool> isSearchingNotifier = ValueNotifier(false);
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text("Albums"),
        centerTitle: true,
        actions: [
          ValueListenableBuilder(
            valueListenable: isSearchingNotifier,
            builder: (context, value, child) {
              return value
                  ? Expanded(
                      child: SizedBox(
                        height: 30,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: SearchField(
                            autofocus: true,
                            controller: textController,
                            suggestions: [],
                            searchInputDecoration: SearchInputDecoration(
                              hintText: 'Search Albums',
                              prefixIcon: Icon(Icons.search),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  isSearchingNotifier.value = false;
                                  songListMapNotifier.value = album2SongList;
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
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSearchTextChanged: (value) {
                              songListMapNotifier.value = Map.fromEntries(
                                album2SongList.entries.where(
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
                    )
                  : IconButton(
                      onPressed: () {
                        isSearchingNotifier.value = true;
                      },
                      icon: Icon(Icons.search),
                    );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: songListMapNotifier,
        builder: (context, currentSongListMap, child) {
          return GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.95,
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
                      borderRadius: BorderRadius.circular(appWidth * 0.025),
                    ),
                    child: InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: CoverArtWidget(
                        size: appWidth * 0.4,
                        borderRadius: appWidth * 0.025,
                        source: getCoverArt(songList!.first),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SongListPage(album: key),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 5),
                  SizedBox(
                    width: appWidth * 0.4 - 20,
                    child: Center(
                      child: Text(
                        key,
                        style: TextStyle(overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
