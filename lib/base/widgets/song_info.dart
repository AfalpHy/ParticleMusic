import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gamepads/flutter_gamepads.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';

class SongInfo extends StatefulWidget {
  final MyAudioMetadata song;

  const SongInfo({super.key, required this.song});

  @override
  State<StatefulWidget> createState() => _SongInfoState();
}

class _SongInfoState extends State<SongInfo> {
  late final MyAudioMetadata song;
  final _scrollController = ScrollController();

  static const double _step = 80;

  void _scroll(AxisDirection direction) {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;

    final target = switch (direction) {
      AxisDirection.up => (position.pixels - _step).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),

      AxisDirection.down => (position.pixels + _step).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),

      _ => position.pixels,
    };

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();
    song = widget.song;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortSide = size.shortestSide;

    bool isPhone = shortSide < 600;
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (context, value, child) {
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
    final double verticalPadding = isPhone ? 5 : 10;
    final textColor = colorManager.getSpecificTextColor();
    final textStyle = TextStyle(color: textColor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        children: [
          Text(
            l10n.songInfo,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: textColor,
            ),
          ),

          paddingDivider(verticalPadding),

          Expanded(
            child: GamepadInterceptor(
              onBeforeIntent: (activator, intent) {
                if (intent is ScrollIntent) {
                  _scroll(intent.direction);
                  return false;
                }
                return true;
              },
              child: KeyboardListener(
                focusNode: FocusNode(),
                autofocus: true,
                onKeyEvent: (event) {
                  if (event is! KeyRepeatEvent && event is! KeyDownEvent) {
                    return;
                  }

                  switch (event.logicalKey) {
                    case .arrowUp:
                      _scroll(AxisDirection.up);
                      break;

                    case .arrowDown:
                      _scroll(AxisDirection.down);
                      break;
                  }
                },
                child: ListView(
                  controller: _scrollController,
                  padding: .symmetric(horizontal: isMobile ? 5 : 15),
                  children: [
                    SizedBox(height: 10),

                    Row(
                      children: [
                        CoverArtWidget(
                          size: isPhone ? 150 : 180,
                          borderRadius: 10,
                          picture: song.picture,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: isPhone ? .start : .center,
                            children: [
                              Text('${l10n.format}:', style: textStyle),
                              Text(
                                song.format?.toUpperCase() ?? "Unknown",
                                style: textStyle,
                              ),

                              paddingDivider(verticalPadding),

                              Text('${l10n.bitrate}:', style: textStyle),
                              Text(
                                '${song.bitrate?.toString() ?? ''} Kbps',
                                style: textStyle,
                              ),

                              paddingDivider(verticalPadding),

                              Text('${l10n.samplerate}:', style: textStyle),
                              if (song.samplerate == null)
                                Text('')
                              else
                                Text(
                                  '${(song.samplerate! / 1000.0).toString()} KHz',
                                  style: textStyle,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 10),
                    paddingDivider(verticalPadding),

                    Text('${l10n.title}: ${getTitle(song)}', style: textStyle),

                    paddingDivider(verticalPadding),

                    Text(
                      '${l10n.artist}: ${getArtist(song)}',
                      style: textStyle,
                    ),

                    paddingDivider(verticalPadding),

                    Text('${l10n.album}: ${getAlbum(song)}', style: textStyle),

                    paddingDivider(verticalPadding),

                    Text(
                      '${l10n.albumArtist}: ${getAlbumArtist(song)}',
                      style: textStyle,
                    ),

                    paddingDivider(verticalPadding),

                    Text('${l10n.genre}: ${getGenre(song)}', style: textStyle),

                    paddingDivider(verticalPadding),

                    Text(
                      '${l10n.year}: ${song.year?.toString() ?? ''}',
                      style: textStyle,
                    ),

                    paddingDivider(verticalPadding),

                    Text(
                      '${l10n.track}: ${song.track?.toString() ?? ''}',
                      style: textStyle,
                    ),

                    paddingDivider(verticalPadding),

                    Text(
                      '${l10n.disc}: ${song.disc?.toString() ?? ''}',
                      style: textStyle,
                    ),

                    paddingDivider(verticalPadding),

                    Text(
                      '${l10n.duration}: ${song.duration?.toString() ?? ''}',
                      style: textStyle,
                    ),

                    paddingDivider(verticalPadding),

                    Text('${l10n.path}:', style: textStyle),

                    Text(song.path ?? '', style: textStyle),

                    paddingDivider(verticalPadding),

                    Text('${l10n.lyrics}:', style: textStyle),

                    Text(song.lyrics ?? '', style: textStyle),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget paddingDivider(double verticalPadding) {
    return Padding(
      padding: .symmetric(vertical: verticalPadding),
      child: Divider(
        thickness: 0.5,
        height: 1,
        color: colorManager.getSpecificDividerColor(),
      ),
    );
  }
}
