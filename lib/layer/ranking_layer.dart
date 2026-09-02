import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/widgets/collection_list.dart';
import 'package:sylvakru/base/widgets/song_list.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/layer/layers_manager.dart';

final GlobalKey<NavigatorState> rankingKey = GlobalKey();
final rankingVisibleNotifier = ValueNotifier(true);

class RankingLayer extends CollectionList {
  const RankingLayer({super.key});

  @override
  State<StatefulWidget> createState() => _RankingLayerState();
}

class _RankingLayerState extends CollectionListState {
  @override
  GlobalKey<NavigatorState> get globalKey => rankingKey;

  @override
  ValueNotifier<bool> get visibleNotifier => rankingVisibleNotifier;

  @override
  AssetImage get image => rankingImage;

  @override
  String Function(int) get countFunction =>
      AppLocalizations.of(context).albumCount;

  @override
  String get label => 'ranking';

  @override
  void updateCurrentList() {
    preparing = false;
    final value = textController.text;
    final list = history.rankingAlbumList
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();
    currentPictureList = list.map((e) => e.picture).toList();
    currentTextList = list.map((e) => e.name).toList();
    currentOnTapList = list
        .map(
          (e) => () {
            if (e.picture.isLoaded) {
              layersManager.pushDetail('ranking', e);
            }
          },
        )
        .toList();
    changeNotifier.value++;
  }

  @override
  Future<void> fetchCollectionList() async {
    reachEnd = await history.loadAlbums(true) == 0;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      updateCurrentList();
      if (sourceType == .navidrome && history.rankingAlbumList.isEmpty) {
        reachEnd = await history.loadAlbums(true) == 0;
      }
    });

    history.rankingChangeNotifier.addListener(updateCurrentList);
  }

  @override
  void dispose() {
    history.rankingChangeNotifier.removeListener(updateCurrentList);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (sourceType != .navidrome) {
      return SongList(isRanking: true);
    }
    final l10n = AppLocalizations.of(context);
    title = l10n.ranking;
    searchHint = l10n.searchAlbums;
    return super.build(context);
  }
}
