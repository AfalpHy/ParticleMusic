import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:sylvakru/base/widgets/collection_list.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/asset_images.dart';

final GlobalKey<NavigatorState> artistsKey = GlobalKey();
final artistsVisibleNotifier = ValueNotifier(true);

class ArtistsLayer extends CollectionList {
  const ArtistsLayer({super.key});

  @override
  State<StatefulWidget> createState() => _ArtistsLayerState();
}

class _ArtistsLayerState extends CollectionListState {
  @override
  GlobalKey<NavigatorState> get globalKey => artistsKey;

  @override
  ValueNotifier<bool> get visibleNotifier => artistsVisibleNotifier;

  @override
  AssetImage get image => artistImage;

  @override
  String Function(int) get countFunction =>
      AppLocalizations.of(context).artistCount;

  @override
  void updateCurrentList() {
    final value = textController.text;
    artistAlbumManager.sortArtists();
    final list = artistAlbumManager.artistList
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
              layersManager.pushDetail('artists', e);
            }
          },
        )
        .toList();
    changeNotifier.value++;
  }

  Future<void> _fetchArtistList() async {
    final artistList = await navidromeClient!.getArtistList(
      artistAlbumManager.artistList.length,
    );
    if (!mounted || artistList == null) {
      return;
    }

    reachEnd = true;
    for (final map in artistList) {
      final name = map['name'];
      final artist = Artist(name, id: map['id'], coverArtId: map['coverArt']);
      artistAlbumManager.artistList.add(artist);
      artistAlbumManager.artistMap[name] = artist;
    }
    artistAlbumManager.sortArtists();
    artistAlbumManager.updateNotifier.value++;
  }

  @override
  void initState() {
    super.initState();

    randomizeNotifier = artistAlbumManager.getIsRandomizeNotifier(true);
    isAscendingNotifier = artistAlbumManager.getIsAscendingNotifier(true);
    useLargePictureNotifier = artistAlbumManager.getUseLargePictureNotifier(
      true,
    );

    isListViewNotifier = artistAlbumManager.artistsIsListViewNotifier;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (isStreamSource) {
        if (artistAlbumManager.artistList.isEmpty) {
          await _fetchArtistList();
        }
      }
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    title = l10n.artists;
    searchHint = l10n.searchArtists;
    return super.build(context);
  }
}
