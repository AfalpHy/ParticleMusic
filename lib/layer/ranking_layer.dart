import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
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
    final albumList = await navidromeClient!.getAlbumList(
      history.rankingAlbumList.length,
      type: 'frequent',
    );
    if (!mounted || albumList == null) {
      return;
    }

    if (albumList.isEmpty) {
      reachEnd = true;
    }

    for (final map in albumList) {
      final name = map['name'];
      final id = map['id'];
      final album = artistAlbumManager.albumMap.putIfAbsent(
        id,
        () => Album(name, id: id, coverArtId: map['coverArt']),
      );
      history.rankingAlbumList.add(album);
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (isStreamSource) {
        if (history.rankingAlbumList.isEmpty) {
          await fetchCollectionList();
        }
      }
      updateCurrentList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isNotStreamSource) {
      return SongList(isRanking: true);
    }
    final l10n = AppLocalizations.of(context);
    title = l10n.ranking;
    searchHint = l10n.searchAlbums;
    return super.build(context);
  }
}
