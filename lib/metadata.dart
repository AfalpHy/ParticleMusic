import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/desktop/keyboard.dart';
import 'package:smooth_corner/smooth_corner.dart';

Map<AudioMetadata, ValueNotifier<int>> songIsUpdated = {};

void showSongMetadataDialog(BuildContext context, AudioMetadata song) async {
  final originalTitle = song.title ?? '';
  final originalArtist = song.artist ?? '';
  final originalAlbum = song.album ?? '';

  final titleTextController = TextEditingController();
  titleTextController.text = originalTitle;
  final artistTextController = TextEditingController();
  artistTextController.text = originalArtist;
  final albumTextController = TextEditingController();
  albumTextController.text = originalAlbum;

  await showDialog(
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
                              showCenterMessage(
                                context,
                                'Not supported yet',
                                duration: 2000,
                              );
                            },
                            child: Text("Change Cover"),
                          ),

                          ElevatedButton(
                            onPressed: () {
                              showCenterMessage(
                                context,
                                'Not supported yet',
                                duration: 2000,
                              );
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
                        if (song == currentSongNotifier.value) {
                          showCenterMessage(
                            context,
                            'Can not modify the song that is playing',
                            duration: 2000,
                          );
                          return;
                        }
                        if (await showConfirmDialog(
                          context,
                          'Update Metadata Action',
                        )) {
                          if (titleTextController.text != originalTitle ||
                              artistTextController.text != originalArtist ||
                              albumTextController.text != originalAlbum) {
                            song.title = titleTextController.text == ''
                                ? null
                                : titleTextController.text;
                            song.artist = artistTextController.text == ''
                                ? null
                                : artistTextController.text;
                            song.album = albumTextController.text == ''
                                ? null
                                : albumTextController.text;

                            try {
                              updateMetadata(song.file, (metadata) {
                                metadata.setTitle(song.title);
                                metadata.setArtist(song.artist);
                                metadata.setAlbum(song.album);
                              });
                              if (context.mounted) {
                                showCenterMessage(
                                  context,
                                  'Update successfully',
                                  duration: 2000,
                                );
                              }
                            } catch (_) {
                              if (context.mounted) {
                                showCenterMessage(
                                  context,
                                  'Update failed',
                                  duration: 2000,
                                );
                              }
                            }

                            songIsUpdated[song]!.value++;
                          } else {
                            if (context.mounted) {
                              showCenterMessage(
                                context,
                                'Nothing need to update',
                                duration: 2000,
                              );
                            }
                          }

                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        }
                      },
                      child: const Text('Update'),
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

  appFocusNode.requestFocus();
}
