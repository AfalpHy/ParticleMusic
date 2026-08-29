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
    final albumList = await navidromeClient!.getAlbumList(
      history.recentlySongList.length,
      type: 'recent',
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
      history.recentlyAlbumList.add(album);
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (isStreamSource) {
        if (history.recentlyAlbumList.isEmpty) {
          await fetchCollectionList();
        }
      }
      updateCurrentList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isNotStreamSource) {
      return SongList(isRecently: true);
    }
    final l10n = AppLocalizations.of(context);
    title = l10n.recently;
    searchHint = l10n.searchAlbums;
    return super.build(context);
  }
}
