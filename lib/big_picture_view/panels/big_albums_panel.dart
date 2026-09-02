import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/utils/zoom_page_route.dart';
import 'package:sylvakru/big_picture_view/panels/big_collection_list_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_single_album_panel.dart';

class BigAlbumsPanel extends BigCollectionListPanel {
  const BigAlbumsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigAlbumsPanelState();
}

class _BigAlbumsPanelState extends BigCollectionListPanelState {
  @override
  ValueNotifier<bool> get randomizeNotifier => albumsRandomizeNotifier;

  @override
  ValueNotifier<bool> get isAscendingNotifier => albumsIsAscendingNotifier;

  @override
  void updateCurrentList() {
    preparing = false;
    final value = textController.text;
    final list = artistAlbumManager.albumList
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();
    if (randomizeNotifier.value) {
      list.shuffle();
    }
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

  bool _reachEnd = false;
  void _onScroll() async {
    if (preparing | _reachEnd) {
      return;
    }

    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent) {
      _reachEnd = await artistAlbumManager.loadAlbums() == 0;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (artistAlbumManager.albumList.isNotEmpty ||
          (isNotStreamSource && !Loader.busy)) {
        updateCurrentList();
      } else if (isStreamSource) {
        _reachEnd = await artistAlbumManager.loadAlbums() == 0;
        updateCurrentList();
      }
    });
    artistAlbumManager.updateNotifier.addListener(updateCurrentList);
    if (isStreamSource) {
      scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    artistAlbumManager.updateNotifier.removeListener(updateCurrentList);
    super.dispose();
  }
}
