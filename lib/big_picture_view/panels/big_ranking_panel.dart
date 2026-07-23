import 'package:flutter/material.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/data/song_list_manager.dart';
import 'package:sylvakru/big_picture_view/panels/big_song_list_base_panel.dart';

class BigRankingPanel extends BigSongListBasePanel {
  const BigRankingPanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigRankingPanelState();
}

class _BigRankingPanelState extends BigSongListBasePanelState {
  @override
  SongListManager get songListManager => history.rankingSongListManager;

  @override
  bool get isRanking => true;
}
