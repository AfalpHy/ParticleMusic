import 'package:flutter/widgets.dart';
import 'package:sylvakru/base/data/folder.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/big_picture_view/panels/big_song_list_with_cover_base_panel.dart';

class BigSingleFolderPanel extends BigSongListWithCoverBasePanel {
  final Folder folder;
  const BigSingleFolderPanel({
    super.key,
    required this.folder,
    required super.baseColor,
  });

  @override
  State<StatefulWidget> createState() => _BigSingleFolderPanelState();
}

class _BigSingleFolderPanelState
    extends BigSongListWithCoverBasePanelState<BigSingleFolderPanel> {
  @override
  String get title => widget.folder.id;

  @override
  Folder? get folder => widget.folder;

  @override
  void moveToTop(MyAudioMetadata song) {
    widget.folder.songList.remove(song);
    widget.folder.songList.insert(0, song);
    widget.folder.changeNotifier.value++;
  }

  @override
  void initState() {
    currentSongList = widget.folder.songList;
    sourceCount = 1;
    sourceType = widget.folder.isWebdav ? .webdav : .local;
    widget.folder.changeNotifier.addListener(updateSongList);
    super.initState();
  }

  @override
  void dispose() {
    widget.folder.changeNotifier.removeListener(updateSongList);
    super.dispose();
  }
}
