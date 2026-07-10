import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/song_list_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/utils/source_type.dart';
import 'package:sylvakru/base/widgets/song_list.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/layer/layers_manager.dart';

class SwitchableSongList extends StatelessWidget {
  final Playlist? playlist;
  final Artist? artist;
  final Album? album;
  final bool isRanking;
  final bool isRecently;
  final bool isRoot;

  final SongListManager songListManager;

  const SwitchableSongList({
    super.key,
    this.playlist,
    this.artist,
    this.album,
    this.isRanking = false,
    this.isRecently = false,
    this.isRoot = true,
    required this.songListManager,
  });

  void switchCallBack(BuildContext context) {
    if (songListManager.notEmptyCount == 2) {
      for (final sourceType in SourceType.values) {
        if (sourceType != songListManager.sourceTypeNotifier.value &&
            songListManager.getSongList2(sourceType).isNotEmpty) {
          songListManager.sourceTypeNotifier.value = sourceType;
          layersManager.updateBackground();
          break;
        }
      }
      return;
    }
    showAnimationDialog(
      context: context,
      child: SizedBox(
        width: 300,
        height: isMobile ? 280 : 260,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Builder(
            builder: (context) {
              return ListView(
                children: [
                  for (final sourceType in SourceType.values)
                    if (songListManager.getSongList2(sourceType).isNotEmpty)
                      ListTile(
                        leading: Image(
                          image: getSourceTypeImage(sourceType),
                          height: 30,
                          width: 30,
                        ),
                        title: Text(
                          getSourceTypeName(
                            AppLocalizations.of(context),
                            sourceType,
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await Future.delayed(Duration(milliseconds: 250));
                          songListManager.sourceTypeNotifier.value = sourceType;
                          layersManager.updateBackground();
                        },
                        trailing:
                            songListManager.sourceTypeNotifier.value ==
                                sourceType
                            ? Icon(Icons.check)
                            : null,
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: songListManager.sourceTypeNotifier,
      builder: (context, sourceType, child) {
        return Stack(
          children: [
            ...(() {
              List<Widget> widgets = [];
              for (int i = 0; i < SourceType.values.length; i++) {
                final tmpSourcetype = SourceType.values[i];
                final songListIsNotEmpty = songListManager
                    .getSongList2(tmpSourcetype)
                    .isNotEmpty;

                if (songListIsNotEmpty || (i == 0 && sourceType == .local)) {
                  widgets.add(
                    Visibility(
                      key: ValueKey(tmpSourcetype.name),
                      visible: sourceType == tmpSourcetype,
                      maintainState: true,
                      child: SongList(
                        playlist: playlist,
                        artist: artist,
                        album: album,
                        isRanking: isRanking,
                        isRecently: isRecently,
                        isRoot: isRoot,
                        sourceType: tmpSourcetype,
                        switchCallBack: switchCallBack,
                      ),
                    ),
                  );
                  continue;
                }
              }

              return widgets;
            })(),
          ],
        );
      },
    );
  }
}
