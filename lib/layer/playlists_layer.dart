import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/widgets/collection_list.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/asset_images.dart';

final GlobalKey<NavigatorState> playlistsKey = GlobalKey();
final playlistsVisibleNotifier = ValueNotifier(true);

class PlaylistsLayer extends CollectionList {
  const PlaylistsLayer({super.key});

  @override
  State<StatefulWidget> createState() => _PlaylistsLayerState();
}

class _PlaylistsLayerState extends CollectionListState {
  @override
  GlobalKey<NavigatorState> get globalKey => playlistsKey;

  @override
  ValueNotifier<bool> get visibleNotifier => playlistsVisibleNotifier;

  @override
  ValueNotifier<bool> get useLargePictureNotifier =>
      playlistsUseLargePictureNotifier;

  @override
  AssetImage get image => playlistsImage;

  @override
  String Function(int) get countFunction =>
      AppLocalizations.of(context).playlistCount;

  @override
  bool get reachEnd => true;

  @override
  void updateCurrentList() {
    preparing = false;
    final value = textController.text;
    final list = playlistManager.playlists.where((playlist) {
      return playlist.name.toLowerCase().contains(value.toLowerCase());
    }).toList();

    currentPictureList = list.map((e) => e.getCoverSong()?.picture).toList();
    currentTextList = list.map((e) => e.name).toList();
    currentSubCountList = list.map((e) => e.totalCount).toList();
    currentOnTapList = list
        .map(
          (e) => () {
            if (e.getCoverSong() == null ||
                e.getCoverSong()!.picture.isLoaded) {
              layersManager.pushDetail('playlists', e);
            }
          },
        )
        .toList();
    changeNotifier.value++;
  }

  @override
  void initState() {
    super.initState();
    isListViewNotifier = ValueNotifier(true);
    updateCurrentList();
    playlistManager.updateNotifier.addListener(updateCurrentList);
  }

  @override
  void dispose() {
    playlistManager.updateNotifier.removeListener(updateCurrentList);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    title = l10n.playlists;
    searchHint = l10n.searchPlaylists;
    if (currentTextList.isNotEmpty) {
      currentTextList[0] = l10n.favorites;
    }
    return super.build(context);
  }
}
