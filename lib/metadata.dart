import 'dart:io';
import 'dart:typed_data';

import 'package:audio_tags_lofty/audio_tags.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

void showSongMetadataDialog(BuildContext context, MyAudioMetadata song) async {
  final originalTitle = song.title ?? '';
  final originalArtist = song.artist ?? '';
  final originalAlbum = song.album ?? '';

  final titleTextController = TextEditingController();
  titleTextController.text = originalTitle;
  final artistTextController = TextEditingController();
  artistTextController.text = originalArtist;
  final albumTextController = TextEditingController();
  albumTextController.text = originalAlbum;

  final ValueNotifier<Uint8List?> pictureBytesNotifier = ValueNotifier(
    getPictureBytes(song),
  );
  final l10n = AppLocalizations.of(context);

  await showDialog(
    context: context,
    builder: (context) {
      return Dialog(
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
                        if (await showConfirmDialog(
                          context,
                          l10n.updateMedata,
                        )) {
                          String? writeTitle;
                          String? writeArtist;
                          String? writeAlbum;
                          Uint8List? writePictureBytes;

                          if (titleTextController.text != originalTitle) {
                            writeTitle = titleTextController.text;
                          }
                          if (artistTextController.text != originalArtist) {
                            writeArtist = artistTextController.text;
                          }
                          if (albumTextController.text != originalArtist) {
                            writeAlbum = albumTextController.text;
                          }
                          if (pictureBytesNotifier.value !=
                              getPictureBytes(song)) {
                            writePictureBytes = pictureBytesNotifier.value;
                          }

                          bool success = writeMetadata(
                            path: song.filePath,
                            title: writeTitle,
                            artist: writeArtist,
                            album: writeAlbum,
                            lyrics: null,
                            pictureBytes: writePictureBytes,
                          );
                          if (success) {
                            song.title = titleTextController.text.isNotEmpty
                                ? titleTextController.text
                                : null;
                            song.artist = artistTextController.text.isNotEmpty
                                ? artistTextController.text
                                : null;

                            song.album = albumTextController.text.isNotEmpty
                                ? albumTextController.text
                                : null;
                            song.pictureBytes = pictureBytesNotifier.value;
                            song.coverArtColor = null;

                            song.updateNotifier.value++;
                            if (!isMobile) {
                              panelManager.updateBackground();
                            }
                          }
                          if (context.mounted) {
                            showCenterMessage(
                              context,
                              success
                                  ? l10n.updateSuccessfully
                                  : l10n.updateFailed,
                              duration: 2000,
                            );
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
                        valueListenable: pictureBytesNotifier,
                        builder: (context, pictureBytes, child) {
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

                                  pictureBytesNotifier.value = bytes;
                                },
                                child: CoverArtWidget(
                                  song: song,
                                  pictureBytes: pictureBytes,
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
