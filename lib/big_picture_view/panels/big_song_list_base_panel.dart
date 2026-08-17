import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/data/song_list_manager.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/utils/format_duration.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';

abstract class BigSongListBasePanel extends StatefulWidget {
  const BigSongListBasePanel({super.key});
}

abstract class BigSongListBasePanelState extends State<BigSongListBasePanel> {
  late final SongListManager songListManager;
  final bool isRanking = false;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: songListManager.changeNotifier,
      builder: (context, value, child) {
        final currentSongList = songListManager.getSongList();
        final itemExtent = isTooNarrow(context) ? 60.0 : 80.0;
        return ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: isTooNarrow(context) ? 0 : 40,
            vertical: 75 + getTopOffset(context),
          ),
          controller: _scrollController,
          itemExtent: itemExtent,
          itemCount: currentSongList.length,
          itemBuilder: (context, index) {
            final song = currentSongList[index];
            return Builder(
              builder: (itemContext) {
                return Material(
                  color: Colors.transparent,
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: .circular(15),
                  ),
                  clipBehavior: .antiAlias,
                  child: InkWell(
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () {
                      showSongOptions(
                        context: itemContext,
                        song: song,
                        includeGoToArtist: true,
                        includeGoToAlbum: true,
                      );
                    },
                    onFocusChange: (value) {
                      if (value) {
                        final box = itemContext.findRenderObject() as RenderBox;
                        final viewport = RenderAbstractViewport.of(box);

                        final target =
                            viewport.getOffsetToReveal(box, 0.5).offset +
                            itemExtent / 2;

                        _scrollController.animateTo(
                          target.clamp(
                            _scrollController.position.minScrollExtent,
                            _scrollController.position.maxScrollExtent,
                          ),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    child: songInfo(song, index),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget songInfo(MyAudioMetadata song, int index) {
    if (isTooNarrow(context)) {
      return Row(
        children: [
          SizedBox(
            width: 60,
            child: isRanking
                ? Row(
                    mainAxisAlignment: .center,
                    children: [
                      ImageIcon(playOutlinedImage, size: 15),
                      Text(song.playCount.toString()),
                    ],
                  )
                : Center(
                    child: Text(
                      '${index + 1}',
                      style: .new(overflow: .ellipsis),
                    ),
                  ),
          ),
          CoverArtWidget(song: song, size: 40, borderRadius: 4),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: .center,
              crossAxisAlignment: .start,
              children: [
                Text(getTitle(song), style: .new(overflow: .ellipsis)),
                Text(
                  '${getArtist(song)}-${getAlbum(song)}',
                  style: .new(overflow: .ellipsis),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),

          Text(formatDuration(getDuration(song))),
          SizedBox(width: 20),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(width: 60, child: Center(child: Text('${index + 1}'))),
        CoverArtWidget(song: song, size: 60, borderRadius: 10),
        SizedBox(width: 10),

        Expanded(
          child: Text(getTitle(song), style: .new(overflow: .ellipsis)),
        ),
        SizedBox(width: 10),

        Expanded(
          child: Text(getArtist(song), style: .new(overflow: .ellipsis)),
        ),
        SizedBox(width: 10),

        Expanded(
          child: Text(getAlbum(song), style: .new(overflow: .ellipsis)),
        ),
        SizedBox(width: 10),

        Text(formatDuration(getDuration(song))),

        isRanking
            ? SizedBox(
                width: 60,
                child: Center(child: Text(song.playCount.toString())),
              )
            : SizedBox(width: 20),
      ],
    );
  }
}
