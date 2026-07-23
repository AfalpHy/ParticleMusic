import 'package:flutter/widgets.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/data/song_list_manager.dart';
import 'package:sylvakru/big_picture_view/panels/big_song_list_with_cover_base_panel.dart';

class BigSinglePlaylistPanel extends BigSongListWithCoverBasePanel {
  final Playlist playlist;
  const BigSinglePlaylistPanel({
    super.key,
    required this.playlist,
    required super.baseColor,
  });

  @override
  State<StatefulWidget> createState() => _BigSinglePlaylistPanelState();
}

class _BigSinglePlaylistPanelState
    extends BigSongListWithCoverBasePanelState<BigSinglePlaylistPanel> {
  @override
  SongListManager get songListManager => widget.playlist.songListManager;

  @override
  String get title => widget.playlist.name;

  @override
  void updateSongList() {
    currentSongList = songListManager.getSongList();
    sourceCount = songListManager.notEmptyCount;
    sourceType = songListManager.sourceTypeNotifier.value;
    super.updateSongList();
  }

  @override
  void initState() {
    currentSongList = songListManager.getSongList();
    sourceCount = songListManager.notEmptyCount;
    sourceType = songListManager.sourceTypeNotifier.value;
    songListManager.changeNotifier.addListener(updateSongList);
    super.initState();
  }

  @override
  void dispose() {
    songListManager.changeNotifier.removeListener(updateSongList);
    super.dispose();
  }
}
