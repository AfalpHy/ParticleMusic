import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/services/metadata_service.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/lyric.dart';
import 'package:sylvakru/base/utils/contrast_color_generator.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/custom_text_field.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:permission_handler/permission_handler.dart';

class EditMetadata extends StatefulWidget {
  final MyAudioMetadata song;

  const EditMetadata({super.key, required this.song});

  @override
  State<StatefulWidget> createState() => _EditMetadataState();
}

class _EditMetadataState extends State<EditMetadata> {
  late final MyAudioMetadata song;

  final TextEditingController _titleTextController = TextEditingController();
  final TextEditingController _artistTextController = TextEditingController();
  final TextEditingController _albumTextController = TextEditingController();
  final TextEditingController _albumArtistTextController =
      TextEditingController();
  final TextEditingController _genreTextController = TextEditingController();
  final TextEditingController _yearTextController = TextEditingController();
  final TextEditingController _trackTextController = TextEditingController();
  final TextEditingController _discTextController = TextEditingController();
  final TextEditingController _lyricsTextController = TextEditingController();
  late final ValueNotifier<String?> _picturePathNotifier;

  @override
  void initState() {
    super.initState();
    song = widget.song;
    _titleTextController.text = song.title ?? '';
    _artistTextController.text = song.artist ?? '';
    _albumTextController.text = song.album ?? '';
    _albumArtistTextController.text = song.albumArtist ?? '';
    _genreTextController.text = song.genre ?? '';
    _yearTextController.text = song.year?.toString() ?? '';
    _trackTextController.text = song.track?.toString() ?? '';
    _discTextController.text = song.disc?.toString() ?? '';
    _lyricsTextController.text = song.lyrics ?? '';
    _picturePathNotifier = ValueNotifier(song.picturePath);
  }

  @override
  void dispose() {
    _titleTextController.dispose();
    _artistTextController.dispose();
    _albumTextController.dispose();
    _albumArtistTextController.dispose();
    _genreTextController.dispose();
    _yearTextController.dispose();
    _trackTextController.dispose();
    _discTextController.dispose();
    _lyricsTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortSide = size.shortestSide;

    bool isPhone = shortSide < 600;
    return SizedBox(
      height: max(350, size.height * 0.7),
      width: isPhone ? 300 : 400,
      child: _content(context, isPhone),
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
                          CustomTextField(
                            l10n.year,
                            _yearTextController,
                            onlyNumber: true,
                          ),

                          if (!isPhone) SizedBox(height: 10),

                          CustomTextField(
                            l10n.track,
                            _trackTextController,
                            onlyNumber: true,
                          ),

                          if (!isPhone) SizedBox(height: 10),

                          CustomTextField(
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

                CustomTextField(l10n.title, _titleTextController),

                SizedBox(height: 5),

                CustomTextField(l10n.artist, _artistTextController),

                SizedBox(height: 5),

                CustomTextField(l10n.album, _albumTextController),

                SizedBox(height: 5),

                CustomTextField(l10n.albumArtist, _albumArtistTextController),

                SizedBox(height: 5),

                CustomTextField(l10n.genre, _genreTextController),

                SizedBox(height: 5),

                CustomTextField(
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
        valueListenable: _picturePathNotifier,
        builder: (context, picturePath, child) {
          return Tooltip(
            message: l10n.replacePicture,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  final result = await FilePicker.pickFile(
                    type: FileType.image,
                  );

                  if (result == null) {
                    return;
                  }

                  _picturePathNotifier.value = result.path;
                },
                child: CoverArtWidget(
                  song: song,
                  picturePath: picturePath,
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

  Future<void> _tryWriteMetadata(
    BuildContext context,
    MyAudioMetadata song,
  ) async {
    final l10n = AppLocalizations.of(context);

    if (await showConfirmDialog(context, l10n.updateMedata)) {
      if (Platform.isAndroid) {
        if (await Permission.manageExternalStorage.request() == .denied) {
          if (context.mounted) {
            showCenterMessage(context, l10n.updateFailed);
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

      Uint8List? writePictureBytes;
      if (_picturePathNotifier.value != null) {
        File pictureFile = File(_picturePathNotifier.value!);
        if (await pictureFile.exists()) {
          writePictureBytes = await pictureFile.readAsBytes();
        }
      }

      late bool success;
      try {
        success = writeMetadata(
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
          headers: song.sourceType == .webdav ? webdavClient?.headers : null,
        );
      } catch (e) {
        logger.output(e.toString());
        success = false;
      }

      if (success) {
        song.modified = DateTime.now();
        if (song.cacheExist) {
          File(song.cachePath!).deleteSync();
          song.cacheExist = false;
        }
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

        await library.updateMetadata(song);

        song.pictureLoaded = false;
        song.pictureExist = false;
        song.coverArtColor = null;
        song.lowerLuminance = null;
        // clear cache
        final imageCache = PaintingBinding.instance.imageCache;
        imageCache.clear();
        imageCache.clearLiveImages();

        await computeCoverArtColor(song);
        if (song == currentSongNotifier.value) {
          currentCoverArtColor = song.coverArtColor!;
          contrastColorTheme = ContrastColorGenerator.generate(
            currentCoverArtColor,
          );
          colorManager.updateLyricsPageColors();
        }
        final originArtist = getArtist(song);
        final originAlbum = getAlbum(song);
        artistAlbumManager.updateArtistAlbum(song, originArtist, originAlbum);

        song.updateNotifier.value++;

        layersManager.updateBackground();
      }
      if (context.mounted) {
        showCenterMessage(
          context,
          success ? l10n.updateSuccessfully : l10n.updateFailed,
        );
        Navigator.pop(context);
      }
    }
  }
}
