import 'dart:io';
import 'dart:typed_data';

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

  final ValueNotifier<Uint8List?> coverArtNotifier = ValueNotifier(
    getPictureBytes(song),
  );
  final l10n = AppLocalizations.of(context);

  await showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: commonColor,
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
                              coverArtNotifier.value != getPictureBytes(song)) {
                            song.title = titleTextController.text == ''
                                ? null
                                : titleTextController.text;
                            song.artist = artistTextController.text == ''
                                ? null
                                : artistTextController.text;
                            song.album = albumTextController.text == ''
                                ? null
                                : albumTextController.text;

                            song.pictureBytes = coverArtNotifier.value;

                            try {
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

                            song.updateNotifier.value++;
                            if (!isMobile) {
                              panelManager.updateBackground();
                            }
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

                                  coverArtNotifier.value = bytes;
                                },
                                child: CoverArtWidget(
                                  song: song,
                                  pictureBytes: coverArt,
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
