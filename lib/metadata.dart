import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:smooth_corner/smooth_corner.dart';

void showSongMetadataDialog(BuildContext context, AudioMetadata song) {
  final titleTextController = TextEditingController();
  titleTextController.text = getTitle(song);
  final artistTextController = TextEditingController();
  artistTextController.text = getArtist(song);
  final albumTextController = TextEditingController();
  albumTextController.text = getAlbum(song);

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        child: SizedBox(
          height: 550,
          width: 500,
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                Row(
                  children: [
                    CoverArtWidget(
                      source: getCoverArt(song),
                      size: 200,
                      borderRadius: 10,
                    ),
                    Expanded(
                      child: Column(
                        spacing: 30,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              showCenterMessage(context, 'Not supported yet');
                            },
                            child: Text("Change Cover"),
                          ),

                          ElevatedButton(
                            onPressed: () {
                              showCenterMessage(context, 'Not supported yet');
                            },
                            child: Text("Remove Cover"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Title:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 5),
                TextField(
                  controller: titleTextController,
                  decoration: InputDecoration(border: OutlineInputBorder()),
                  onChanged: (value) {},
                ),

                Spacer(),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Artist:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                SizedBox(height: 5),
                TextField(
                  controller: artistTextController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),

                Spacer(),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Album:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 5),

                TextField(
                  controller: albumTextController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                Spacer(),
                Row(
                  children: [
                    Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Cancel'),
                    ),
                    SizedBox(width: 30),
                    ElevatedButton(
                      onPressed: () async {
                        showCenterMessage(context, 'Not supported yet');
                        // TODO: the plugin has bug when content is Chinese
                        // if (await showConfirmDialog(
                        //   context,
                        //   'Change Metadata Action',
                        // )) {
                        //   updateMetadata(song.file, (metadata) {
                        //     metadata.setTitle('');
                        //   });

                        //   if (context.mounted) {
                        //     Navigator.pop(context);
                        //   }
                        // }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
