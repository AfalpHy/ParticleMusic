import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
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

  final ValueNotifier<Picture?> coverArtNotifier = ValueNotifier(
    getCoverArt(song),
  );
  final l10n = AppLocalizations.of(context);

  await showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: panelColor,
        shape: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        child: SizedBox(
          height: 280,
          width: 600,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 10, 30, 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      l10n.editMetadata,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    Spacer(),

                    IconButton(
                      icon: Icon(Icons.check_rounded),

                      onPressed: () async {
                        if (song == currentSongNotifier.value) {
                          showCenterMessage(
                            context,
                            l10n.canNotUpdate,
                            duration: 2000,
                          );
                          return;
                        }
                        if (await showConfirmDialog(
                          context,
                          l10n.updateMedata,
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
                                  l10n.updateSuccessfully,
                                  duration: 2000,
                                );
                              }
                            } catch (_) {
                              if (context.mounted) {
                                showCenterMessage(
                                  context,
                                  l10n.updateFailed,
                                  duration: 2000,
                                );
                              }
                            }

                            songIsUpdated[song]!.value++;
                          } else {
                            if (context.mounted) {
                              showCenterMessage(
                                context,
                                l10n.nothingNeedToUpdate,
                                duration: 2000,
                              );
                            }
                          }

                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        }
                      },
                    ),
                  ],
                ),

                Divider(thickness: 0.3, height: 1, color: Colors.black),
                SizedBox(height: 5),
                Expanded(
                  child: Row(
                    children: [
                      ValueListenableBuilder(
                        valueListenable: coverArtNotifier,
                        builder: (context, coverArt, child) {
                          return Tooltip(
                            message: l10n.replacePicture,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () async {
                                  final result = await FilePicker.platform
                                      .pickFiles(
                                        type: FileType.image,
                                        allowMultiple: false,
                                      );
                                  if (result == null || result.files.isEmpty) {
                                    return;
                                  }

                                  final file = result.files.first;

                                  final Uint8List bytes =
                                      file.bytes ??
                                      await File(file.path!).readAsBytes();

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
                                child: CoverArtWidget(
                                  source: coverArt,
                                  size: 180,
                                  borderRadius: 10,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 30),
                      Expanded(
                        child: Column(
                          children: [
                            Spacer(),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "${l10n.title}:",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextField(
                              style: TextStyle(fontSize: 12),
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
                                "${l10n.artist}:",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            TextField(
                              style: TextStyle(fontSize: 12),
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
                                "${l10n.album}:",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            TextField(
                              style: TextStyle(fontSize: 12),
                              controller: albumTextController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            Spacer(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
