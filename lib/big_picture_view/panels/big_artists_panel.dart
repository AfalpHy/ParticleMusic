import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/utils/zoom_page_route.dart';
import 'package:sylvakru/big_picture_view/panels/big_collection_list_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_single_artist_panel.dart';

class BigArtistsPanel extends BigCollectionListPanel {
  const BigArtistsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigArtistsPanelState();
}

class _BigArtistsPanelState extends BigCollectionListPanelState {
  @override
  ValueNotifier<bool> get randomizeNotifier => artistsRandomizeNotifier;

  @override
  ValueNotifier<bool> get isAscendingNotifier => artistsIsAscendingNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (isStreamSource) {
        await artistAlbumManager.loadArtists();
      }
      firstLoading = false;
      updateCurrentList();
    });
    artistAlbumManager.updateNotifier.addListener(updateCurrentList);
  }

  @override
  void dispose() {
    artistAlbumManager.updateNotifier.removeListener(updateCurrentList);
    super.dispose();
  }

  @override
  void updateCurrentList() {
    final value = textController.text;
    final list = artistAlbumManager.artistList
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();
    if (randomizeNotifier.value) {
      list.shuffle();
    }
    pictureList = list.map((e) => e.picture).toList();
    textList = list.map((e) => e.name).toList();
    onTapList = list
        .map(
          (e) => () {
            Navigator.of(context).push(
              ZoomPageRoute(
                builder: (context) {
                  return BigSingleArtistPanel(artist: e);
                },
              ),
            );
            return;
          },
        )
        .toList();
    if (mounted) {
      setState(() {});
    }
  }
}
