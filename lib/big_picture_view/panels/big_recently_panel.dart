import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/data/song_list_manager.dart';

import 'package:sylvakru/big_picture_view/panels/big_song_list_base_panel.dart';

class BigRecentlyPanel extends BigSongListBasePanel {
  const BigRecentlyPanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigRecentlyPanelState();
}

class _BigRecentlyPanelState extends BigSongListBasePanelState {
  @override
  SongListManager get songListManager => history.recentlySongListManager;
}
