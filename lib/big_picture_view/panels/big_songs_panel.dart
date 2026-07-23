import 'package:flutter/material.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/song_list_manager.dart';
import 'package:sylvakru/big_picture_view/panels/big_song_list_base_panel.dart';

class BigSongsPanel extends BigSongListBasePanel {
  const BigSongsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigSongsPanelState();
}

class _BigSongsPanelState extends BigSongListBasePanelState {
  @override
  SongListManager get songListManager => library.songListManager;
}
