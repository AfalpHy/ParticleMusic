import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/song_list_manager.dart';
import 'package:sylvakru/base/widgets/song_list.dart';
import 'package:sylvakru/base/data/playlist.dart';

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

                if (tmpSourcetype == sourceType || songListIsNotEmpty) {
                  widgets.add(
                    Visibility(
                      key: ValueKey(tmpSourcetype.name),
                      visible: tmpSourcetype == sourceType,
                      maintainState: true,
                      child: SongList(
                        playlist: playlist,
                        artist: artist,
                        album: album,
                        isRanking: isRanking,
                        isRecently: isRecently,
                        isRoot: isRoot,
                        sourceType: tmpSourcetype,
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
