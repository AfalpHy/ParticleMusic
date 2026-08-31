import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/widgets/collection_list.dart';
import 'package:sylvakru/base/widgets/song_list.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/layer/layers_manager.dart';

final GlobalKey<NavigatorState> recentlyKey = GlobalKey();
final recentlyVisibleNotifier = ValueNotifier(true);

class RecentlyLayer extends CollectionList {
  const RecentlyLayer({super.key});

  @override
  State<StatefulWidget> createState() => _RecentlyLayerState();
}

class _RecentlyLayerState extends CollectionListState {
  @override
  GlobalKey<NavigatorState> get globalKey => recentlyKey;

  @override
  ValueNotifier<bool> get visibleNotifier => recentlyVisibleNotifier;

  @override
  AssetImage get image => recentlyImage;

  @override
  String Function(int) get countFunction =>
      AppLocalizations.of(context).albumCount;

  @override
  String get label => 'recently';

  @override
  void updateCurrentList() {
    final value = textController.text;
    final list = history.recentlyAlbumList
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();
    currentPictureList = list.map((e) => e.picture).toList();
    currentTextList = list.map((e) => e.name).toList();
    currentOnTapList = list
        .map(
          (e) => () {
            if (e.picture.isLoaded) {
              layersManager.pushDetail('recently', e);
            }
          },
        )
        .toList();
    changeNotifier.value++;
  }

  @override
  Future<void> fetchCollectionList() async {
    reachEnd = await history.loadAlbums(false) == 0;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (sourceType == .navidrome && history.recentlyAlbumList.isEmpty) {
        reachEnd = await history.loadAlbums(false) == 0;
      }
      firstLoading = false;
      updateCurrentList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (sourceType != .navidrome) {
      return SongList(isRecently: true);
    }
    final l10n = AppLocalizations.of(context);
    title = l10n.recently;
    searchHint = l10n.searchAlbums;
    return super.build(context);
  }
}
