import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
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
  final buttonStyle = ElevatedButton.styleFrom(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    padding: EdgeInsets.all(10),
  );

  final ValueNotifier<Picture?> coverArtNotifier = ValueNotifier(
    getCoverArt(song),
  );

  await showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        child: SizedBox(
          height: 600,
          width: 400,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 20),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Edit Metadata',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                SizedBox(height: 5),
                Divider(thickness: 0.5, height: 1, color: Colors.grey),
                SizedBox(height: 10),

                ValueListenableBuilder(
                  valueListenable: coverArtNotifier,
                  builder: (context, coverArt, child) {
                    return CoverArtWidget(
                      source: coverArt,
                      size: 200,
                      borderRadius: 10,
                    );
                  },
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Spacer(),
                    ElevatedButton(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          allowMultiple: false,
                        );
                        if (result == null || result.files.isEmpty) return;

                        final file = result.files.first;

                        final Uint8List bytes =
                            file.bytes ?? await File(file.path!).readAsBytes();

                        // mimeType is not that important, use image/jpeg as default
                        String mimeType = 'image/jpeg';
                        if (file.extension != null) {
                          final ext = file.extension!.toLowerCase();
                          if (ext == 'png') {
                            mimeType = 'image/png';
                          } else if (ext == 'gif') {
                            mimeType = 'image/gif';
                          } else if (ext == 'bmp') {
                            mimeType = 'image/bmp';
                          } else if (ext == 'webp') {
                            mimeType = 'image/webp';
                          }
                        }

                        coverArtNotifier.value = Picture(
                          bytes,
                          mimeType,
                          PictureType.coverFront,
                        );
                      },
                      style: buttonStyle,
                      child: Text("Change"),
                    ),
                    SizedBox(width: 20),
                    ElevatedButton(
                      onPressed: () {
                        coverArtNotifier.value = null;
                      },
                      style: buttonStyle,

                      child: Text("Remove"),
                    ),
                    Spacer(),
                  ],
                ),

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
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
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
                    isDense: true,
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
                    isDense: true,
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
                      style: buttonStyle,

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
                              albumTextController.text != originalAlbum ||
                              coverArtNotifier.value != getCoverArt(song)) {
                            song.title = titleTextController.text == ''
                                ? null
                                : titleTextController.text;
                            song.artist = artistTextController.text == ''
                                ? null
                                : artistTextController.text;
                            song.album = albumTextController.text == ''
                                ? null
                                : albumTextController.text;

                            song.pictures = coverArtNotifier.value == null
                                ? []
                                : [coverArtNotifier.value!];

                            try {
                              updateMetadata(song.file, (metadata) {
                                metadata.setTitle(song.title);
                                metadata.setArtist(song.artist);
                                metadata.setAlbum(song.album);
                                metadata.setPictures(song.pictures);
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
                      style: buttonStyle,

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
}
