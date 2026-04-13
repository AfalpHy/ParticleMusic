import 'dart:math';

import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';

void showSongInfoDialog(BuildContext context, MyAudioMetadata song) async {
  await showAnimationDialog(
    context: context,
    child: _SongInfo(song: song),
  );
}

class _SongInfo extends StatelessWidget {
  final MyAudioMetadata song;

  const _SongInfo({required this.song});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final size = MediaQuery.of(context).size;
        final shortSide = size.shortestSide;

        bool isPhone = shortSide < 600;
        return SizedBox(
          height: max(350, size.height * 0.7),
          width: isPhone ? 320 : 400,
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
            l10n.songInfo,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          SizedBox(height: 5),

          Divider(thickness: 0.5, height: 1, color: dividerColor),
          SizedBox(height: 5),
          Expanded(
            child: ListView(
              padding: .symmetric(horizontal: isMobile ? 5 : 15),
              children: [
                SizedBox(height: 5),

                Row(
                  children: [
                    CoverArtWidget(size: 180, borderRadius: 10, song: song),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: isPhone ? .start : .center,
                        children: [
                          Text('${l10n.format}:'),
                          Text('Unknown'),

                          SizedBox(height: 10),
                          Divider(
                            thickness: 0.5,
                            height: 1,
                            color: dividerColor,
                          ),
                          SizedBox(height: 10),

                          Text('${l10n.bitrate}:'),
                          Text('${song.bitrate?.toString() ?? ''} Kbps'),

                          SizedBox(height: 10),
                          Divider(
                            thickness: 0.5,
                            height: 1,
                            color: dividerColor,
                          ),
                          SizedBox(height: 10),

                          Text('${l10n.samplerate}:'),
                          if (song.samplerate == null)
                            Text('')
                          else
                            Text(
                              '${(song.samplerate! / 1000.0).toString()} KHz',
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 15),
                Divider(thickness: 0.5, height: 1, color: dividerColor),
                SizedBox(height: 10),

                Text('${l10n.title}: ${getTitle(song)}'),

                SizedBox(height: 10),
                Divider(thickness: 0.5, height: 1, color: dividerColor),
                SizedBox(height: 10),

                Text('${l10n.artist}: ${getArtist(song)}'),

                SizedBox(height: 10),
                Divider(thickness: 0.5, height: 1, color: dividerColor),
                SizedBox(height: 10),

                Text('${l10n.album}: ${getAlbum(song)}'),

                SizedBox(height: 10),
                Divider(thickness: 0.5, height: 1, color: dividerColor),
                SizedBox(height: 10),

                Text('${l10n.genre}: ${getGenre(song)}'),

                SizedBox(height: 10),
                Divider(thickness: 0.5, height: 1, color: dividerColor),
                SizedBox(height: 10),

                Text('${l10n.year}: ${song.year?.toString() ?? ''}'),

                SizedBox(height: 10),
                Divider(thickness: 0.5, height: 1, color: dividerColor),
                SizedBox(height: 10),

                Text('${l10n.track}: ${song.track?.toString() ?? ''}'),

                SizedBox(height: 10),
                Divider(thickness: 0.5, height: 1, color: dividerColor),
                SizedBox(height: 10),

                Text('${l10n.disc}: ${song.disc?.toString() ?? ''}'),

                SizedBox(height: 10),
                Divider(thickness: 0.5, height: 1, color: dividerColor),
                SizedBox(height: 10),

                Text('${l10n.duration}: ${song.duration?.toString() ?? ''}'),

                SizedBox(height: 10),
                Divider(thickness: 0.5, height: 1, color: dividerColor),
                SizedBox(height: 10),

                Text('File Path: '),

                Text(song.filePath ?? ''),

                SizedBox(height: 10),
                Divider(thickness: 0.5, height: 1, color: dividerColor),
                SizedBox(height: 10),

                Text('${l10n.lyrics}:'),

                Text(song.lyrics ?? ''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
