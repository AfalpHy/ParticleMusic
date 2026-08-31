import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/utils/zoom_page_route.dart';
import 'package:sylvakru/big_picture_view/panels/big_collection_list_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_single_album_panel.dart';

import 'package:sylvakru/big_picture_view/panels/big_song_list_base_panel.dart';

class BigRankingPanel extends StatelessWidget {
  const BigRankingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    if (sourceType == .navidrome) {
      return _BigRankingAlbumListPanel();
    }
    return _BigRankingSongListPanel();
  }
}

class _BigRankingSongListPanel extends BigSongListBasePanel {
  const _BigRankingSongListPanel();

  @override
  State<StatefulWidget> createState() => _BigRankingSongListPanelState();
}

class _BigRankingSongListPanelState extends BigSongListBasePanelState {
  @override
  List<MyAudioMetadata> get songList => history.rankingSongList;

  @override
  bool get isRanking => true;
}

class _BigRankingAlbumListPanel extends BigCollectionListPanel {
  const _BigRankingAlbumListPanel();

  @override
  State<StatefulWidget> createState() => _BigRankingAlbumListPanelState();
}

class _BigRankingAlbumListPanelState extends BigCollectionListPanelState {
  bool _reachEnd = false;
  void _onScroll() async {
    if (firstLoading | _reachEnd) {
      return;
    }
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent) {
      _reachEnd = await history.loadAlbums(true) == 0;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (sourceType == .navidrome && history.rankingAlbumList.isEmpty) {
        _reachEnd = await history.loadAlbums(true) == 0;
      }
      firstLoading = false;
      updateCurrentList();
    });
    history.recentlyChangeNotifier.addListener(updateCurrentList);
    if (sourceType == .navidrome) {
      scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    history.rankingChangeNotifier.removeListener(updateCurrentList);
    super.dispose();
  }

  @override
  void updateCurrentList() {
    final value = textController.text;
    final list = history.rankingAlbumList
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();

    pictureList = list.map((e) => e.picture).toList();
    textList = list.map((e) => e.name).toList();
    onTapList = list
        .map(
          (e) => () async {
            final baseColor = await computeColor(e.picture);
            if (mounted) {
              Navigator.of(context).push(
                ZoomPageRoute(
                  builder: (context) {
                    return BigSingleAlbumPanel(album: e, baseColor: baseColor);
                  },
                ),
              );
            }

            return;
          },
        )
        .toList();
    if (mounted) {
      setState(() {});
    }
  }
}
