import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/big_picture_view/panels/big_song_list_base_panel.dart';

class BigSongsPanel extends BigSongListBasePanel {
  const BigSongsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigSongsPanelState();
}

class _BigSongsPanelState extends BigSongListBasePanelState {
  @override
  List<MyAudioMetadata> get songList => library.songList;
}
