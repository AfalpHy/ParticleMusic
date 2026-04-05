import 'dart:io';
import 'dart:typed_data';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';

TextEditingController _titleTextController = TextEditingController();
TextEditingController _artistTextController = TextEditingController();
TextEditingController _albumTextController = TextEditingController();
TextEditingController _genreTextController = TextEditingController();
TextEditingController _yearTextController = TextEditingController();
TextEditingController _trackTextController = TextEditingController();
TextEditingController _discTextController = TextEditingController();
TextEditingController _lyricsTextController = TextEditingController();

late ValueNotifier<Uint8List?> _pictureBytesNotifier;

void showSongMetadataDialog(BuildContext context, MyAudioMetadata song) async {
  _titleTextController.text = song.title ?? '';
  _artistTextController.text = song.artist ?? '';
  _albumTextController.text = song.album ?? '';
  _genreTextController.text = song.genre ?? '';
  _yearTextController.text = song.year?.toString() ?? '';
  _trackTextController.text = song.track?.toString() ?? '';
  _discTextController.text = song.disc?.toString() ?? '';
  _lyricsTextController.text = song.lyrics ?? '';

  _pictureBytesNotifier = ValueNotifier(getPictureBytes(song));

  final l10n = AppLocalizations.of(context);

  await showAnimationDialog(
    context: context,
    height: isMobile ? 380 : 500,
    width: isMobile ? 300 : 400,
    pageBuilder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          children: [
            Text(
              l10n.editMetadata,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [Spacer()]),
            SizedBox(height: 5),

            Divider(thickness: 0.5, height: 1, color: dividerColor),
            SizedBox(height: 5),
            Expanded(
              child: ListView(
                children: [
                  SizedBox(height: 5),

                  _coverArt(context, song),
                  SizedBox(height: 5),

                  _metadataTextField(context, l10n.title, _titleTextController),

                  SizedBox(height: 5),

                  _metadataTextField(
                    context,
                    l10n.artist,
                    _artistTextController,
                  ),

                  SizedBox(height: 5),

                  _metadataTextField(context, l10n.album, _albumTextController),

                  SizedBox(height: 5),

                  _metadataTextField(context, l10n.genre, _genreTextController),

                  SizedBox(height: 5),

                  _metadataTextField(
                    context,
                    l10n.year,
                    _yearTextController,
                    onlyNumber: true,
                  ),

                  SizedBox(height: 5),

                  _metadataTextField(
                    context,
                    l10n.track,
                    _trackTextController,
                    onlyNumber: true,
                  ),

                  SizedBox(height: 5),

                  _metadataTextField(
                    context,
                    l10n.disc,
                    _discTextController,
                    onlyNumber: true,
                  ),

                  SizedBox(height: 5),

                  _metadataTextField(
                    context,
                    l10n.lyrics,
                    _lyricsTextController,
                    expand: true,
                  ),
                  SizedBox(height: 15),

                  Row(
                    children: [
                      Spacer(),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l10n.cancel),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton(
                        onPressed: () {
                          _tryWriteMetadata(context, song);
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: Text(l10n.confirm),
                      ),
                      Spacer(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _coverArt(BuildContext context, MyAudioMetadata song) {
  final l10n = AppLocalizations.of(context);

  return Center(
    child: ValueListenableBuilder(
      valueListenable: _pictureBytesNotifier,
      builder: (context, pictureBytes, child) {
        return Tooltip(
          message: l10n.replacePicture,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  allowMultiple: false,
                );
                if (result == null || result.files.isEmpty) {
                  return;
                }

                final file = result.files.first;

                final Uint8List bytes =
                    file.bytes ?? await File(file.path!).readAsBytes();

                _pictureBytesNotifier.value = bytes;
              },
              child: CoverArtWidget(
                song: song,
                pictureBytes: pictureBytes,
                size: isMobile ? 150 : 180,
                borderRadius: 10,
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _metadataTextField(
  BuildContext context,
  String type,
  TextEditingController controller, {
  bool expand = false,
  bool onlyNumber = false,
}) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 20),
    child: Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text('$type:', style: TextStyle(fontWeight: FontWeight.bold)),
        ),

        SizedBox(
          height: expand ? 180 : null,
          child: TextField(
            keyboardType: onlyNumber ? .number : null,
            readOnly: isMobile,
            expands: expand,
            maxLines: expand ? null : 1,
            style: TextStyle(fontSize: 12),
            controller: controller,
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: textColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: textColor, width: 1.5),
              ),
              isDense: true,
            ),
            onTap: () {
              if (isMobile) {
                showTextFieldSheet(
                  context,
                  controller,
                  expand: expand,
                  onlyNumber: onlyNumber,
                );
              }
            },
          ),
        ),
      ],
    ),
  );
}

Future<void> _tryWriteMetadata(
  BuildContext context,
  MyAudioMetadata song,
) async {
  final l10n = AppLocalizations.of(context);

  if (await showConfirmDialog(context, l10n.updateMedata)) {
    String writeTitle = _titleTextController.text;
    String writeArtist = _artistTextController.text;
    String writeAlbum = _albumTextController.text;
    String writeGenre = _genreTextController.text;
    String writeLyrics = _lyricsTextController.text;
    int? writeYear = int.tryParse(_yearTextController.text);
    int? writeTrack = int.tryParse(_trackTextController.text);
    int? writeDisc = int.tryParse(_discTextController.text);

    Uint8List? writePictureBytes = _pictureBytesNotifier.value;

    bool success = writeMetadata(
      path: song.filePath!,
      title: writeTitle,
      artist: writeArtist,
      album: writeAlbum,
      genre: writeGenre,
      year: writeYear,
      track: writeTrack,
      disc: writeDisc,
      lyrics: writeLyrics,
      pictureBytes: writePictureBytes,
    );
    if (success) {
      song.title = writeTitle;
      song.artist = writeArtist;
      song.album = writeAlbum;
      song.genre = writeGenre;
      song.lyrics = writeLyrics;
      song.parsedLyrics = null;
      song.year = writeYear;
      song.track = writeTrack;
      song.disc = writeDisc;

      song.pictureBytes = _pictureBytesNotifier.value;
      song.coverArtColor = null;

      song.updateNotifier.value++;
      layersManager.updateBackground();
    }
    if (context.mounted) {
      showCenterMessage(
        context,
        success ? l10n.updateSuccessfully : l10n.updateFailed,
        duration: 2000,
      );
      Navigator.pop(context);
    }
  }
}
