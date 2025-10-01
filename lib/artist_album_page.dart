import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/art_widget.dart';
import 'package:particle_music/song_list_tile.dart';

Map<String, List<AudioMetadata>> artist2SongList = {};
Map<String, List<AudioMetadata>> album2SongList = {};

Widget artistAlbumScaffold(bool isArtist) {
  final songListMap = isArtist ? artist2SongList : album2SongList;
  return Scaffold(
    backgroundColor: Colors.white,
    resizeToAvoidBottomInset: false,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(isArtist ? "Artists" : "Albums"),
    ),
    body: GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.88,
      ),
      itemCount: songListMap.length,
      itemBuilder: (context, index) {
        final key = songListMap.keys.elementAt(index);
        final songList = songListMap[key];
        return Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(
                MediaQuery.widthOf(context) * 0.4 / 20,
              ),

              child: ArtWidget(
                size: MediaQuery.widthOf(context) * 0.4,
                borderRadius: MediaQuery.widthOf(context) * 0.4 / 20,
                source: songList!.first.pictures.isNotEmpty
                    ? songList.first.pictures.first
                    : null,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => songListScafflod(songList)),
                );
              },
            ),
            SizedBox(height: 10),
            Text(key, style: TextStyle(overflow: TextOverflow.ellipsis)),
          ],
        );
      },
    ),
  );
}

Widget songListScafflod(List<AudioMetadata> songList) {
  return Scaffold(
    backgroundColor: Colors.white,
    resizeToAvoidBottomInset: false,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    body: ListView.builder(
      itemCount: songList.length,
      itemBuilder: (_, index) {
        return SongListTile(index: index, source: songList);
      },
    ),
  );
}
