import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/mobile/pages/song_list_page.dart';
import 'package:smooth_corner/smooth_corner.dart';

class FoldersPage extends StatelessWidget {
  const FoldersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Folders'),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: folderPaths.length,
        itemBuilder: (_, index) {
          final folder = folderPaths[index];
          final songList = folder2SongList[folder]!;
          return SmoothClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ListTile(
              leading: CoverArtWidget(
                size: 40,
                borderRadius: 4,
                source: songList.isNotEmpty
                    ? getCoverArt(songList.first)
                    : null,
              ),
              title: Text(folder),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SongListPage(
                      songList: songList,
                      name: folder,
                      moreSheet: (context) =>
                          moreSheet(context, folder, songList),
                    ),
                  ),
                );
              },
            ),
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
              width: appWidth * 0.9,
              child: Row(
                children: [
                  Text('Folders', style: TextStyle(fontSize: 15)),
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
            leading: const ImageIcon(selectImage, color: Colors.black),
            title: Text(
              'Select',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SelectableSongListPage(songList: songList),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
