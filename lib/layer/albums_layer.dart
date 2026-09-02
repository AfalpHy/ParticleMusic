import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:sylvakru/base/widgets/collection_list.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/layer/layers_manager.dart';

final GlobalKey<NavigatorState> albumsKey = GlobalKey();
final albumsVisibleNotifier = ValueNotifier(true);

class AlbumsLayer extends CollectionList {
  const AlbumsLayer({super.key});

  @override
  State<StatefulWidget> createState() => _AlbumsLayerState();
}

class _AlbumsLayerState extends CollectionListState {
  @override
  GlobalKey<NavigatorState> get globalKey => albumsKey;

  @override
  ValueNotifier<bool> get visibleNotifier => albumsVisibleNotifier;

  @override
  AssetImage get image => albumImage;

  @override
  String Function(int) get countFunction =>
      AppLocalizations.of(context).albumCount;

  @override
  String get label => 'albums';

  @override
  void updateCurrentList() {
    preparing = false;

    final value = textController.text;
    final list = artistAlbumManager.albumList
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();
    if (randomizeNotifier!.value) {
      list.shuffle();
    }
    currentPictureList = list.map((e) => e.picture).toList();
    currentTextList = list.map((e) => e.name).toList();
    currentOnTapList = list
        .map(
          (e) => () {
            if (e.picture.isLoaded) {
              layersManager.pushDetail('albums', e);
            }
          },
        )
        .toList();
    changeNotifier.value++;
  }

  @override
  Future<void> fetchCollectionList() async {
    reachEnd = await artistAlbumManager.loadAlbums() == 0;
  }

  @override
  void initState() {
    super.initState();

    randomizeNotifier = artistAlbumManager.getRandomizeNotifier(false);
    isAscendingNotifier = artistAlbumManager.getIsAscendingNotifier(false);
    useLargePictureNotifier = artistAlbumManager.getUseLargePictureNotifier(
      false,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (artistAlbumManager.albumList.isNotEmpty ||
          (isNotStreamSource && !Loader.busy)) {
        updateCurrentList();
      } else if (isStreamSource) {
        reachEnd = await artistAlbumManager.loadAlbums() == 0;
        updateCurrentList();
      }
    });
    artistAlbumManager.updateNotifier.addListener(updateCurrentList);
  }

  @override
  void dispose() {
    artistAlbumManager.updateNotifier.removeListener(updateCurrentList);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    title = l10n.albums;
    searchHint = l10n.searchAlbums;
    return super.build(context);
  }
}
