import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common_widgets/lyrics.dart';
import 'package:particle_music/common_widgets/my_divider.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';
import 'package:permission_handler/permission_handler.dart';

TextEditingController _titleTextController = TextEditingController();
TextEditingController _artistTextController = TextEditingController();
TextEditingController _albumTextController = TextEditingController();
TextEditingController _albumArtistTextController = TextEditingController();
TextEditingController _genreTextController = TextEditingController();
TextEditingController _yearTextController = TextEditingController();
TextEditingController _trackTextController = TextEditingController();
TextEditingController _discTextController = TextEditingController();
TextEditingController _lyricsTextController = TextEditingController();

late ValueNotifier<Uint8List?> _pictureBytesNotifier;

void showEditMetadataDialog(BuildContext context, MyAudioMetadata song) async {
  _titleTextController.text = song.title ?? '';
  _artistTextController.text = song.artist ?? '';
  _albumTextController.text = song.album ?? '';
  _albumArtistTextController.text = song.albumArtist ?? '';
  _genreTextController.text = song.genre ?? '';
  _yearTextController.text = song.year?.toString() ?? '';
  _trackTextController.text = song.track?.toString() ?? '';
  _discTextController.text = song.disc?.toString() ?? '';
  _lyricsTextController.text = song.lyrics ?? '';

  _pictureBytesNotifier = ValueNotifier(getPictureBytes(song));

  await showAnimationDialog(
    context: context,
    child: _MetadataDialog(song: song),
  );
}

Future<void> _tryWriteMetadata(
  BuildContext context,
  MyAudioMetadata song,
) async {
  final l10n = AppLocalizations.of(context);

  if (await showConfirmDialog(context, l10n.updateMedata)) {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request() == .denied) {
        if (context.mounted) {
          showCenterMessage(context, l10n.updateFailed, duration: 2000);
        }
        return;
      }
    }
    String writeTitle = _titleTextController.text;
    String writeArtist = _artistTextController.text;
    String writeAlbum = _albumTextController.text;
    String writeAlbumArtist = _albumArtistTextController.text;
    String writeGenre = _genreTextController.text;
    String writeLyrics = _lyricsTextController.text;
    int? writeYear = int.tryParse(_yearTextController.text);
    int? writeTrack = int.tryParse(_trackTextController.text);
    int? writeDisc = int.tryParse(_discTextController.text);

    Uint8List? writePictureBytes = _pictureBytesNotifier.value;

    bool success = writeMetadata(
      path: song.path!,
      title: writeTitle,
      artist: writeArtist,
      album: writeAlbum,
      albumArtist: writeAlbumArtist,
      genre: writeGenre,
      year: writeYear,
      track: writeTrack,
      disc: writeDisc,
      lyrics: writeLyrics,
      pictureBytes: writePictureBytes,
      username: song.isWebdav ? webdavUsername : null,
      password: song.isWebdav ? webdavPassword : null,
    );
    if (success) {
      song.modified = DateTime.now();
      song.webdavCachePath = null;

      final originArtist = getArtist(song);
      final originAlbum = getAlbum(song);

      song.title = writeTitle;
      song.artist = writeArtist;
      song.album = writeAlbum;
      song.albumArtist = writeAlbumArtist;
      song.genre = writeGenre;
      song.lyrics = writeLyrics;
      song.parsedLyrics = null;
      await setParsedLyrics(song);
      // do not modify when writeValue is null
      song.year = writeYear ?? song.year;
      song.track = writeTrack ?? song.track;
      song.disc = writeDisc ?? song.disc;

      song.pictureBytes = _pictureBytesNotifier.value;
      song.coverArtColor = null;
      song.lowerLuminance = null;
      await computeCoverArtColor(song);
      if (song == currentSongNotifier.value) {
        currentCoverArtColor = song.coverArtColor!;
        colorManager.updateLyricsPageColors();
      }
      artistsAlbumsManager.updateArtistAlbum(song, originArtist, originAlbum);

      song.updateNotifier.value++;
      await library.update();
      for (final folder in library.folderList) {
        if (folder.id2Song[song.id] != null) {
          await folder.update();
        }
      }
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

class _MetadataDialog extends StatelessWidget {
  final MyAudioMetadata song;

  const _MetadataDialog({required this.song});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final size = MediaQuery.of(context).size;
        final shortSide = size.shortestSide;

        bool isPhone = shortSide < 600;
        return SizedBox(
          height: max(350, size.height * 0.7),
          width: isPhone ? 300 : 400,
          child: _content(context, isPhone),
        );
      },
    );
  }

  Widget _content(BuildContext context, bool isPhone) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        children: [
          Text(
            l10n.editMetadata,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          SizedBox(height: 5),

          MyDivider(thickness: 0.5, height: 1, color: dividerColor),
          SizedBox(height: 5),
          Expanded(
            child: ListView(
              padding: .symmetric(horizontal: isMobile ? 10 : 15),
              children: [
                SizedBox(height: 10),

                Row(
                  children: [
                    _coverArt(context, song, isPhone),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        children: [
                          adaptiveTextField(
                            context,
                            l10n.year,
                            _yearTextController,
                            onlyNumber: true,
                          ),

                          if (!isPhone) SizedBox(height: 10),

                          adaptiveTextField(
                            context,
                            l10n.track,
                            _trackTextController,
                            onlyNumber: true,
                          ),

                          if (!isPhone) SizedBox(height: 10),

                          adaptiveTextField(
                            context,
                            l10n.disc,
                            _discTextController,
                            onlyNumber: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),

                adaptiveTextField(context, l10n.title, _titleTextController),

                SizedBox(height: 5),

                adaptiveTextField(context, l10n.artist, _artistTextController),

                SizedBox(height: 5),

                adaptiveTextField(context, l10n.album, _albumTextController),

                SizedBox(height: 5),

                adaptiveTextField(
                  context,
                  l10n.albumArtist,
                  _albumArtistTextController,
                ),

                SizedBox(height: 5),

                adaptiveTextField(context, l10n.genre, _genreTextController),

                SizedBox(height: 5),

                adaptiveTextField(
                  context,
                  l10n.lyrics,
                  _lyricsTextController,
                  expand: true,
                ),
                SizedBox(height: 15),

                ValueListenableBuilder(
                  valueListenable: buttonColor.valueNotifier,
                  builder: (context, value, child) {
                    return Row(
                      children: [
                        Spacer(),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: value,
                          ),
                          child: Text(l10n.cancel),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: () {
                            _tryWriteMetadata(context, song);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: value,
                            foregroundColor: Colors.red,
                          ),
                          child: Text(l10n.confirm),
                        ),
                        Spacer(),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverArt(BuildContext context, MyAudioMetadata song, bool isPhone) {
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
                  final result = await FilePicker.pickFiles(
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
                  size: isPhone ? 150 : 180,
                  borderRadius: 10,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
