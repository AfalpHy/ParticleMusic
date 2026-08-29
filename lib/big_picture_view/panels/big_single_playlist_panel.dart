import 'package:flutter/widgets.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/big_picture_view/panels/big_song_list_with_cover_base_panel.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

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
  String get title => widget.playlist.isFavorite
      ? AppLocalizations.of(context).favorites
      : widget.playlist.name;

  @override
  List<MyAudioMetadata> get songList => widget.playlist.songList;

  @override
  Playlist get playlist => widget.playlist;

  @override
  void moveToTop(MyAudioMetadata song) {
    songList.remove(song);
    songList.insert(0, song);
    playlist.update();
  }

  @override
  void initState() {
    currentSongList = List.from(songList);
    widget.playlist.changeNotifier.addListener(updateSongList);
    super.initState();
  }

  @override
  void dispose() {
    widget.playlist.changeNotifier.removeListener(updateSongList);
    super.dispose();
  }
}
