import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/big_picture_view/panels/big_song_list_base_panel.dart';

class BigSongsPanel extends BigSongListBasePanel {
  const BigSongsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigSongsPanelState();
}

class _BigSongsPanelState extends BigSongListBasePanelState {
  @override
  List<MyAudioMetadata> get songList => library.songList;

  bool _isLoadingMoreData = false;
  bool _reachEnd = false;

  void _onScroll() async {
    if (firstLoading | _isLoadingMoreData | _reachEnd) {
      return;
    }
    _isLoadingMoreData = true;

    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      _isLoadingMoreData = true;

      final fetchedSongList = await streamClient?.getSongs(
        100,
        songList.length,
      );
      if (!mounted) {
        return;
      }
      if (fetchedSongList == null) {
        _isLoadingMoreData = false;
        return;
      }
      _reachEnd = fetchedSongList.isEmpty;
      songList.addAll(fetchedSongList);

      if (mounted) {
        setState(() {});
      }
    }
    _isLoadingMoreData = false;
  }

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (isStreamSource && songList.isEmpty) {
        firstLoading = true;
        final songs = await streamClient?.getSongs(100, 0) ?? [];
        songList.addAll(songs);

        if (mounted) {
          setState(() {
            firstLoading = false;
          });
        }
      }
    });
  }
}
